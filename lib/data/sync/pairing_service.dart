import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import '../../core/hlc.dart';
import '../db/database.dart';
import '../repositories/group_repository.dart';
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

  // --- Per-group keys (TASKS 8.5, ADR 0004) ---
  //
  // Every sharing group has its own XChaCha20 key under
  // `group_key:<groupId>`; the pre-groups key above keeps serving the
  // personal mailbox. The key — not the cloud folder ACL — is the
  // security boundary of a group.

  static String _groupKeyKeyFor(String groupId) => 'group_key:$groupId';

  /// The group's key, created on demand (group-creation flow).
  Future<SecretKey> loadOrCreateGroupKeyFor(String groupId) async {
    final stored = await keyStore.read(_groupKeyKeyFor(groupId));
    if (stored != null && stored.isNotEmpty) {
      return SecretKey(base64Decode(stored));
    }
    final key = SecretKeyData.random(length: 32);
    await keyStore.write(_groupKeyKeyFor(groupId), base64Encode(key.bytes));
    return key;
  }

  /// The group's key if this device holds it (i.e. has joined), else null.
  Future<SecretKey?> groupKeyFor(String groupId) async {
    final stored = await keyStore.read(_groupKeyKeyFor(groupId));
    if (stored == null || stored.isEmpty) return null;
    return SecretKey(base64Decode(stored));
  }

  /// Burns the group's key (member removal, ADR 0004): everything sealed
  /// from now on uses the fresh key. Remaining members must re-join via a
  /// new invitation, and the caller should wipe the group's mailbox.
  /// Other groups — and the personal key — are untouched.
  Future<void> rotateGroupKey(String groupId) async {
    final key = SecretKeyData.random(length: 32);
    await keyStore.write(_groupKeyKeyFor(groupId), base64Encode(key.bytes));
  }

  /// What the group inviter displays (TASKS 8.5): the standard pairing
  /// payload plus the group's id/name/backend and — the secret — its key.
  /// Same trust model as [createInvitation]: the QR itself is the secret
  /// and travels only over the visual/clipboard channel. Also ensures the
  /// inviter's own device row + membership so the joiner sees them after
  /// the first sync.
  Future<String> createGroupInvitation({
    required DeviceIdentity identity,
    required String name,
    required String platform,
    required SyncGroup group,
  }) async {
    final key = await loadOrCreateGroupKeyFor(group.id);
    await registerSelf(identity: identity, name: name, platform: platform);
    await GroupRepository(db, hlc).addMember(group.id, identity.deviceId);
    final payload = await identity.pairingPayload(
      name: name,
      platform: platform,
    );
    return jsonEncode({
      'v': 2,
      'payload': payload.encode(),
      'group': {
        'id': group.id,
        'name': group.name,
        'backendKind': group.backendKind,
      },
      'gk': base64Encode(await key.extractBytes()),
    });
  }

  /// Joiner side (TASKS 8.5): adopts the group key, materializes the
  /// group row locally (unstamped — the inviter's stamped writes arrive
  /// with the first sync and stay authoritative), records the inviter's
  /// device row, and registers this device's own row + membership, which
  /// replicate back through the group's mailbox. The returned fingerprint
  /// is confirmed on both screens, exactly like personal pairing.
  Future<PairingResult> acceptGroupInvitation(
    String invitation, {
    required DeviceIdentity identity,
    required String name,
    required String platform,
  }) async {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(invitation) as Map<String, dynamic>;
    } on FormatException {
      throw const FormatException('Not a valid group invitation');
    }
    final group = map['group'];
    if (map['v'] != 2 ||
        map['payload'] is! String ||
        map['gk'] is! String ||
        group is! Map<String, dynamic> ||
        group['id'] is! String) {
      throw const FormatException('Not a valid group invitation');
    }
    final groupId = group['id'] as String;
    final peer = PairingPayload.decode(map['payload'] as String);

    await keyStore.write(_groupKeyKeyFor(groupId), map['gk'] as String);
    // Materialize the group so the UI can show it before the first sync;
    // no stamps — the inviter's writes are the authoritative history.
    await db.syncGroups.insertOne(
      SyncGroupsCompanion.insert(
        id: groupId,
        name: group['name'] as String? ?? '',
        backendKind: Value(group['backendKind'] as String? ?? ''),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await _upsertDevice(
      id: peer.deviceId,
      name: peer.name,
      platform: peer.platform,
      publicKeyBase64: peer.publicKeyBase64,
    );
    await registerSelf(identity: identity, name: name, platform: platform);
    await GroupRepository(db, hlc).addMember(groupId, identity.deviceId);

    final fingerprint = await PairingCrypto.fingerprint(
      peer.publicKey,
      await identity.publicKey,
    );
    return PairingResult(peer: peer, fingerprint: fingerprint);
  }

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

  /// Renames a device (own or peer); replicates like any field write.
  Future<void> rename(String deviceId, String newName) async {
    final stamp = hlc.send();
    await db.transaction(() async {
      await (db.devices.update()..where((d) => d.id.equals(deviceId))).write(
        DevicesCompanion(name: Value(newName)),
      );
      await stampFields(
        db: db,
        entity: 'devices',
        rowId: deviceId,
        fields: const ['name'],
        hlc: stamp,
      );
    });
  }

  /// Revokes a device (TASKS.md 3.8): tombstones its row (replicates) and
  /// **rotates the group key** so the revoked device cannot read anything
  /// sealed from now on. Remaining devices no longer share our key, so the
  /// user must re-pair them with fresh invitations — and the caller should
  /// wipe the mailbox folder (old files are sealed with the burned key).
  Future<void> revoke(String deviceId) async {
    final stamp = hlc.send();
    await db.transaction(() async {
      // The row may not have synced to us yet; tombstone must still land.
      await db.devices.insertOne(
        DevicesCompanion.insert(
          id: deviceId,
          name: '',
          platform: '',
          publicKey: '',
        ),
        mode: InsertMode.insertOrIgnore,
      );
      await (db.devices.update()..where((d) => d.id.equals(deviceId))).write(
        const DevicesCompanion(deleted: Value(true)),
      );
      await stampFields(
        db: db,
        entity: 'devices',
        rowId: deviceId,
        fields: const ['deleted'],
        hlc: stamp,
      );
    });
    final newKey = SecretKeyData.random(length: 32);
    await keyStore.write(_groupKeyKey, base64Encode(newKey.bytes));
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
