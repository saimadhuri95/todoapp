import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/db/database.dart' hide Device;
import 'package:todoapp/data/sync/mailbox_transport.dart';
import 'package:todoapp/data/sync/sync_fields.dart';

import '../support/simulated_device.dart';

/// Scoped changesets (TASKS 8.3, ADR 0004): a sharing group's mailbox
/// carries only its own lists/todos/membership — and the per-scope
/// convergence gate that guards invariant 2 inside a scope.
void main() {
  final start = DateTime.utc(2026, 7, 8, 12);
  late Directory root;
  late SecretKey groupKey;
  late Device a;
  late Device b;

  MailboxTransport transportFor(Device d, {String? groupId}) =>
      MailboxTransport(
        root: root,
        engine: d.engine,
        db: d.db,
        deviceId: d.id,
        groupKey: groupKey,
        groupId: groupId,
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('scoped_mailbox');
    groupKey = SecretKey(List<int>.generate(32, (i) => i * 3 % 256));
    a = Device('aa', start);
    b = Device('bb', start.add(const Duration(seconds: 3)));
  });

  tearDown(() async {
    await a.close();
    await b.close();
    await root.delete(recursive: true);
  });

  test('scoped changesFor carries only the group rows', () async {
    final local = await a.lists.create(name: 'Private');
    await a.todos.create(title: 'secret', listId: local.id);
    final family = await a.groups.create(name: 'Family', backendKind: 'webdav');
    final shared = await a.lists.create(name: 'Groceries');
    await a.lists.setGroup(shared.id, family.id);
    final milk = await a.todos.create(title: 'milk', listId: shared.id);
    await a.db.devices.insertOne(
      DevicesCompanion.insert(
        id: 'aa',
        name: 'My iPhone',
        platform: 'ios',
        publicKey: 'pk',
      ),
    );
    // Pairing stamps device rows in production; mirror that here.
    await stampFields(
      db: a.db,
      entity: 'devices',
      rowId: 'aa',
      fields: syncColumns['devices']!.keys,
      hlc: a.hlc.send(),
    );
    await a.groups.addMember(family.id, 'aa');

    final scoped = await a.engine.changesFor(const {}, groupId: family.id);

    final byEntity = <String, Set<String>>{};
    for (final w in scoped.writes) {
      byEntity.putIfAbsent(w.entity, () => {}).add(w.rowId);
    }
    expect(byEntity['todo_lists'], {shared.id});
    expect(byEntity['todos'], {milk.id});
    expect(byEntity['sync_groups'], {family.id});
    expect(byEntity['group_members'], {'${family.id}:aa'});
    expect(byEntity['devices'], {'aa'});
    // Nothing from the private list leaks into the scope.
    final rowIds = scoped.writes.map((w) => w.rowId).toSet();
    expect(rowIds.contains(local.id), isFalse);
  });

  test('a group mailbox replicates its scope and nothing else', () async {
    final local = await a.lists.create(name: 'Private');
    await a.todos.create(title: 'secret', listId: local.id);
    final family = await a.groups.create(name: 'Family', backendKind: 'webdav');
    final shared = await a.lists.create(name: 'Groceries');
    await a.lists.setGroup(shared.id, family.id);
    await a.todos.create(title: 'milk', listId: shared.id);

    expect(await transportFor(a, groupId: family.id).publish(), greaterThan(0));
    expect(await transportFor(b, groupId: family.id).consume(), greaterThan(0));

    // B has the shared list, its todo, and the group row…
    expect((await b.db.todoLists.select().get()).map((l) => l.id), [shared.id]);
    expect((await b.db.todos.select().getSingle()).title, 'milk');
    expect((await b.db.syncGroups.select().getSingle()).name, 'Family');
    // …and never saw the private list or its todo.
    expect(
      (await b.db.todoLists.select().get()).map((l) => l.id),
      isNot(contains(local.id)),
    );
  });

  test('moving a list into a group republishes its full history', () async {
    final family = await a.groups.create(name: 'Family', backendKind: 'webdav');
    final shared = await a.lists.create(name: 'Groceries');
    await a.lists.setGroup(shared.id, family.id);
    // First publish writes the vector marker for the scope.
    await transportFor(a, groupId: family.id).publish();
    await transportFor(b, groupId: family.id).consume();

    // An old list, created *before* that marker, moves in later. Its
    // original stamps predate the marker — setGroup's re-stamp is what
    // keeps it publishable.
    final old = await a.lists.create(name: 'Chores');
    final sweep = await a.todos.create(title: 'sweep', listId: old.id);
    a.clock.advance(const Duration(minutes: 1));
    await a.lists.setGroup(old.id, family.id);

    expect(await transportFor(a, groupId: family.id).publish(), greaterThan(0));
    await transportFor(b, groupId: family.id).consume();

    final bLists = (await b.db.todoLists.select().get()).map((l) => l.id);
    expect(bLists, containsAll([shared.id, old.id]));
    expect(
      (await b.db.todos.select().get()).map((t) => t.id),
      contains(sweep.id),
    );
  });

  test('moving a list out stops publishing its updates to the group', () async {
    final family = await a.groups.create(name: 'Family', backendKind: 'webdav');
    final shared = await a.lists.create(name: 'Groceries');
    await a.lists.setGroup(shared.id, family.id);
    await transportFor(a, groupId: family.id).publish();
    await transportFor(b, groupId: family.id).consume();

    a.clock.advance(const Duration(minutes: 1));
    await a.lists.setGroup(shared.id, null); // Back to local-only.
    await a.lists.rename(shared.id, 'Groceries v2');
    await transportFor(a, groupId: family.id).publish();
    await transportFor(b, groupId: family.id).consume();

    // Past members keep the history they received (ADR 0004) — but the
    // post-move rename never reaches them.
    expect((await b.db.todoLists.select().getSingle()).name, 'Groceries');
  });

  test(
    'per-scope convergence gate: shared scope converges, locals stay put',
    () async {
      // A creates the group + shared list; B joins by consuming.
      final family = await a.groups.create(
        name: 'Family',
        backendKind: 'webdav',
      );
      final shared = await a.lists.create(name: 'Groceries');
      await a.lists.setGroup(shared.id, family.id);
      final milk = await a.todos.create(title: 'milk', listId: shared.id);
      await transportFor(a, groupId: family.id).publish();
      await transportFor(b, groupId: family.id).consume();

      // Each device also has private local data.
      await a.todos.create(
        title: 'a-private',
        listId: (await a.lists.create(name: 'A local')).id,
      );
      await b.todos.create(
        title: 'b-private',
        listId: (await b.lists.create(name: 'B local')).id,
      );

      // Concurrent edits to the shared todo on both sides.
      a.clock.advance(const Duration(seconds: 10));
      b.clock.advance(const Duration(seconds: 20));
      await a.todos.edit(milk.id, title: const Value('milk (2L)'));
      await b.todos.edit(milk.id, priority: const Value(2));
      final extra = await b.todos.create(title: 'eggs', listId: shared.id);

      // Two full rounds so relays settle.
      for (var i = 0; i < 2; i++) {
        await transportFor(a, groupId: family.id).publish();
        await transportFor(b, groupId: family.id).publish();
        await transportFor(a, groupId: family.id).consume();
        await transportFor(b, groupId: family.id).consume();
      }

      Future<List<String>> sharedDump(Device d) async {
        final todos =
            await (d.db.todos.select()
                  ..where((t) => t.listId.equals(shared.id))
                  ..orderBy([(t) => OrderingTerm(expression: t.id)]))
                .get();
        return [
          for (final t in todos)
            '${t.id}|${t.title}|${t.priority}|${t.deleted}',
        ];
      }

      // The shared scope converged to identical state…
      final aDump = await sharedDump(a);
      expect(aDump, await sharedDump(b));
      expect(aDump.join(), contains('milk (2L)'));
      expect(aDump.join(), contains('eggs'));
      expect((await sharedDump(a)).length, 2);
      expect(aDump.join(), contains(extra.id));

      // …while each device's private data never crossed.
      final aTitles = (await a.db.todos.select().get()).map((t) => t.title);
      final bTitles = (await b.db.todos.select().get()).map((t) => t.title);
      expect(aTitles, isNot(contains('b-private')));
      expect(bTitles, isNot(contains('a-private')));
    },
  );

  test(
    'pending count is scoped: local writes do not count for the group',
    () async {
      final family = await a.groups.create(
        name: 'Family',
        backendKind: 'webdav',
      );
      final shared = await a.lists.create(name: 'Groceries');
      await a.lists.setGroup(shared.id, family.id);
      await transportFor(a, groupId: family.id).publish();

      await a.todos.create(
        title: 'private',
        listId: (await a.lists.create(name: 'Local')).id,
      );

      expect(
        await transportFor(a, groupId: family.id).pendingOutboundCount(),
        0,
      );
      // The unscoped (personal) view still sees them.
      expect(await transportFor(a).pendingOutboundCount(), greaterThan(0));
    },
  );
}
