import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/sync/mailbox_transport.dart';

import 'sync_engine_test.dart' show Device;

void main() {
  final start = DateTime.utc(2026, 7, 5, 12);
  late Directory root;
  late SecretKey groupKey;
  late Device a;
  late Device b;

  MailboxTransport transportFor(Device d) => MailboxTransport(
    root: root,
    engine: d.engine,
    db: d.db,
    deviceId: d.id,
    groupKey: groupKey,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mailbox_test');
    groupKey = SecretKey(List<int>.generate(32, (i) => i * 7 % 256));
    a = Device('aa', start);
    b = Device('bb', start.add(const Duration(seconds: 5)));
  });

  tearDown(() async {
    await a.close();
    await b.close();
    await root.delete(recursive: true);
  });

  test('publish/consume converges two devices through the folder', () async {
    final list = await a.lists.create(name: 'Inbox');
    await a.todos.create(title: 'Buy milk', listId: list.id);

    expect(await transportFor(a).publish(), greaterThan(0));
    expect(await transportFor(b).consume(), greaterThan(0));

    expect((await b.db.todos.all().getSingle()).title, 'Buy milk');
    expect(await b.dump(), await a.dump());
  });

  test('mailbox files are ciphertext only', () async {
    await a.todos.create(title: 'SUPERSECRET-TITLE');
    await transportFor(a).publish();

    final files = root.listSync(recursive: true).whereType<File>().toList();
    expect(files, isNotEmpty);
    for (final f in files) {
      final bytes = await f.readAsBytes();
      expect(latin1.decode(bytes).contains('SUPERSECRET'), isFalse);
      expect(latin1.decode(bytes).contains('title'), isFalse);
    }
  });

  test('repeat publish and consume are no-ops', () async {
    await a.todos.create(title: 't');
    final ta = transportFor(a);
    final tb = transportFor(b);

    await ta.publish();
    expect(await ta.publish(), 0); // vector marker covers it
    await tb.consume();
    expect(await tb.consume(), 0); // cursor covers it

    // Only one changeset file + vector marker in A's outbox.
    final aFiles = Directory('${root.path}/aa').listSync();
    expect(aFiles, hasLength(2));
  });

  test('bidirectional edits converge via the folder', () async {
    await a.todos.create(title: 'shared');
    await transportFor(a).publish();
    await transportFor(b).consume();
    final id = (await b.db.todos.all().getSingle()).id;

    await a.todos.edit(id, title: const Value('A title'));
    await b.todos.edit(id, priority: const Value(2));
    await transportFor(a).publish();
    await transportFor(b).publish();
    await transportFor(a).consume();
    await transportFor(b).consume();

    expect(await a.dump(), await b.dump());
    final merged = await a.db.todos.all().getSingle();
    expect(merged.title, 'A title');
    expect(merged.priority, 2);
  });

  test('third device catches up from both outboxes', () async {
    final c = Device('cc', start.add(const Duration(seconds: 9)));
    addTearDown(c.close);

    await a.todos.create(title: 'from a');
    await transportFor(a).publish();
    await transportFor(b).consume();
    await b.todos.create(title: 'from b');
    await transportFor(b).publish();

    await transportFor(c).consume();

    expect(await c.db.todos.all().get(), hasLength(2));
    // C must now equal B (which has everything).
    expect(await c.dump(), await b.dump());
  });

  test('corrupt/torn file is skipped and retried without crashing', () async {
    await a.todos.create(title: 'good');
    await transportFor(a).publish();

    // Simulate a torn upload: truncate the changeset file.
    final changesetFile = Directory('${root.path}/aa')
        .listSync()
        .whereType<File>()
        .firstWhere((f) => !f.path.endsWith('vector.bin'));
    final bytes = await changesetFile.readAsBytes();
    await changesetFile.writeAsBytes(bytes.sublist(0, bytes.length ~/ 2));

    expect(await transportFor(b).consume(), 0); // skipped, no crash

    // Cloud drive finishes the upload; retry succeeds.
    await changesetFile.writeAsBytes(bytes, flush: true);
    expect(await transportFor(b).consume(), greaterThan(0));
    expect(await b.dump(), await a.dump());
  });
}
