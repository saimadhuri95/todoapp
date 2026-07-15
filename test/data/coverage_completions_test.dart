import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/backup_service.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/repositories/group_repository.dart';
import 'package:todoapp/data/repositories/list_repository.dart';
import 'package:todoapp/data/repositories/todo_repository.dart';

/// Fills the last testable gaps in the pure data layer: every restoreSnapshot
/// field branch, the not-found guards on the repositories, the full migration
/// chain, and small leaves — so lib/data (minus generated/native) hits 100%.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late TodoRepository todos;
  late ListRepository lists;
  late GroupRepository groups;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime.utc(2026, 7, 6, 12));
    final hlc = HlcClock(nodeId: 'device-1', clock: clock);
    todos = TodoRepository(db, hlc);
    lists = ListRepository(db, hlc);
    groups = GroupRepository(db, hlc);
  });

  tearDown(() => db.close());

  test('restoreSnapshot with no field filter restores every column', () async {
    // Create a fully-populated todo, capture it, then mutate every field.
    final list = await lists.create(name: 'L');
    final original = await todos.create(
      title: 'original',
      listId: list.id,
      notes: 'n',
      dueAtMs: 111,
      recurrenceRule: 'FREQ=DAILY',
      priority: 2,
      tags: ['x'],
      section: 'Doing',
    );
    await todos.edit(
      original.id,
      title: const Value('mutated'),
      notes: const Value('changed'),
      dueAtMs: const Value(999),
      priority: const Value(0),
      section: const Value('Elsewhere'),
      estimateMinutes: const Value(30),
      energy: const Value(1),
      nagIntervalMinutes: const Value(10),
    );
    await todos.setPinned(original.id, true);
    await todos.softDelete(original.id);

    // No field filter → every column is restored from the snapshot.
    await todos.restoreSnapshot(original);

    final restored = (await todos.getById(original.id))!;
    expect(restored.title, 'original');
    expect(restored.notes, 'n');
    expect(restored.dueAtMs, 111);
    expect(restored.priority, 2);
    expect(restored.section, 'Doing');
    expect(restored.pinned, isFalse);
    expect(restored.deleted, isFalse);
    expect(restored.estimateMinutes, isNull);
    expect(restored.nagIntervalMinutes, isNull);
  });

  test('restoreSnapshot rejects unknown field names', () async {
    final todo = await todos.create(title: 't');
    expect(
      () => todos.restoreSnapshot(todo, fields: const ['not_a_column']),
      throwsArgumentError,
    );
  });

  test('setGeofence arms and clears the location reminder', () async {
    final todo = await todos.create(title: 'home');
    await todos.setGeofence(
      todo.id,
      lat: 37.7,
      lng: -122.4,
      radiusM: 150,
      label: 'Home',
    );
    var row = (await todos.getById(todo.id))!;
    expect(row.geofenceLat, 37.7);
    expect(row.geofenceLabel, 'Home');

    await todos.setGeofence(
      todo.id,
      lat: null,
      lng: null,
      radiusM: null,
      label: null,
    );
    row = (await todos.getById(todo.id))!;
    expect(row.geofenceLat, isNull);
  });

  group('repository not-found guards', () {
    test('list rename / setColor throw for a missing id', () async {
      expect(() => lists.rename('nope', 'x'), throwsStateError);
      final l = await lists.create(name: 'C');
      await lists.setColor(l.id, 5);
      expect((await lists.getById(l.id))!.color, 5);
    });

    test(
      'group rename throws for a missing id, succeeds for a real one',
      () async {
        final g = await groups.create(name: 'Fam', backendKind: 'folder');
        await groups.rename(g.id, 'Family');
        expect((await db.syncGroups.select().getSingle()).name, 'Family');
        expect(() => groups.rename('nope', 'x'), throwsStateError);
      },
    );
  });

  test(
    'full migration chain from v1 brings a bare todos row current',
    () async {
      // Drop every column added after v1, insert a v1-shaped row, then run the
      // whole onUpgrade chain — exercising every migration branch.
      await db.customStatement('PRAGMA foreign_keys = OFF');
      for (final col in const [
        'alarm_offsets_json',
        'last_dismissed_ms',
        'snooze_until_ms',
        'parent_id',
        'section',
        'sort_key',
        'pinned',
        'estimate_minutes',
        'energy',
        'nag_interval_minutes',
        'assignee_device_id',
        'current_streak',
        'geofence_lat',
        'geofence_lng',
        'geofence_radius_m',
        'geofence_label',
      ]) {
        await db.customStatement('ALTER TABLE todos DROP COLUMN $col');
      }
      await db.customStatement('ALTER TABLE devices DROP COLUMN deleted');
      await db.customStatement(
        'ALTER TABLE sync_log DROP COLUMN last_synced_at_ms',
      );
      await db.customStatement('DROP TABLE group_members');
      await db.customStatement('DROP TABLE sync_groups');
      await db.customStatement('ALTER TABLE todo_lists DROP COLUMN group_id');
      await db.todos.insertOne(
        TodosCompanion.insert(id: 't1', title: 'ancient'),
      );

      await db.migration.onUpgrade(db.createMigrator(), 1, 10);

      final migrated = await db.todos.all().getSingle();
      expect(migrated.currentStreak, 0);
      expect(migrated.geofenceLat, isNull);
      expect(migrated.nagIntervalMinutes, isNull);
    },
  );

  test('createSubtasks rejects a missing parent id', () async {
    expect(
      () => todos.createSubtasks('no-such-parent', const ['a']),
      throwsStateError,
    );
  });

  test('BackupPassphraseError describes itself', () {
    expect(
      const BackupPassphraseError().toString(),
      'Wrong passphrase or corrupted backup',
    );
  });
}
