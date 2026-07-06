import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/sync/device_identity.dart';

/// Key store that always throws — a keychain without its entitlement.
class _BrokenKeyStore implements KeyStore {
  @override
  Future<String?> read(String key) async => throw Exception('no entitlement');

  @override
  Future<void> write(String key, String value) async =>
      throw Exception('no entitlement');
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('key_store_test');
  });

  tearDown(() => tmp.delete(recursive: true));

  group('FileKeyStore', () {
    test('round-trips values and persists across instances', () async {
      final store = FileKeyStore(() async => tmp);
      expect(await store.read('k'), isNull);
      await store.write('k', 'v1');
      await store.write('other', 'v2');
      expect(await FileKeyStore(() async => tmp).read('k'), 'v1');
      expect(await FileKeyStore(() async => tmp).read('other'), 'v2');
    });

    test('creates the directory on demand', () async {
      final nested = Directory('${tmp.path}/a/b');
      final store = FileKeyStore(() async => nested);
      await store.write('k', 'v');
      expect(await store.read('k'), 'v');
    });
  });

  group('FallbackKeyStore', () {
    test('uses the file store when the keychain throws', () async {
      final store = FallbackKeyStore(
        primary: _BrokenKeyStore(),
        fallback: FileKeyStore(() async => tmp),
      );
      await store.write('k', 'v');
      expect(await store.read('k'), 'v');
    });

    test('prefers the primary when it works', () async {
      final primary = InMemoryKeyStore();
      final store = FallbackKeyStore(
        primary: primary,
        fallback: FileKeyStore(() async => tmp),
      );
      await store.write('k', 'v');
      expect(await primary.read('k'), 'v');
      expect(File('${tmp.path}/key_store.json').existsSync(), isFalse);
    });

    test('falls through to the file value when primary has none', () async {
      final fallback = FileKeyStore(() async => tmp);
      await fallback.write('k', 'from-file');
      final store = FallbackKeyStore(
        primary: InMemoryKeyStore(),
        fallback: fallback,
      );
      expect(await store.read('k'), 'from-file');
    });

    test('identity survives via fallback end to end', () async {
      final store = FallbackKeyStore(
        primary: _BrokenKeyStore(),
        fallback: FileKeyStore(() async => tmp),
      );
      final first = await DeviceIdentity.loadOrCreate(store, 'device-1');
      final second = await DeviceIdentity.loadOrCreate(store, 'device-1');
      expect((await second.publicKey).bytes, (await first.publicKey).bytes);
    });
  });
}
