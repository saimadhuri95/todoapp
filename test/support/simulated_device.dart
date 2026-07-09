import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/repositories/group_repository.dart';
import 'package:todoapp/data/repositories/list_repository.dart';
import 'package:todoapp/data/repositories/todo_repository.dart';
import 'package:todoapp/data/sync/sync_engine.dart';

/// One simulated device: its own db, clock, repos, and sync engine.
class Device {
  Device(this.id, DateTime start)
    : db = _openMemoryDb(),
      clock = FixedClock(start) {
    hlc = HlcClock(nodeId: id, clock: clock);
    todos = TodoRepository(db, hlc);
    lists = ListRepository(db, hlc);
    groups = GroupRepository(db, hlc);
    engine = SyncEngine(db: db, hlcClock: hlc, deviceId: id);
  }

  final String id;
  final AppDatabase db;
  final FixedClock clock;
  late final HlcClock hlc;
  late final TodoRepository todos;
  late final ListRepository lists;
  late final GroupRepository groups;
  late final SyncEngine engine;

  static AppDatabase _openMemoryDb() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return AppDatabase(NativeDatabase.memory());
  }

  Future<void> close() => db.close();

  /// Canonical dump of synced state for convergence comparison.
  Future<String> dump() async {
    final todosRows =
        await (db.todos.select()
              ..orderBy([(t) => OrderingTerm(expression: t.id)]))
            .get();
    final listRows =
        await (db.todoLists.select()
              ..orderBy([(l) => OrderingTerm(expression: l.id)]))
            .get();
    final clockRows =
        await (db.fieldClocks.select()..orderBy([
              (c) => OrderingTerm(expression: c.entity),
              (c) => OrderingTerm(expression: c.rowId),
              (c) => OrderingTerm(expression: c.fieldName),
            ]))
            .get();
    return [
      for (final t in todosRows)
        'T|${t.id}|${t.listId}|${t.title}|${t.notes}|${t.dueAtMs}'
            '|${t.recurrenceRule}|${t.completedAtMs}|${t.priority}'
            '|${t.tagsJson}|${t.deleted}|${t.alarmOffsetsJson}'
            '|${t.lastDismissedMs}|${t.snoozeUntilMs}',
      for (final l in listRows)
        'L|${l.id}|${l.name}|${l.color}|${l.sortOrder}|${l.deleted}',
      for (final c in clockRows)
        'C|${c.entity}|${c.rowId}|${c.fieldName}|${c.hlc}',
    ].join('\n');
  }
}
