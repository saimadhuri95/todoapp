import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/app/sync_service.dart';
import 'package:todoapp/data/sync/device_identity.dart';
import 'package:todoapp/data/sync/mailbox_store.dart';
import 'package:todoapp/data/sync/mailbox_transport.dart';
import 'package:todoapp/data/sync/sync_orchestrator.dart';

import '../support/simulated_device.dart';

/// Multi-mailbox orchestration (TASKS 8.6, ADR 0004): one transport per
/// configured group per pass, each failing soft individually.
class ThrowingStore implements MailboxStore {
  @override
  Future<List<String>> listDeviceDirs() =>
      throw const SocketException('backend down');

  @override
  Future<List<String>> listFiles(String deviceDir) =>
      throw const SocketException('backend down');

  @override
  Future<List<int>?> read(String deviceDir, String name) =>
      throw const SocketException('backend down');

  @override
  Future<void> write(String deviceDir, String name, List<int> bytes) =>
      throw const SocketException('backend down');

  @override
  Future<void> delete(String deviceDir, String name) =>
      throw const SocketException('backend down');

  @override
  Future<void> wipeAll() => throw const SocketException('backend down');
}

void main() {
  final start = DateTime.utc(2026, 7, 8, 12);
  late Directory personalRoot;
  late Directory groupRoot;
  late SecretKey personalKey;
  late SecretKey groupKey;
  late Device a;
  late Device b;

  setUp(() async {
    personalRoot = await Directory.systemTemp.createTemp('personal');
    groupRoot = await Directory.systemTemp.createTemp('group');
    personalKey = SecretKey(List<int>.generate(32, (i) => i));
    groupKey = SecretKey(List<int>.generate(32, (i) => 255 - i));
    a = Device('aa', start);
    b = Device('bb', start.add(const Duration(seconds: 3)));
  });

  tearDown(() async {
    await a.close();
    await b.close();
    await personalRoot.delete(recursive: true);
    await groupRoot.delete(recursive: true);
  });

  MailboxTransport personalBox(Device d) => MailboxTransport(
    root: personalRoot,
    engine: d.engine,
    db: d.db,
    deviceId: d.id,
    groupKey: personalKey,
  );

  MailboxTransport groupBox(Device d, String gid) => MailboxTransport(
    root: groupRoot,
    engine: d.engine,
    db: d.db,
    deviceId: d.id,
    groupKey: groupKey,
    groupId: gid,
  );

  test(
    'one pass serves the personal mailbox and every group mailbox',
    () async {
      final family = await a.groups.create(
        name: 'Family',
        backendKind: 'folder',
      );
      final shared = await a.lists.create(name: 'Groceries');
      await a.lists.setGroup(shared.id, family.id);
      await a.todos.create(title: 'milk', listId: shared.id);
      await a.todos.create(
        title: 'private',
        listId: (await a.lists.create(name: 'Local')).id,
      );

      final report = await SyncOrchestrator(
        engine: a.engine,
        groupKey: personalKey,
        mailbox: personalBox(a),
        groupMailboxes: [groupBox(a, family.id)],
      ).syncNow();

      expect(report.mailboxPublished, greaterThan(0));
      expect(report.errors, isEmpty);
      // Both physical mailboxes got this device's outbox.
      expect(Directory('${personalRoot.path}/aa').existsSync(), isTrue);
      expect(Directory('${groupRoot.path}/aa').existsSync(), isTrue);

      // B consumes only the group mailbox: sees shared data, not private.
      await SyncOrchestrator(
        engine: b.engine,
        groupKey: personalKey,
        groupMailboxes: [groupBox(b, family.id)],
      ).syncNow();
      final bTitles = (await b.db.todos.select().get()).map((t) => t.title);
      expect(bTitles, contains('milk'));
      expect(bTitles, isNot(contains('private')));
    },
  );

  test('a dead group backend fails soft; the others still sync', () async {
    final family = await a.groups.create(name: 'Family', backendKind: 'folder');
    final shared = await a.lists.create(name: 'Groceries');
    await a.lists.setGroup(shared.id, family.id);
    await a.todos.create(title: 'milk', listId: shared.id);

    final dead = MailboxTransport.withStore(
      store: ThrowingStore(),
      engine: a.engine,
      db: a.db,
      deviceId: a.id,
      groupKey: groupKey,
      groupId: 'friends',
    );

    final report = await SyncOrchestrator(
      engine: a.engine,
      groupKey: personalKey,
      // Dead transport first: the healthy ones after it must still run.
      groupMailboxes: [dead, groupBox(a, family.id)],
    ).syncNow();

    expect(report.errors, hasLength(1));
    expect(report.errors.single, contains('mailbox[friends]'));
    expect(report.mailboxPublished, greaterThan(0));
    expect(Directory('${groupRoot.path}/aa').existsSync(), isTrue);
  });

  test('buildOrchestrator wires one transport per joined group', () async {
    final keyStore = InMemoryKeyStore();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(a.db),
        deviceIdProvider.overrideWithValue(a.id),
        clockProvider.overrideWithValue(a.clock),
        keyStoreProvider.overrideWithValue(keyStore),
      ],
    );
    addTearDown(container.dispose);

    // A folder-backed group, joined (key exists) and wired (local ref).
    final family = await a.groups.create(
      name: 'Family',
      backendKind: 'folder',
      localAccountRef: groupRoot.path,
    );
    await container
        .read(pairingServiceProvider)
        .loadOrCreateGroupKeyFor(family.id);
    // A second group that is NOT wired up: no key, no ref — skipped.
    await a.groups.create(name: 'Pending', backendKind: 'webdav');

    final orchestrator = await buildOrchestrator(container);

    expect(orchestrator, isNotNull);
    expect(orchestrator!.mailboxes, hasLength(1));
    expect(orchestrator.mailboxes.single.groupId, family.id);

    final shared = await a.lists.create(name: 'Groceries');
    await a.lists.setGroup(shared.id, family.id);
    await orchestrator.syncNow();
    expect(Directory('${groupRoot.path}/${a.id}').existsSync(), isTrue);
  });
}
