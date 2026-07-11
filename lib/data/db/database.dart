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
  int get schemaVersion => 8;

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
      if (from < 6 && to >= 6) {
        // "Top 3" pins (TASKS.md 6.34): existing todos default to unpinned.
        await m.addColumn(todos, todos.pinned);
      }
      if (from < 7 && to >= 7) {
        // Estimates + energy (TASKS.md 6.35): existing todos stay unestimated.
        await m.addColumn(todos, todos.estimateMinutes);
        await m.addColumn(todos, todos.energy);
      }
      if (from < 8 && to >= 8) {
        // Nag reminders (TASKS.md 6.44): existing todos don't nag.
        await m.addColumn(todos, todos.nagIntervalMinutes);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
