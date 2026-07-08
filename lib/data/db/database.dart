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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(devices, devices.deleted);
        await m.addColumn(syncLog, syncLog.lastSyncedAtMs);
      }
      if (from < 3) {
        await m.addColumn(todos, todos.alarmOffsetsJson);
        await m.addColumn(todos, todos.lastDismissedMs);
        await m.addColumn(todos, todos.snoozeUntilMs);
      }
      if (from < 4) {
        // Sharing groups (ADR 0004): existing lists keep groupId = null,
        // i.e. stay local-only — migration changes nothing user-visible.
        await m.createTable(syncGroups);
        await m.createTable(groupMembers);
        await m.addColumn(todoLists, todoLists.groupId);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
