import 'dart:convert';

import 'package:drift/drift.dart' show TableOrViewStatements;
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/backup_service.dart';
import 'package:todoapp/data/export_service.dart';

import '../support/simulated_device.dart';

void main() {
  final start = DateTime.utc(2026, 7, 6, 12);
  late Device source;
  late Device target;
  late BackupService backupA;
  late BackupService restoreB;

  setUp(() {
    source = Device('aa', start);
    target = Device('bb', start.add(const Duration(seconds: 3)));
    // Low work factor keeps the pure-Dart KDF fast in tests.
    backupA = BackupService(
      export: ExportService(db: source.db, hlc: source.hlc),
      iterations: 1000,
    );
    restoreB = BackupService(
      export: ExportService(db: target.db, hlc: target.hlc),
      iterations: 1000,
    );
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  test('backup roundtrips todos and lists to another device', () async {
    final list = await source.lists.create(name: 'Groceries', color: 4);
    await source.todos.create(
      title: 'Buy milk',
      listId: list.id,
      priority: 2,
      tags: ['errand'],
    );
    await source.todos.create(title: 'Call plumber');

    final file = await backupA.createBackup('correct horse battery');
    final (lists, todos) = await restoreB.restoreBackup(
      file,
      'correct horse battery',
    );

    expect(lists, 1);
    expect(todos, 2);
    final restored = await target.db.todos.all().get();
    expect(
      restored.map((t) => t.title),
      containsAll(['Buy milk', 'Call plumber']),
    );
  });

  test('the backup file is a versioned envelope with no plaintext', () async {
    await source.todos.create(title: 'Secret errand');
    final file = await backupA.createBackup('pw');
    final env = jsonDecode(file) as Map<String, dynamic>;
    expect(env['app'], 'knot');
    expect(env['kind'], 'knot-backup');
    expect(env['v'], BackupService.formatVersion);
    expect(env['kdf'], 'pbkdf2-hmac-sha256');
    expect(env['iterations'], 1000);
    expect(env['salt'], isA<String>());
    expect(env['payload'], isA<String>());
    // The title must not appear anywhere in the ciphertext envelope.
    expect(file.contains('Secret errand'), isFalse);
  });

  test('wrong passphrase fails with BackupPassphraseError', () async {
    await source.todos.create(title: 'Buy milk');
    final file = await backupA.createBackup('right');
    expect(
      () => restoreB.restoreBackup(file, 'wrong'),
      throwsA(isA<BackupPassphraseError>()),
    );
    // Nothing was imported on failure.
    expect(await target.db.todos.all().get(), isEmpty);
  });

  test('a tampered payload is rejected', () async {
    await source.todos.create(title: 'Buy milk');
    final file = await backupA.createBackup('pw');
    final env = jsonDecode(file) as Map<String, dynamic>;
    final payload = base64Decode(env['salt'] as String);
    // Flip a byte in the salt so the derived key no longer matches.
    payload[0] ^= 0xFF;
    env['salt'] = base64Encode(payload);
    expect(
      () => restoreB.restoreBackup(jsonEncode(env), 'pw'),
      throwsA(isA<BackupPassphraseError>()),
    );
  });

  test('an empty passphrase is refused on create', () {
    expect(() => backupA.createBackup(''), throwsA(isA<FormatException>()));
  });

  test('non-backup files raise a clear FormatException', () {
    expect(
      () => restoreB.restoreBackup('not json at all', 'pw'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => restoreB.restoreBackup('{"app":"other"}', 'pw'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a newer format version is refused', () {
    const env =
        '{"app":"knot","kind":"knot-backup","v":999,'
        '"salt":"AAAA","payload":"AAAA"}';
    expect(
      () => restoreB.restoreBackup(env, 'pw'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a JSON value that is not an object is rejected', () {
    expect(
      () => restoreB.restoreBackup('[1,2,3]', 'pw'),
      throwsA(isA<FormatException>()),
    );
  });

  test('default work factor follows the OWASP recommendation', () {
    final service = BackupService(
      export: ExportService(db: source.db, hlc: source.hlc),
    );
    expect(service.iterations, 210000);
  });
}
