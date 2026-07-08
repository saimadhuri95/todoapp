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
    this.groupId,
  }) : store = FolderMailboxStore(root);

  /// Mailbox over any [MailboxStore] (cloud provider APIs on iPhone).
  MailboxTransport.withStore({
    required this.store,
    required this.engine,
    required this.db,
    required this.deviceId,
    required this.groupKey,
    this.groupId,
  });

  final MailboxStore store;
  final SyncEngine engine;
  final AppDatabase db;
  final String deviceId;
  final SecretKey groupKey;

  /// Sharing group this mailbox serves (ADR 0004, TASKS 8.2). Namespaces
  /// the consumption cursors so one device can hold many groups — each
  /// with its own mailbox and independent progress. Null = the personal
  /// (pre-groups) mailbox, whose cursor keys stay unchanged.
  final String? groupId;

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
    // Only real device outboxes are peers. Skip our own, and skip the
    // dot-prefixed metadata folders third-party sync tools leave behind
    // (Syncthing .stfolder/.stversions, .Trash-*, cloud caches) — 6.45.
    final dirs = (await store.listDeviceDirs()).where(
      (d) => d != deviceId && !d.startsWith('.'),
    );
    for (final dir in dirs) {
      final cursor = await _cursorFor(dir);
      final files =
          (await store.listFiles(dir))
              .where(_isChangesetName)
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
    final deltas = (await store.listFiles(
      deviceId,
    )).where(_isChangesetName).toList();
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

  /// Our own changeset shape only (see [_fileNameFor]): HLC millis, counter,
  /// and a nodeId joined by `_`, with a `.bin` suffix. Third-party sync
  /// tools drop artifacts alongside them — Syncthing `*.sync-conflict-*`
  /// copies, Dropbox "(conflicted copy)" files, iCloud `.icloud`
  /// placeholders, `~`/`.tmp` temp files. Each introduces a `.`, space,
  /// `(`, `)`, or `~` this pattern rejects, so consumption and compaction
  /// ignore them (TASKS.md 6.45). `vector.bin` is excluded too — it carries
  /// no HLC prefix.
  static final _changesetName = RegExp(
    r'^\d{15}_[0-9a-f]{4,}_[^.\s()~]+\.bin$',
  );

  static bool _isChangesetName(String name) => _changesetName.hasMatch(name);

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
  /// Keys are per group (8.2): `mailbox:<peer>` for the personal mailbox,
  /// `group:<gid>:mailbox:<peer>` inside a sharing group.
  String _cursorKey(String peerDir) =>
      groupId == null ? 'mailbox:$peerDir' : 'group:$groupId:mailbox:$peerDir';

  Future<String?> _cursorFor(String peerDir) async {
    final row =
        await (db.syncLog.select()
              ..where((s) => s.peerId.equals(_cursorKey(peerDir))))
            .getSingleOrNull();
    return row?.lastAppliedHlc.isEmpty ?? true ? null : row!.lastAppliedHlc;
  }

  Future<void> _saveCursor(String peerDir, String fileName) =>
      db.syncLog.insertOne(
        SyncLogCompanion.insert(
          peerId: _cursorKey(peerDir),
          lastAppliedHlc: Value(fileName),
        ),
        mode: InsertMode.insertOrReplace,
      );
}
