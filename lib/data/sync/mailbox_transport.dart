import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'changeset.dart';
import 'mailbox_store.dart';
import 'pairing_crypto.dart';
import 'sync_engine.dart';

/// Cloud-drive mailbox transport (TASKS.md 3.10): the user points every
/// device at one shared mailbox — a folder replicated by their own cloud
/// drive (iCloud Drive, Syncthing, any file-syncing folder) or a storage
/// provider account spoken to over its API ([MailboxStore] implementations
/// in lib/data/cloud/).
///
/// Layout: `<root>/<deviceId>/<sortable-name>.bin` — each device appends
/// sealed changesets to its own outbox and reads every other outbox past a
/// locally-stored cursor. `vector.bin` in each outbox records the version
/// vector that outbox covers, so publishing writes deltas, not snapshots.
///
/// Everything stored is XChaCha20-Poly1305 ciphertext under [groupKey]
/// (distributed at pairing, 3.6); a torn/partial upload simply fails
/// authentication and is retried next round.
class MailboxTransport {
  /// Folder-backed mailbox (the common desktop/iCloud-Drive case).
  MailboxTransport({
    required Directory root,
    required this.engine,
    required this.db,
    required this.deviceId,
    required this.groupKey,
  }) : store = FolderMailboxStore(root);

  /// Mailbox over any [MailboxStore] (cloud provider APIs on iPhone).
  MailboxTransport.withStore({
    required this.store,
    required this.engine,
    required this.db,
    required this.deviceId,
    required this.groupKey,
  });

  final MailboxStore store;
  final SyncEngine engine;
  final AppDatabase db;
  final String deviceId;
  final SecretKey groupKey;

  static const _vectorFile = 'vector.bin';

  /// User-facing sync health (TASKS.md 6.27): how many distinct records
  /// still have local mailbox writes waiting to be published.
  Future<int> pendingOutboundCount() async {
    final published = await _readVector();
    final changeset = await engine.changesFor(published);
    return {
      for (final write in changeset.writes) '${write.entity}:${write.rowId}',
    }.length;
  }

  /// Writes everything not yet covered by our outbox. Returns the number
  /// of field writes published.
  Future<int> publish() async {
    final published = await _readVector();
    final changeset = await engine.changesFor(published);
    if (changeset.writes.isEmpty) return 0;

    final sealed = await PairingCrypto.seal(
      utf8.encode(changeset.encode()),
      groupKey,
    );
    await store.write(deviceId, _fileNameFor(changeset), sealed);

    final vector = await engine.versionVector();
    final sealedVector = await PairingCrypto.seal(
      utf8.encode(jsonEncode(vector)),
      groupKey,
    );
    await store.write(deviceId, _vectorFile, sealedVector);
    return changeset.writes.length;
  }

  /// Applies unseen changeset files from every other device's outbox.
  /// Returns the number of field writes that won LWW.
  Future<int> consume() async {
    var applied = 0;
    final dirs = (await store.listDeviceDirs()).where((d) => d != deviceId);
    for (final dir in dirs) {
      final cursor = await _cursorFor(dir);
      final files =
          (await store.listFiles(dir))
              .where((name) => name.endsWith('.bin'))
              .where((name) => name != _vectorFile)
              .where((name) => cursor == null || name.compareTo(cursor) > 0)
              .toList()
            ..sort();
      for (final name in files) {
        final bytes = await store.read(dir, name);
        if (bytes == null) continue; // Deleted between list and read.
        try {
          final clear = await PairingCrypto.open(bytes, groupKey);
          applied += await engine.apply(Changeset.decode(utf8.decode(clear)));
        } on SecretBoxAuthenticationError {
          // Torn upload or foreign data: stop here, keep the cursor before
          // this file so it's retried once the cloud drive finishes.
          break;
        } on FormatException {
          break;
        }
        await _saveCursor(dir, name);
      }
    }
    return applied;
  }

  /// Compaction (TASKS.md 3.11): once the outbox accumulates [threshold]
  /// delta files, replace them with one full-state snapshot. Peers behind
  /// re-apply the snapshot idempotently; peers fully caught up skip it
  /// (its name sorts ≤ their cursor).
  Future<bool> compactIfNeeded({int threshold = 20}) async {
    final deltas = (await store.listFiles(deviceId))
        .where((name) => name.endsWith('.bin'))
        .where((name) => name != _vectorFile)
        .toList();
    if (deltas.length < threshold) return false;

    final snapshot = await engine.changesFor(const {});
    if (snapshot.writes.isEmpty) return false;
    final sealed = await PairingCrypto.seal(
      utf8.encode(snapshot.encode()),
      groupKey,
    );
    final name = _fileNameFor(snapshot);
    await store.write(deviceId, name, sealed);
    for (final delta in deltas) {
      if (delta != name) await store.delete(deviceId, delta);
    }
    return true;
  }

  /// Deletes the whole shared mailbox. Used on device revocation: the
  /// group key was rotated, so every file in here is sealed with a burned
  /// key; devices republish after re-pairing.
  Future<void> wipeAll() => store.wipeAll();

  /// Filenames sort in HLC order; ':' is not filename-safe on Windows.
  static String _fileNameFor(Changeset changeset) {
    final max = changeset.writes.last.hlc.encode().replaceAll(':', '_');
    return '$max.bin';
  }

  Future<Map<String, String>> _readVector() async {
    final bytes = await store.read(deviceId, _vectorFile);
    if (bytes == null) return {};
    try {
      final clear = await PairingCrypto.open(bytes, groupKey);
      return (jsonDecode(utf8.decode(clear)) as Map<String, dynamic>)
          .cast<String, String>();
    } on SecretBoxAuthenticationError {
      return {}; // Unreadable marker: republish everything (idempotent).
    } on FormatException {
      return {};
    }
  }

  /// Consumption cursors live in the local sync_log (never in the shared
  /// mailbox — they're per-device state).
  Future<String?> _cursorFor(String peerDir) async {
    final row =
        await (db.syncLog.select()
              ..where((s) => s.peerId.equals('mailbox:$peerDir')))
            .getSingleOrNull();
    return row?.lastAppliedHlc.isEmpty ?? true ? null : row!.lastAppliedHlc;
  }

  Future<void> _saveCursor(String peerDir, String fileName) =>
      db.syncLog.insertOne(
        SyncLogCompanion.insert(
          peerId: 'mailbox:$peerDir',
          lastAppliedHlc: Value(fileName),
        ),
        mode: InsertMode.insertOrReplace,
      );
}
