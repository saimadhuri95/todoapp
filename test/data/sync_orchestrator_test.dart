import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show TableOrViewStatements;
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/sync/lan_transport.dart';
import 'package:todoapp/data/sync/mailbox_transport.dart';
import 'package:todoapp/data/sync/sync_orchestrator.dart';

import 'sync_engine_test.dart' show Device;

void main() {
  final start = DateTime.utc(2026, 7, 5, 12);
  late SecretKey groupKey;
  late Device a;
  late Device b;

  setUp(() {
    groupKey = SecretKey(List<int>.generate(32, (i) => (i * 31 + 5) % 256));
    a = Device('aa', start);
    b = Device('bb', start.add(const Duration(seconds: 5)));
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('mailbox + LAN in one pass; both directions converge', () async {
    final root = await Directory.systemTemp.createTemp('orch_test');
    addTearDown(() => root.delete(recursive: true));
    final server = LanSyncServer(engine: a.engine, groupKey: groupKey);
    final port = await server.start();
    addTearDown(server.stop);

    await a.todos.create(title: 'on a');
    await b.todos.create(title: 'on b');

    MailboxTransport boxFor(Device d) => MailboxTransport(
      root: root,
      engine: d.engine,
      db: d.db,
      deviceId: d.id,
      groupKey: groupKey,
    );

    final orchestratorA = SyncOrchestrator(
      engine: a.engine,
      groupKey: groupKey,
      mailbox: boxFor(a),
    );
    final orchestratorB = SyncOrchestrator(
      engine: b.engine,
      groupKey: groupKey,
      mailbox: boxFor(b),
      discoverPeers: () async => [(host: '127.0.0.1', port: port)],
    );

    final reportA = await orchestratorA.syncNow(); // publishes A's state
    expect(reportA.mailboxPublished, greaterThan(0));

    final reportB = await orchestratorB.syncNow();
    expect(reportB.mailboxApplied, greaterThan(0)); // got A via folder
    expect(reportB.lanPeersReached, 1); // pushed its own via LAN
    expect(reportB.errors, isEmpty);

    // A gets B's todo via the LAN session (server applies asynchronously).
    for (var i = 0; i < 100; i++) {
      if ((await a.db.todos.all().get()).length == 2) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await a.db.todos.all().get(), hasLength(2));
  });

  test('unreachable LAN peer is an error entry, not a crash', () async {
    final orchestrator = SyncOrchestrator(
      engine: a.engine,
      groupKey: groupKey,
      discoverPeers: () async => [(host: '127.0.0.1', port: 1)],
      connectTimeout: const Duration(milliseconds: 300),
    );

    final report = await orchestrator.syncNow();
    expect(report.lanPeersReached, 0);
    expect(report.errors, hasLength(1));
  });

  test('reentrant syncNow is skipped', () async {
    final orchestrator = SyncOrchestrator(
      engine: a.engine,
      groupKey: groupKey,
      // Slow discovery keeps the first pass running.
      discoverPeers: () async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return [];
      },
    );

    final first = orchestrator.syncNow();
    final second = await orchestrator.syncNow();
    expect(second.skipped, isTrue);
    expect((await first).skipped, isFalse);
  });

  test('periodic start syncs without manual calls, stop halts it', () async {
    final root = await Directory.systemTemp.createTemp('orch_timer');
    addTearDown(() => root.delete(recursive: true));
    await a.todos.create(title: 'tick');

    final orchestrator = SyncOrchestrator(
      engine: a.engine,
      groupKey: groupKey,
      mailbox: MailboxTransport(
        root: root,
        engine: a.engine,
        db: a.db,
        deviceId: a.id,
        groupKey: groupKey,
      ),
    );
    orchestrator.start(period: const Duration(milliseconds: 50));
    addTearDown(orchestrator.stop);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    orchestrator.stop();

    // The periodic pass published A's outbox.
    expect(Directory('${root.path}/aa').existsSync(), isTrue);
  });
}
