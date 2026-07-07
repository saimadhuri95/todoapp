import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/hlc.dart';
import 'db/database.dart';
import 'import_parsers.dart';
import 'repositories/todo_repository.dart' show TodoTags;
import 'sync/sync_fields.dart';

/// JSON export/import (TASKS.md 5.3).
///
/// Export includes tombstones so a backup restores exactly. Import upserts
/// every row and stamps all sync fields with a fresh HLC, so restored data
/// replicates to paired devices like any local edit (and LWW keeps a
/// restore from resurrecting newer remote state on conflict — the newer
/// stamps win when they arrive).
class ExportService {
  ExportService({required this.db, required this.hlc});

  final AppDatabase db;
  final HlcClock hlc;

  static const int formatVersion = 1;
  static const _uuid = Uuid();

  /// Creates new todos from a parsed third-party import (the [ImportedTodo]s
  /// from [parseTodoTxt]/[parseCsv]). Unlike [importJson], these are fresh
  /// rows with new ids — never a row-for-row restore — so each gets a new
  /// uuid v7 and a single batch HLC stamp and replicates like a local add.
  /// Completed items without a source timestamp are stamped with the clock.
  /// Returns the number of todos written.
  Future<int> importParsed(List<ImportedTodo> items) async {
    if (items.isEmpty) return 0;
    final stamp = hlc.send();
    final nowMs = hlc.clock.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      for (final item in items) {
        final id = _uuid.v7();
        await db.todos.insertOne(
          TodosCompanion.insert(
            id: id,
            title: item.title,
            notes: Value(item.notes),
            dueAtMs: Value(item.dueAtMs),
            recurrenceRule: Value(item.recurrenceRule),
            completedAtMs: Value(
              item.completed ? (item.completedAtMs ?? nowMs) : null,
            ),
            priority: Value(item.priority),
            tagsJson: Value(jsonEncode(item.tags)),
          ),
        );
        await stampFields(
          db: db,
          entity: 'todos',
          rowId: id,
          fields: syncColumns['todos']!.keys,
          hlc: stamp,
        );
      }
    });
    return items.length;
  }

  Future<String> exportJson() async {
    final lists = await db.todoLists.all().get();
    final todos = await db.todos.all().get();
    return const JsonEncoder.withIndent('  ').convert({
      'v': formatVersion,
      'app': 'knot',
      'exportedAtMs': hlc.clock.now().millisecondsSinceEpoch,
      'lists': [for (final l in lists) l.toJson()],
      'todos': [for (final t in todos) t.toJson()],
    });
  }

  /// Human-readable Markdown export (TASKS.md 6.17). One-way — for reading,
  /// printing, or pasting elsewhere; restores go through [exportJson].
  /// Tombstones are excluded: this is for humans, not replication.
  Future<String> exportMarkdown() async {
    final lists = await db.todoLists.all().get();
    final todos = await _liveTodos();
    final buffer = StringBuffer('# Knot todos — ${_ymd(hlc.clock.now())}\n');
    final byList = <String?, List<Todo>>{};
    for (final todo in todos) {
      byList.putIfAbsent(todo.listId, () => []).add(todo);
    }
    final liveLists = [
      for (final l in lists)
        if (!l.deleted) l,
    ]..sort((x, y) => x.name.compareTo(y.name));
    final sections = <(String, List<Todo>?)>[
      ('Inbox', byList[null]),
      for (final list in liveLists) (list.name, byList[list.id]),
    ];
    for (final (name, items) in sections) {
      if (items == null || items.isEmpty) continue;
      buffer.write('\n## $name\n\n');
      for (final todo in items) {
        final done = todo.completedAtMs != null;
        final extras = [
          if (todo.dueAtMs != null)
            'due ${_ymdHm(DateTime.fromMillisecondsSinceEpoch(todo.dueAtMs!))}',
          if (todo.recurrenceRule != null)
            'repeats ${_recurrenceLabel(todo.recurrenceRule!)}',
          if (todo.priority > 0) _priorityNames[todo.priority] ?? '',
          for (final tag in todo.tags) '#$tag',
        ];
        buffer.write(
          '- [${done ? 'x' : ' '}] ${todo.title}'
          '${extras.isEmpty ? '' : ' (${extras.join(', ')})'}\n',
        );
        for (final line in todo.notes.split('\n')) {
          if (line.trim().isNotEmpty) buffer.write('  $line\n');
        }
      }
    }
    return buffer.toString();
  }

  /// todo.txt export (TASKS.md 6.17): one task per line following
  /// https://github.com/todotxt/todo.txt — `x` + completion date, `(A)`
  /// priorities, `+List` projects, `@tag` contexts, `due:`/`rec:` key-values.
  /// Lossy by design: notes don't fit a single-line format and are dropped.
  Future<String> exportTodoTxt() async {
    final listNames = {
      for (final l in await db.todoLists.all().get()) l.id: l.name,
    };
    final buffer = StringBuffer();
    for (final todo in await _liveTodos()) {
      final completedAt = todo.completedAtMs;
      final rec = todo.recurrenceRule == null
          ? null
          : _recTag(todo.recurrenceRule!);
      final parts = [
        if (completedAt != null)
          'x ${_ymd(DateTime.fromMillisecondsSinceEpoch(completedAt))}'
        else if (todo.priority > 0)
          '(${_todoTxtPriorities[todo.priority]})',
        todo.title,
        if (todo.listId case final id? when listNames.containsKey(id))
          '+${listNames[id]!.replaceAll(' ', '_')}',
        for (final tag in todo.tags) '@${tag.replaceAll(' ', '_')}',
        if (todo.dueAtMs != null)
          'due:${_ymd(DateTime.fromMillisecondsSinceEpoch(todo.dueAtMs!))}',
        if (rec != null) 'rec:$rec',
      ];
      buffer.writeln(parts.join(' '));
    }
    return buffer.toString();
  }

  /// Not-deleted todos, active before completed, soonest due first.
  Future<List<Todo>> _liveTodos() async {
    final rows =
        await (db.todos.select()
              ..where((t) => t.deleted.equals(false))
              ..orderBy([
                (t) => OrderingTerm(expression: t.completedAtMs.isNotNull()),
                (t) => OrderingTerm(expression: t.dueAtMs.isNull()),
                (t) => OrderingTerm(expression: t.dueAtMs),
              ]))
            .get();
    return rows;
  }

  static const _priorityNames = {1: 'low', 2: 'medium', 3: 'high'};
  static const _todoTxtPriorities = {3: 'A', 2: 'B', 1: 'C'};

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static String _ymdHm(DateTime d) =>
      '${_ymd(d)} ${_two(d.hour)}:${_two(d.minute)}';

  static final _simpleRule = RegExp(
    r'^FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)'
    r'(?:;INTERVAL=(\d+))?$',
  );

  /// "daily" / "every 2 weeks" for the editor's simple rules, raw otherwise.
  static String _recurrenceLabel(String rule) {
    final m = _simpleRule.firstMatch(rule);
    if (m == null) return rule;
    final unit = m.group(1)!.toLowerCase(); // daily/weekly/monthly/yearly
    final n = int.parse(m.group(2) ?? '1');
    if (n == 1) return unit;
    const plural = {
      'DAILY': 'days',
      'WEEKLY': 'weeks',
      'MONTHLY': 'months',
      'YEARLY': 'years',
    };
    return 'every $n ${plural[m.group(1)]}';
  }

  /// todo.txt `rec:` value (1d/2w/…) for simple rules; null for anything the
  /// format can't say (e.g. BYDAY) rather than exporting a wrong rule.
  static String? _recTag(String rule) {
    final m = _simpleRule.firstMatch(rule);
    if (m == null) return null;
    const unit = {'DAILY': 'd', 'WEEKLY': 'w', 'MONTHLY': 'm', 'YEARLY': 'y'};
    return '${m.group(2) ?? '1'}${unit[m.group(1)]}';
  }

  /// Returns (lists, todos) imported. Throws [FormatException] on
  /// malformed input; nothing is written in that case.
  Future<(int, int)> importJson(String json) async {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(json) as Map<String, dynamic>;
    } on FormatException {
      throw const FormatException('Not valid JSON');
    }
    if (map['v'] != formatVersion || map['app'] != 'knot') {
      throw const FormatException('Not a Knot export file');
    }
    final lists = [
      for (final l in (map['lists'] as List<dynamic>? ?? []))
        TodoList.fromJson(l as Map<String, dynamic>),
    ];
    final todos = [
      for (final t in (map['todos'] as List<dynamic>? ?? []))
        Todo.fromJson(t as Map<String, dynamic>),
    ];

    final stamp = hlc.send();
    await db.transaction(() async {
      for (final list in lists) {
        await db.todoLists.insertOnConflictUpdate(list);
        await stampFields(
          db: db,
          entity: 'todo_lists',
          rowId: list.id,
          fields: syncColumns['todo_lists']!.keys,
          hlc: stamp,
        );
      }
      for (final todo in todos) {
        await db.todos.insertOnConflictUpdate(todo);
        await stampFields(
          db: db,
          entity: 'todos',
          rowId: todo.id,
          fields: syncColumns['todos']!.keys,
          hlc: stamp,
        );
      }
    });
    return (lists.length, todos.length);
  }
}
