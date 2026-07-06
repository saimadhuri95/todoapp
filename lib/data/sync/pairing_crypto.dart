import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Crypto for device pairing and changeset sealing (TASKS.md 3.5/3.7).
///
/// Each device holds an X25519 identity keypair. A pairing derives a
/// per-pair session key via ECDH + HKDF; changesets are sealed with
/// XChaCha20-Poly1305. Everything that leaves a device goes through
/// [seal] — the cloud mailbox only ever stores its output.
class PairingCrypto {
  static final _x25519 = X25519();
  static final _aead = Xchacha20.poly1305Aead();
  static const _nonceLength = 24;
  static const _macLength = 16;

  static Future<SimpleKeyPair> generateIdentity() => _x25519.newKeyPair();

  /// Both sides derive the identical key: ECDH is symmetric and the HKDF
  /// salt uses the sorted device-id pair.
  static Future<SecretKey> deriveSessionKey({
    required SimpleKeyPair mine,
    required SimplePublicKey theirs,
    required String myDeviceId,
    required String theirDeviceId,
  }) async {
    final shared = await _x25519.sharedSecretKey(
      keyPair: mine,
      remotePublicKey: theirs,
    );
    final ids = [myDeviceId, theirDeviceId]..sort();
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: shared,
      nonce: utf8.encode(ids.join(':')),
      info: utf8.encode('todoapp-sync-v1'),
    );
  }

  /// Random-nonce AEAD; output is nonce ‖ ciphertext ‖ MAC.
  static Future<Uint8List> seal(List<int> plaintext, SecretKey key) async {
    final box = await _aead.encrypt(plaintext, secretKey: key);
    return box.concatenation();
  }

  /// Throws [SecretBoxAuthenticationError] on tampering or a wrong key.
  static Future<List<int>> open(List<int> sealed, SecretKey key) {
    final box = SecretBox.fromConcatenation(
      sealed,
      nonceLength: _nonceLength,
      macLength: _macLength,
    );
    return _aead.decrypt(box, secretKey: key);
  }

  /// Short human-checkable fingerprint of a pairing, shown on both screens
  /// for confirmation (3.6). Symmetric: same value on both devices.
  static Future<String> fingerprint(
    SimplePublicKey a,
    SimplePublicKey b,
  ) async {
    final keys = [base64Encode(a.bytes), base64Encode(b.bytes)]..sort();
    final digest = await Sha256().hash(utf8.encode(keys.join('|')));
    final hex = digest.bytes
        .take(6)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return '${hex.substring(0, 4)}-${hex.substring(4, 8)}-${hex.substring(8)}';
  }
}

/// What a QR code (or short-code exchange) carries during pairing.
class PairingPayload {
  const PairingPayload({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.publicKeyBase64,
  });

  final String deviceId;
  final String name;
  final String platform;
  final String publicKeyBase64;

  SimplePublicKey get publicKey =>
      SimplePublicKey(base64Decode(publicKeyBase64), type: KeyPairType.x25519);

  String encode() => jsonEncode({
    'v': 1,
    'id': deviceId,
    'name': name,
    'platform': platform,
    'pk': publicKeyBase64,
  });

  factory PairingPayload.decode(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    if (map['v'] != 1) {
      throw FormatException('Unsupported pairing payload version: ${map['v']}');
    }
    return PairingPayload(
      deviceId: map['id'] as String,
      name: map['name'] as String,
      platform: map['platform'] as String,
      publicKeyBase64: map['pk'] as String,
    );
  }
}
