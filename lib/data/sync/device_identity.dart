import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pairing_crypto.dart';

/// Where identity keys live. Production: platform keychain/keystore via
/// [SecureKeyStore]; tests: [InMemoryKeyStore].
abstract interface class KeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureKeyStore implements KeyStore {
  const SecureKeyStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// JSON file in the app's private container (TASKS.md 4.17 fallback).
///
/// Used when the platform keychain is unavailable — on macOS, keychain
/// access needs the Keychain Sharing capability, which is a restricted
/// entitlement that ad-hoc-signed local builds cannot carry. The file lives
/// inside the sandboxed app container and never syncs (invariant 3 covers
/// data leaving the device); still, the keychain is preferred, so flip the
/// capability on once real signing exists (docs/packaging.md).
class FileKeyStore implements KeyStore {
  FileKeyStore(this._directory);

  /// Deferred so the data layer stays free of path_provider; providers
  /// pass `getApplicationSupportDirectory`.
  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}/key_store.json');
  }

  @override
  Future<String?> read(String key) async {
    final file = await _file();
    if (!await file.exists()) return null;
    final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return map[key] as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    final file = await _file();
    final map = await file.exists()
        ? jsonDecode(await file.readAsString()) as Map<String, dynamic>
        : <String, dynamic>{};
    map[key] = value;
    await file.writeAsString(jsonEncode(map), flush: true);
  }
}

/// Tries [primary] (keychain) and falls back to [fallback] (file) when the
/// keychain throws or has no value. Writes go to the keychain when it works,
/// so devices upgrade to it automatically once the entitlement lands.
class FallbackKeyStore implements KeyStore {
  const FallbackKeyStore({required this.primary, required this.fallback});

  final KeyStore primary;
  final KeyStore fallback;

  @override
  Future<String?> read(String key) async {
    try {
      final value = await primary.read(key);
      if (value != null) return value;
    } catch (_) {
      // Keychain unavailable (e.g. errSecMissingEntitlement on ad-hoc
      // macOS builds) — the file store is the source of truth then.
    }
    return fallback.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await primary.write(key, value);
      return;
    } catch (_) {
      await fallback.write(key, value);
    }
  }
}

class InMemoryKeyStore implements KeyStore {
  final _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

/// This device's long-lived X25519 identity (TASKS.md 3.5): generated on
/// first use, private key persisted only in the key store.
class DeviceIdentity {
  const DeviceIdentity({required this.deviceId, required this.keyPair});

  final String deviceId;
  final SimpleKeyPair keyPair;

  Future<SimplePublicKey> get publicKey => keyPair.extractPublicKey();

  Future<PairingPayload> pairingPayload({
    required String name,
    required String platform,
  }) async => PairingPayload(
    deviceId: deviceId,
    name: name,
    platform: platform,
    publicKeyBase64: base64Encode((await publicKey).bytes),
  );

  static const _privateKeyKey = 'device_identity_private_key';

  /// Loads the stored identity or creates and persists a new one.
  /// [deviceId] is the app-level id (already persisted by main()).
  static Future<DeviceIdentity> loadOrCreate(
    KeyStore store,
    String deviceId,
  ) async {
    final stored = await store.read(_privateKeyKey);
    if (stored != null) {
      final keyPair = SimpleKeyPairData(
        base64Decode(stored),
        publicKey: await X25519()
            .newKeyPairFromSeed(base64Decode(stored))
            .then((k) => k.extractPublicKey()),
        type: KeyPairType.x25519,
      );
      return DeviceIdentity(deviceId: deviceId, keyPair: keyPair);
    }
    final keyPair = await PairingCrypto.generateIdentity();
    final seed = await keyPair.extractPrivateKeyBytes();
    await store.write(_privateKeyKey, base64Encode(seed));
    return DeviceIdentity(deviceId: deviceId, keyPair: keyPair);
  }
}
