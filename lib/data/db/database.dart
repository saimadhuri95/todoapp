import 'package:drift/drift.dart';

import 'open_connection.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    TodoLists,
    Todos,
    TodoAlarms,
    Devices,
    SyncLog,
    AlarmDismissals,
    FieldClocks,
    SyncGroups,
    GroupMembers,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Tests pass `NativeDatabase.memory()`; production uses [open].
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2 && to >= 2) {
        await m.addColumn(devices, devices.deleted);
        await m.addColumn(syncLog, syncLog.lastSyncedAtMs);
      }
      if (from < 3 && to >= 3) {
        await m.addColumn(todos, todos.alarmOffsetsJson);
        await m.addColumn(todos, todos.lastDismissedMs);
        await m.addColumn(todos, todos.snoozeUntilMs);
      }
      if (from < 4 && to >= 4) {
        // Sharing groups (ADR 0004): existing lists keep groupId = null,
        // i.e. stay local-only — migration changes nothing user-visible.
        await m.createTable(syncGroups);
        await m.createTable(groupMembers);
        await m.addColumn(todoLists, todoLists.groupId);
      }
      if (from < 5 && to >= 5) {
        // Existing todos remain top-level, date-grouped, and in their prior
        // due-date order until users add sections or manually reorder.
        await m.addColumn(todos, todos.parentId);
        await m.addColumn(todos, todos.section);
        await m.addColumn(todos, todos.sortKey);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
