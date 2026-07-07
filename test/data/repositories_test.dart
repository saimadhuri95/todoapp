import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/repositories/list_repository.dart';
import 'package:todoapp/data/repositories/todo_repository.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late TodoRepository todos;
  late ListRepository lists;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime.utc(2026, 7, 5, 12));
    final hlc = HlcClock(nodeId: 'device-1', clock: clock);
    todos = TodoRepository(db, hlc);
    lists = ListRepository(db, hlc);
  });

  tearDown(() => db.close());

  Future<Map<String, String>> clocksFor(String rowId) async {
    final rows =
        await (db.fieldClocks.select()..where((c) => c.rowId.equals(rowId)))
            .get();
    return {for (final r in rows) r.fieldName: r.hlc};
  }

  group('TodoRepository', () {
    test('create returns row and stamps every sync field', () async {
      final todo = await todos.create(
        title: 'Buy milk',
        tags: ['errand'],
        priority: 2,
      );

      expect(todo.title, 'Buy milk');
      expect(todo.tags, ['errand']);
      expect(todo.priority, 2);

      final stamps = await clocksFor(todo.id);
      expect(stamps.keys, hasLength(12)); // every todos entry in syncColumns
      expect(stamps.keys, contains('title'));
      expect(stamps.keys, contains('deleted'));
    });

    test('edit writes only given fields and bumps only their clocks', () async {
      final todo = await todos.create(title: 'before');
      final createStamps = await clocksFor(todo.id);

      await todos.edit(todo.id, title: const Value('after'));

      final after = (await todos.getById(todo.id))!;
      expect(after.title, 'after');
      expect(after.priority, 0);

      final editStamps = await clocksFor(todo.id);
      expect(
        Hlc.parse(editStamps['title']!) > Hlc.parse(createStamps['title']!),
        isTrue,
      );
      expect(editStamps['notes'], createStamps['notes']);
    });

    test('edit of missing todo throws', () {
      expect(
        () => todos.edit('nope', title: const Value('x')),
        throwsStateError,
      );
    });

    test('complete/uncomplete use injected clock and stamp field', () async {
      final todo = await todos.create(title: 't');

      await todos.complete(todo.id);
      final done = (await todos.getById(todo.id))!;
      expect(done.completedAtMs, clock.now().millisecondsSinceEpoch);

      await todos.uncomplete(todo.id);
      expect((await todos.getById(todo.id))!.completedAtMs, isNull);
    });

    test('softDelete tombstones and watchActive hides it', () async {
      final keep = await todos.create(title: 'keep');
      final drop = await todos.create(title: 'drop');

      await todos.softDelete(drop.id);

      final active = await todos.watchActive().first;
      expect(active.map((t) => t.id), [keep.id]);
      // Row still exists (tombstone).
      expect((await todos.getById(drop.id))!.deleted, isTrue);

      await todos.restore(drop.id);
      expect(await todos.watchActive().first, hasLength(2));
    });

    test('watchActive orders by due date (nulls last) then priority', () async {
      final noDue = await todos.create(title: 'no due', priority: 9);
      final late_ = await todos.create(title: 'late', dueAtMs: 2000);
      final soon = await todos.create(title: 'soon', dueAtMs: 1000);
      final completed = await todos.create(title: 'done', dueAtMs: 500);
      await todos.complete(completed.id);

      final active = await todos.watchActive().first;
      expect(active.map((t) => t.id), [soon.id, late_.id, noDue.id]);
    });

    test('tags roundtrip through edit', () async {
      final todo = await todos.create(title: 't');
      await todos.edit(todo.id, tags: const Value(['home', 'urgent']));
      expect((await todos.getById(todo.id))!.tags, ['home', 'urgent']);
    });
  });

  group('ListRepository', () {
    test('create/rename/archive lifecycle with stamps', () async {
      final list = await lists.create(name: 'Inbox');
      await lists.rename(list.id, 'Home');

      expect((await lists.getById(list.id))!.name, 'Home');
      expect((await clocksFor(list.id)).keys, hasLength(4));

      await lists.archive(list.id);
      expect(await lists.watchAll().first, isEmpty);
      expect((await lists.getById(list.id))!.deleted, isTrue);
    });

    test('watchAll orders by sortOrder', () async {
      final b = await lists.create(name: 'B');
      final a = await lists.create(name: 'A');
      await lists.setSortOrder(a.id, 1);
      await lists.setSortOrder(b.id, 2);

      final all = await lists.watchAll().first;
      expect(all.map((l) => l.name), ['A', 'B']);
    });

    test('todo can move between lists', () async {
      final inbox = await lists.create(name: 'Inbox');
      final work = await lists.create(name: 'Work');
      final todo = await todos.create(title: 't', listId: inbox.id);

      await todos.edit(todo.id, listId: Value(work.id));
      expect((await todos.getById(todo.id))!.listId, work.id);

      final inWork = await todos.watchActive(listId: work.id).first;
      expect(inWork.map((t) => t.id), [todo.id]);
    });
  });

  // Clock is fixed at 2026-07-05 12:00 UTC.
  group('recurring complete (TASKS.md 6.9)', () {
    int at(DateTime d) => d.millisecondsSinceEpoch;

    test('advances due to the next occurrence and stays active', () async {
      final todo = await todos.create(
        title: 'meds',
        dueAtMs: at(DateTime.utc(2026, 7, 5, 9)), // this morning
        recurrenceRule: 'FREQ=DAILY',
      );

      await todos.complete(todo.id);

      final row = (await todos.getById(todo.id))!;
      expect(row.completedAtMs, isNull); // never leaves the active list
      expect(row.dueAtMs, at(DateTime.utc(2026, 7, 6, 9)));
    });

    test(
      'overdue completion jumps past now, not to another past slot',
      () async {
        final todo = await todos.create(
          title: 'meds',
          dueAtMs: at(DateTime.utc(2026, 7, 1, 9)), // 4 days overdue
          recurrenceRule: 'FREQ=DAILY',
        );

        await todos.complete(todo.id);

        // First occurrence after now (Jul 5 12:00), not Jul 2.
        expect(
          (await todos.getById(todo.id))!.dueAtMs,
          at(DateTime.utc(2026, 7, 6, 9)),
        );
      },
    );

    test('early completion skips the pending occurrence', () async {
      final todo = await todos.create(
        title: 'water plants',
        dueAtMs: at(DateTime.utc(2026, 7, 6, 9)), // due tomorrow
        recurrenceRule: 'FREQ=WEEKLY',
      );

      await todos.complete(todo.id);

      expect(
        (await todos.getById(todo.id))!.dueAtMs,
        at(DateTime.utc(2026, 7, 13, 9)),
      );
    });

    test('advancing clears a stale snooze and stamps the fields', () async {
      final todo = await todos.create(
        title: 'meds',
        dueAtMs: at(DateTime.utc(2026, 7, 5, 9)),
        recurrenceRule: 'FREQ=DAILY',
      );
      await todos.snoozeAlarm(todo.id, at(DateTime.utc(2026, 7, 5, 13)));
      final before = await clocksFor(todo.id);

      await todos.complete(todo.id);

      final row = (await todos.getById(todo.id))!;
      expect(row.snoozeUntilMs, isNull);
      final after = await clocksFor(todo.id);
      expect(after['dueAtMs'], isNot(before['dueAtMs']));
      expect(after['completedAtMs'], before['completedAtMs']); // untouched
    });

    test('malformed rule falls back to normal completion', () async {
      final todo = await todos.create(
        title: 'odd',
        dueAtMs: at(DateTime.utc(2026, 7, 5, 9)),
        recurrenceRule: 'FREQ=SOMETIMES',
      );

      await todos.complete(todo.id);

      expect((await todos.getById(todo.id))!.completedAtMs, isNotNull);
    });

    test('recurring without a due date completes normally', () async {
      final todo = await todos.create(
        title: 'floaty',
        recurrenceRule: 'FREQ=DAILY',
      );

      await todos.complete(todo.id);

      expect((await todos.getById(todo.id))!.completedAtMs, isNotNull);
    });
  });

  test(
    'mutations across repositories share one monotonic HLC stream',
    () async {
      final list = await lists.create(name: 'L');
      final todo = await todos.create(title: 't', listId: list.id);
      await lists.rename(list.id, 'L2');
      await todos.edit(todo.id, title: const Value('t2'));

      final all = await db.fieldClocks.all().get();
      final hlcs = all.map((r) => Hlc.parse(r.hlc)).toSet().toList()..sort();
      // 4 mutations → 4 distinct HLCs, strictly increasing.
      expect(hlcs, hasLength(4));
      for (var i = 1; i < hlcs.length; i++) {
        expect(hlcs[i] > hlcs[i - 1], isTrue);
      }
    },
  );
}
