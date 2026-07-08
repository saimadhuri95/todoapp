import 'package:drift/drift.dart' show TableOrViewStatements;
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/db/database.dart' show Todo;
import 'package:todoapp/data/export_service.dart';
import 'package:todoapp/data/import_parsers.dart';
import 'package:todoapp/data/repositories/todo_repository.dart' show TodoTags;

import '../support/simulated_device.dart';

void main() {
  int dateMs(int y, int m, int d) => DateTime(y, m, d).millisecondsSinceEpoch;

  group('parseTodoTxt', () {
    test('parses a plain task', () {
      final todos = parseTodoTxt('Buy milk\n');
      expect(todos, hasLength(1));
      expect(todos.single.title, 'Buy milk');
      expect(todos.single.completed, isFalse);
      expect(todos.single.priority, 0);
    });

    test('skips blank lines', () {
      final todos = parseTodoTxt('\n  \nBuy milk\n\nCall Sam\n');
      expect(todos.map((t) => t.title), ['Buy milk', 'Call Sam']);
    });

    test('reads priority, projects, contexts, due, and recurrence', () {
      final todos = parseTodoTxt(
        '(A) Pay rent +Home @errand due:2026-08-01 rec:1m',
      );
      final t = todos.single;
      expect(t.title, 'Pay rent');
      expect(t.priority, 3); // (A) = high
      expect(t.tags, ['Home', 'errand']);
      expect(t.dueAtMs, dateMs(2026, 8, 1));
      expect(t.recurrenceRule, 'FREQ=MONTHLY');
      expect(t.completed, isFalse);
    });

    test('maps B/C priorities and multi-interval recurrence', () {
      expect(parseTodoTxt('(B) x').single.priority, 2);
      expect(parseTodoTxt('(C) x').single.priority, 1);
      expect(
        parseTodoTxt('t rec:2w').single.recurrenceRule,
        'FREQ=WEEKLY;INTERVAL=2',
      );
    });

    test('reads a completed task with completion date', () {
      final t = parseTodoTxt('x 2026-07-04 Ship release').single;
      expect(t.title, 'Ship release');
      expect(t.completed, isTrue);
      expect(t.completedAtMs, dateMs(2026, 7, 4));
    });

    test('underscores in tags become spaces (inverse of export)', () {
      expect(parseTodoTxt('t +Home_Reno').single.tags, ['Home Reno']);
    });

    test('drops unknown key:value metadata and empty titles', () {
      final todos = parseTodoTxt('Task pri:whatever\nx 2026-01-01');
      expect(todos, hasLength(1));
      expect(todos.single.title, 'Task');
    });
  });

  group('parseCsv (generic)', () {
    test('maps aliased columns', () {
      final todos = parseCsv(
        'title,due,priority,tags\n'
        'Buy milk,2026-08-01,2,"errand,shopping"\n',
      );
      final t = todos.single;
      expect(t.title, 'Buy milk');
      expect(t.dueAtMs, dateMs(2026, 8, 1));
      expect(t.priority, 2);
      expect(t.tags, ['errand', 'shopping']);
    });

    test('honors quoted fields with embedded commas and newlines', () {
      final todos = parseCsv(
        'title,notes\n'
        '"Plan, then act","line one\nline two"\n',
      );
      expect(todos.single.title, 'Plan, then act');
      expect(todos.single.notes, 'line one\nline two');
    });

    test('unquotes doubled quotes', () {
      expect(
        parseCsv('title\n"She said ""hi"""').single.title,
        'She said "hi"',
      );
    });

    test('skips rows with no title', () {
      final todos = parseCsv('title,notes\n,orphan note\nReal task,');
      expect(todos.map((t) => t.title), ['Real task']);
    });

    test('reads tab-separated values', () {
      final todos = parseCsv('title\tpriority\nWrite tests\t3');
      expect(todos.single.title, 'Write tests');
      expect(todos.single.priority, 3);
    });

    test('returns empty when no header is recognizable', () {
      expect(parseCsv('random,junk\n1,2'), isEmpty);
      expect(parseCsv(''), isEmpty);
    });
  });

  group('parseCsv (Todoist)', () {
    const csv =
        'TYPE,CONTENT,DESCRIPTION,PRIORITY,INDENT,AUTHOR,RESPONSIBLE,DATE\n'
        'task,Buy milk,at the store,4,1,,,2026-08-01\n'
        'note,just a note,,1,1,,,\n'
        'task,Low prio,,1,1,,,\n';

    test('keeps tasks, drops notes, maps inverted priority', () {
      final todos = parseCsv(csv);
      expect(todos.map((t) => t.title), ['Buy milk', 'Low prio']);
      expect(todos.first.priority, 3); // Todoist 4 = p1 = high
      expect(todos.first.notes, 'at the store');
      expect(todos.first.dueAtMs, dateMs(2026, 8, 1));
      expect(todos.last.priority, 0); // Todoist 1 = p4 = none
    });
  });

  group('parseCsv (TickTick)', () {
    const csv =
        '"Date: 2026-07-06"\n'
        '"Version: 7.1"\n'
        '\n'
        '"List Name","Title","Kind","Tags","Content","Due Date",'
        '"Priority","Status","Completed Time","Repeat"\n'
        'Inbox,Buy milk,TEXT,"errand,home",note body,'
        '2026-08-01T00:00:00+0000,5,0,,\n'
        'Inbox,Done thing,TEXT,,,,,2,2026-07-05T09:00:00+0000,'
        'RRULE:FREQ=WEEKLY\n';

    test('skips preamble, maps priority, tags, completion, recurrence', () {
      final todos = parseCsv(csv);
      expect(todos.map((t) => t.title), ['Buy milk', 'Done thing']);
      final milk = todos.first;
      expect(milk.priority, 3); // TickTick 5 = high
      expect(milk.tags, ['errand', 'home']);
      expect(milk.notes, 'note body');
      expect(milk.completed, isFalse);
      final done = todos.last;
      expect(done.completed, isTrue);
      expect(done.completedAtMs, isNotNull);
      expect(done.recurrenceRule, 'FREQ=WEEKLY');
    });
  });

  group('ExportService.importParsed', () {
    late Device device;
    setUp(() => device = Device('aa', DateTime.utc(2026, 7, 6, 12)));
    tearDown(() => device.close());

    Future<List<Todo>> allTodos() => device.db.todos.all().get();

    test('writes fresh rows with new ids and returns the count', () async {
      final service = ExportService(db: device.db, hlc: device.hlc);
      final count = await service.importParsed(
        parseTodoTxt('(A) Pay rent +Home due:2026-08-01\nBuy milk'),
      );
      expect(count, 2);
      final rows = await allTodos();
      expect(rows, hasLength(2));
      final rent = rows.firstWhere((t) => t.title == 'Pay rent');
      expect(rent.priority, 3);
      expect(rent.tags, ['Home']);
      expect(rent.dueAtMs, DateTime(2026, 8, 1).millisecondsSinceEpoch);
      expect(rent.deleted, isFalse);
      // Distinct uuid v7 ids assigned.
      expect(rows.map((t) => t.id).toSet(), hasLength(2));
    });

    test(
      'stamps completion time from the clock when the source omits it',
      () async {
        final service = ExportService(db: device.db, hlc: device.hlc);
        await service.importParsed(const [
          ImportedTodo(title: 'Already done', completed: true),
        ]);
        final row = (await allTodos()).single;
        expect(
          row.completedAtMs,
          DateTime.utc(2026, 7, 6, 12).millisecondsSinceEpoch,
        );
      },
    );

    test('stamps sync fields so imports replicate', () async {
      final service = ExportService(db: device.db, hlc: device.hlc);
      await service.importParsed(const [ImportedTodo(title: 'x')]);
      final clocks = await device.db.fieldClocks.select().get();
      expect(clocks.where((c) => c.entity == 'todos'), isNotEmpty);
    });

    test('empty import writes nothing', () async {
      final service = ExportService(db: device.db, hlc: device.hlc);
      expect(await service.importParsed(const []), 0);
      expect(await allTodos(), isEmpty);
    });
  });
}
