import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/sync/lan_transport.dart';

import '../support/simulated_device.dart';

void main() {
  final start = DateTime.utc(2026, 7, 5, 12);
  late SecretKey groupKey;
  late Device a;
  late Device b;
  late LanSyncServer server;
  late int visibleTodoNotices;

  setUp(() async {
    groupKey = SecretKey(List<int>.generate(32, (i) => (i * 13 + 1) % 256));
    a = Device('aa', start);
    b = Device('bb', start.add(const Duration(seconds: 5)));
    visibleTodoNotices = 0;
    server = LanSyncServer(
      engine: a.engine,
      groupKey: groupKey,
      onVisibleTodosChanged: () async {
        visibleTodoNotices++;
      },
    );
  });

  tearDown(() async {
    await server.stop();
    await a.close();
    await b.close();
  });

  Future<int> clientSync(Device d, int port, {SecretKey? key}) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    return LanSync.sync(
      socket: socket,
      engine: d.engine,
      groupKey: key ?? groupKey,
    );
  }

  test('one session syncs both directions over loopback', () async {
    await a.todos.create(title: 'from server');
    await b.todos.create(title: 'from client');
    final port = await server.start();

    final applied = await clientSync(b, port);
    expect(applied, greaterThan(0));
    // Server applies the client's deltas asynchronously; wait for them.
    await _eventually(() async => (await a.db.todos.all().get()).length == 2);

    expect(await a.dump(), await b.dump());
    expect(visibleTodoNotices, 1);
  });

  test('second session is a near no-op and still converges', () async {
    await a.todos.create(title: 't');
    final port = await server.start();

    await clientSync(b, port);
    await _eventually(() async => (await b.db.todos.all().get()).length == 1);
    expect(await clientSync(b, port), 0);
    expect(await b.dump(), await a.dump());
  });

  test('concurrent edits merge per-field through one session', () async {
    await a.todos.create(title: 'shared');
    final port = await server.start();
    await clientSync(b, port);
    await _eventually(() async => (await b.db.todos.all().get()).length == 1);

    final id = (await b.db.todos.all().getSingle()).id;
    await a.todos.edit(id, title: const Value('server title'));
    await b.todos.edit(id, priority: const Value(3));

    await clientSync(b, port);
    await _eventually(() async {
      final row = await a.db.todos.all().getSingle();
      return row.priority == 3;
    });

    expect(await a.dump(), await b.dump());
    final merged = await b.db.todos.all().getSingle();
    expect(merged.title, 'server title');
    expect(merged.priority, 3);
  });

  test('wrong group key: nothing syncs, nothing crashes', () async {
    await a.todos.create(title: 'protected');
    final port = await server.start();

    final wrongKey = SecretKey(List<int>.filled(32, 9));
    expect(await clientSync(b, port, key: wrongKey), 0);
    expect(await b.db.todos.all().get(), isEmpty);

    // Server keeps serving properly-keyed clients afterwards.
    await clientSync(b, port);
    await _eventually(() async => (await b.db.todos.all().get()).length == 1);
  });

  test('garbage bytes on the socket do not kill the server', () async {
    await a.todos.create(title: 't');
    final port = await server.start();

    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    socket.add(List<int>.filled(64, 0x41));
    await socket.flush();
    socket.destroy();

    await clientSync(b, port);
    await _eventually(() async => (await b.db.todos.all().get()).length == 1);
  });
}

Future<void> _eventually(Future<bool> Function() check) async {
  for (var i = 0; i < 100; i++) {
    if (await check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('condition not reached within 2s');
}
