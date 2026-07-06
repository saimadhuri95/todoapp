import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/hlc.dart';
import 'db/database.dart';
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
