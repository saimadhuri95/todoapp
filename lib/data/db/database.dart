import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Tests pass `NativeDatabase.memory()`; production uses [open].
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(
    LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      return NativeDatabase.createInBackground(
        File(p.join(dir.path, 'todoapp.sqlite')),
      );
    }),
  );

  @override
  int get schemaVersion => 3;

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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
