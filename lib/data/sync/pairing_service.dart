import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import '../../core/hlc.dart';
import '../db/database.dart';
import 'device_identity.dart';
import 'pairing_crypto.dart';
import 'sync_fields.dart';

class PairingResult {
  const PairingResult({required this.peer, required this.fingerprint});

  final PairingPayload peer;

  /// Shown to the user for out-of-band confirmation; the inviter can
  /// verify it from its device list once the acceptor's row syncs over.
  final String fingerprint;
}

/// Pairing flow logic (TASKS.md 3.6).
///
/// An **invitation** is a QR/pasteable JSON blob holding the inviter's
/// identity payload *and the group key*. The invitation itself is the
/// secret: it travels over the local visual/clipboard channel, never the
/// network (same trust model as Syncthing device sharing / WireGuard
/// config QR codes). Group-key *rotation* on device revocation is 3.8.
class PairingService {
  PairingService({required this.db, required this.hlc, required this.keyStore});

  final AppDatabase db;
  final HlcClock hlc;
  final KeyStore keyStore;

  static const _groupKeyKey = 'sync_group_key';

  /// The symmetric key every paired device shares. Created lazily by the
  /// first device that invites; replaced on the acceptor by [accept].
  Future<SecretKey> loadOrCreateGroupKey() async {
    final stored = await keyStore.read(_groupKeyKey);
    if (stored != null) return SecretKey(base64Decode(stored));
    final key = SecretKeyData.random(length: 32);
    await keyStore.write(_groupKeyKey, base64Encode(key.bytes));
    return key;
  }

  Future<bool> hasGroupKey() async => await keyStore.read(_groupKeyKey) != null;

  /// What the inviter displays (QR + copyable text). Also registers this
  /// device's own row so peers list it after their first sync.
  Future<String> createInvitation({
    required DeviceIdentity identity,
    required String name,
    required String platform,
  }) async {
    final key = await loadOrCreateGroupKey();
    await registerSelf(identity: identity, name: name, platform: platform);
    final payload = await identity.pairingPayload(
      name: name,
      platform: platform,
    );
    return jsonEncode({
      'v': 1,
      'payload': payload.encode(),
      'gk': base64Encode(await key.extractBytes()),
    });
  }

  /// Acceptor side: adopts the group key, records the inviter's device row
  /// locally, registers itself (which syncs back to the inviter), and
  /// returns the fingerprint to confirm on both screens.
  Future<PairingResult> accept(
    String invitation, {
    required DeviceIdentity identity,
    required String name,
    required String platform,
  }) async {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(invitation) as Map<String, dynamic>;
    } on FormatException {
      throw const FormatException('Not a valid invitation');
    }
    if (map['v'] != 1 || map['payload'] is! String || map['gk'] is! String) {
      throw const FormatException('Not a valid invitation');
    }
    final peer = PairingPayload.decode(map['payload'] as String);

    await keyStore.write(_groupKeyKey, map['gk'] as String);
    await _upsertDevice(
      id: peer.deviceId,
      name: peer.name,
      platform: peer.platform,
      publicKeyBase64: peer.publicKeyBase64,
    );
    await registerSelf(identity: identity, name: name, platform: platform);

    final fingerprint = await PairingCrypto.fingerprint(
      peer.publicKey,
      await identity.publicKey,
    );
    return PairingResult(peer: peer, fingerprint: fingerprint);
  }

  /// Upserts this device's own row with HLC stamps so it replicates.
  Future<void> registerSelf({
    required DeviceIdentity identity,
    required String name,
    required String platform,
  }) async {
    final publicKey = await identity.publicKey;
    await _upsertDevice(
      id: identity.deviceId,
      name: name,
      platform: platform,
      publicKeyBase64: base64Encode(publicKey.bytes),
    );
  }

  Future<void> _upsertDevice({
    required String id,
    required String name,
    required String platform,
    required String publicKeyBase64,
  }) async {
    final stamp = hlc.send();
    await db.transaction(() async {
      await db.devices.insertOne(
        DevicesCompanion.insert(
          id: id,
          name: name,
          platform: platform,
          publicKey: publicKeyBase64,
        ),
        mode: InsertMode.insertOrReplace,
      );
      await stampFields(
        db: db,
        entity: 'devices',
        rowId: id,
        fields: const ['name', 'platform', 'publicKey'],
        hlc: stamp,
      );
    });
  }
}
