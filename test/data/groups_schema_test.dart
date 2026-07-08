import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/repositories/group_repository.dart';
import 'package:todoapp/data/repositories/list_repository.dart';
import 'package:todoapp/data/sync/lww_applier.dart';
import 'package:todoapp/data/sync/sync_fields.dart';

/// Schema v4 (TASKS 8.2, ADR 0004): sync_groups + group_members +
/// todo_lists.groupId, replicating through the same LWW machinery as
/// everything else.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late HlcClock clock;
  late GroupRepository groups;
  late ListRepository lists;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = HlcClock(
      nodeId: 'dev-a',
      clock: FixedClock(DateTime.utc(2026, 7, 8, 12)),
    );
    groups = GroupRepository(db, clock);
    lists = ListRepository(db, clock);
  });
  tearDown(() => db.close());

  group('GroupRepository', () {
    test(
      'create stamps every synced field, not the local account ref',
      () async {
        final created = await groups.create(
          name: 'Family',
          backendKind: 'icloud',
          localAccountRef: '/private/icloud/docs',
        );

        expect(created.name, 'Family');
        expect(created.backendKind, 'icloud');
        expect(created.localAccountRef, '/private/icloud/docs');
        expect(created.deleted, isFalse);

        final stamped = await db.fieldClocks.select().get();
        final fields = stamped
            .where((c) => c.entity == 'sync_groups' && c.rowId == created.id)
            .map((c) => c.fieldName)
            .toSet();
        // local_account_ref is device-local and must never be stamped.
        expect(fields, {'name', 'backendKind', 'deleted'});
      },
    );

    test('membership rows use the deterministic composite id', () async {
      final family = await groups.create(name: 'Family', backendKind: 'webdav');
      await db.devices.insertOne(
        DevicesCompanion.insert(
          id: 'dev-b',
          name: 'Wife iPhone',
          platform: 'ios',
          publicKey: 'pk',
        ),
      );

      await groups.addMember(family.id, 'dev-b');
      expect(
        (await db.groupMembers.select().getSingle()).id,
        '${family.id}:dev-b',
      );
      expect(await groups.watchMemberIds(family.id).first, ['dev-b']);

      // Leave tombstones; rejoin clears it (idempotent add).
      await groups.removeMember(family.id, 'dev-b');
      expect(await groups.watchMemberIds(family.id).first, isEmpty);
      await groups.addMember(family.id, 'dev-b');
      expect(await groups.watchMemberIds(family.id).first, ['dev-b']);
    });

    test('dissolve tombstones, never deletes the row (invariant 5)', () async {
      final g = await groups.create(name: 'Friends', backendKind: 'dropbox');
      await groups.dissolve(g.id);

      expect(await groups.watchAll().first, isEmpty);
      expect((await db.syncGroups.select().getSingle()).deleted, isTrue);
    });

    test('setLocalAccountRef writes without stamping', () async {
      final g = await groups.create(name: 'Friends', backendKind: 'webdav');
      final stampsBefore = (await db.fieldClocks.select().get()).length;

      await groups.setLocalAccountRef(g.id, 'acct-42');

      expect((await groups.getById(g.id))!.localAccountRef, 'acct-42');
      expect((await db.fieldClocks.select().get()).length, stampsBefore);
    });
  });

  group('list ↔ group assignment', () {
    test(
      'lists default to local-only (null group) and can be assigned',
      () async {
        final list = await lists.create(name: 'Groceries');
        expect(list.groupId, isNull);

        final family = await groups.create(
          name: 'Family',
          backendKind: 'icloud',
        );
        await lists.setGroup(list.id, family.id);
        expect((await lists.getById(list.id))!.groupId, family.id);

        // Back to local-only.
        await lists.setGroup(list.id, null);
        expect((await lists.getById(list.id))!.groupId, isNull);
      },
    );

    test('unknown group id is rejected by the FK', () async {
      final list = await lists.create(name: 'Groceries');
      expect(() => lists.setGroup(list.id, 'no-such-group'), throwsA(anything));
    });
  });

  group('LWW apply for group entities', () {
    Future<bool> apply(
      AppDatabase target,
      String entity,
      String rowId,
      String field,
      Object? value,
      int ms,
    ) => LwwApplier(target).apply(
      FieldWrite(
        entity: entity,
        rowId: rowId,
        field: field,
        value: value,
        hlc: Hlc(ms, 0, 'dev-remote'),
      ),
    );

    test(
      'sync_groups rows spring into existence from any field write',
      () async {
        expect(
          await apply(db, 'sync_groups', 'g1', 'name', 'Family', 10),
          isTrue,
        );
        expect(
          await apply(db, 'sync_groups', 'g1', 'backendKind', 'icloud', 11),
          isTrue,
        );

        final row = await db.syncGroups.select().getSingle();
        expect(row.name, 'Family');
        expect(row.backendKind, 'icloud');
        expect(row.localAccountRef, isNull); // Never carried by sync.
      },
    );

    test(
      'out-of-order membership: FK targets spring before the value lands',
      () async {
        // groupId write arrives before the group's own writes and before the
        // device row exists — both referenced rows must spring.
        expect(
          await apply(db, 'group_members', 'g1:devX', 'groupId', 'g1', 5),
          isTrue,
        );
        expect(
          await apply(db, 'group_members', 'g1:devX', 'deviceId', 'devX', 6),
          isTrue,
        );

        expect((await db.syncGroups.select().getSingle()).id, 'g1');
        expect((await db.devices.select().getSingle()).id, 'devX');
        final member = await db.groupMembers.select().getSingle();
        expect(member.groupId, 'g1');
        expect(member.deviceId, 'devX');
      },
    );

    test('todo_lists.groupId write springs the group row first', () async {
      expect(
        await apply(db, 'todo_lists', 'l1', 'name', 'Family list', 5),
        isTrue,
      );
      expect(await apply(db, 'todo_lists', 'l1', 'groupId', 'g9', 6), isTrue);

      expect((await db.syncGroups.select().getSingle()).id, 'g9');
      expect((await db.todoLists.select().getSingle()).groupId, 'g9');
    });

    test('older groupId write loses LWW', () async {
      final list = await lists.create(name: 'Groceries');
      final family = await groups.create(name: 'Family', backendKind: 'icloud');
      await lists.setGroup(list.id, family.id); // Stamped at fixed clock time.

      // A remote write stamped in the distant past must lose.
      expect(
        await apply(db, 'todo_lists', list.id, 'groupId', null, 1000),
        isFalse,
      );
      expect((await lists.getById(list.id))!.groupId, family.id);
    });
  });

  group('schema migration v3 → v4', () {
    test(
      'adds the tables and column; existing lists stay local-only',
      () async {
        // Simulate a v3 database: build current schema, then drop the v4
        // bits and re-run the migration path.
        final raw = NativeDatabase.memory();
        final old = AppDatabase(raw);
        await old.customStatement('PRAGMA foreign_keys = OFF');
        await old.customStatement('DROP TABLE sync_groups');
        await old.customStatement('DROP TABLE group_members');
        await old.customStatement(
          'ALTER TABLE todo_lists DROP COLUMN group_id',
        );
        await old.todoLists.insertOne(
          TodoListsCompanion.insert(id: 'l1', name: 'Pre-groups list'),
        );

        final m = old.createMigrator();
        await old.migration.onUpgrade(m, 3, 4);

        final migrated = await old.todoLists.select().getSingle();
        expect(migrated.groupId, isNull); // Local-only, unchanged behavior.
        expect(await old.syncGroups.select().get(), isEmpty);
        expect(await old.groupMembers.select().get(), isEmpty);
        await old.close();
      },
    );
  });

  group('sync field allowlist', () {
    test('stamping an unknown group field is rejected', () {
      expect(
        () => stampFields(
          db: db,
          entity: 'sync_groups',
          rowId: 'g1',
          fields: const ['localAccountRef'],
          hlc: clock.send(),
        ),
        throwsArgumentError,
      );
    });
  });
}
