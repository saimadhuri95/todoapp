import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'key_store.dart';
import 'pairing_crypto.dart';

export 'file_key_store.dart';
export 'key_store.dart';

class SecureKeyStore implements KeyStore {
  const SecureKeyStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Used when the platform keychain is unavailable — on macOS, keychain
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
