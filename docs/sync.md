# Sync design

No central server. Sync = exchanging encrypted **changesets** between paired
devices over pluggable transports, merged with CRDT semantics.

## Change tracking & merge

- Every field mutation is stamped with a **hybrid logical clock** (HLC:
  wall-clock + logical counter + deviceId) — totally ordered, resilient to
  clock skew.
- Merge rule: **last-writer-wins per field** by HLC. Deletes are tombstones and
  win over concurrent edits only if their HLC is later (delete-vs-edit races
  resolve deterministically; a later edit resurrects the todo).
- Changesets are idempotent and commutative — any delivery order, any
  duplication, same converged state. This is the property-based test gate.
- Implementation: **hand-rolled** (`LwwApplier` + per-field `field_clocks`);
  cr-sqlite was evaluated and rejected in the Phase 0 spike —
  [ADR 0001](decisions/0001-crdt-choice.md).

## Device identity & pairing

- Each install generates an X25519 keypair; private key lives in the platform
  keychain/keystore.
- Pairing: device A shows a QR code (public key + transport hints); device B
  scans, both derive a shared secret (ECDH), user confirms matching emoji/word
  fingerprint on both screens. Desktop↔desktop fallback: 6-digit short code.
- Revoking a device removes its key and triggers rotation of mailbox encryption
  keys.

## Encryption

- Payloads sealed with XChaCha20-Poly1305 using keys derived from the pairing
  secret (HKDF). The mailbox transport stores ciphertext only — the cloud
  provider learns file sizes and timing, nothing else.

## Transports

### Delta protocol (implemented, `sync_engine.dart`)
- **Version vectors, not scalar cursors** (changed 2026-07-05): each device
  derives "max HLC per origin device" from its own `field_clocks`; a peer
  answers with exactly the writes newer than that vector. Scalar cursors were
  rejected — they lose writes that arrive via an intermediary with stamps
  older than the cursor high-water mark.
- Rows use LWW-map semantics: a row (and any row it references) springs into
  existence when its first field write arrives, so foreign keys hold under
  arbitrary delivery order.

### 1. LAN peer-to-peer
- mDNS/Bonjour advertise + browse (service type `_todosync._tcp`).
- Direct TCP session: hello (device ids, protocol version) → exchange version
  vectors → stream missing changesets both ways.
- Used when devices are on the same network with the app running/foregrounded.

### 2. Cloud-drive mailbox
- User picks a folder on a drive they already sync (iCloud Drive, Google Drive,
  Dropbox, Syncthing — anything that replicates files).
- Layout: `mailbox/{deviceId}/{hlc}.bin` — each device appends encrypted
  changesets to its own outbox and reads every other device's outbox, applying
  anything past its cursor.
- Compaction: periodically each device replaces its old changesets with a
  snapshot once all peers' cursors have passed them.
- Folder access: iCloud container via native channel (iOS/macOS), Storage
  Access Framework (Android), plain directory picker (Windows/Linux).
- **Provider-API backends (ADR 0003):** the same protocol also runs over a
  storage provider's REST API behind the `MailboxStore` seam — Dropbox app
  folder, Google Drive `appDataFolder`, OneDrive Graph approot — signed in
  from Settings → Cloud storage with OAuth/PKCE (docs/cloud-providers.md).
  This is the iPhone path, where those providers expose no filesystem
  folder. Same layout, same ciphertext, narrowest per-provider scopes.
- **Solo-device mode:** a configured mailbox no longer requires pairing —
  the first device creates the group key itself and publishes from day one;
  pairing later hands that key to new devices, which then join the same
  mailbox with full history.
- Third-party tolerance (TASKS.md 6.45): the folder is shared with whatever
  tool the user syncs it with, and those tools litter it with their own files —
  Syncthing `*.sync-conflict-*` copies and `.stversions`/`.stfolder` dirs,
  Dropbox "(conflicted copy)" files, iCloud `.icloud` placeholders, and `~`/
  `.tmp` temp files. Consumption and compaction accept **only** files whose
  name matches our exact `<hlc>.bin` shape and treat only non-dot subdirectories
  as peer outboxes, so foreign artifacts are ignored rather than decrypted,
  re-applied, or (in the case of a conflict copy sorting past a real file)
  allowed to advance a cursor and strand later changesets.

### Sharing groups (ADR 0004, design accepted — implementation Phase 8)

Lists are **local by default**. A *sync group* binds a set of lists to a
mailbox backend (iCloud folder, provider account, plain folder), a
per-group encryption key, and a member set — so "Family on iCloud" and
"Friends on Dropbox" run side by side, each with scoped changesets and
its own cursors. Joining a group (QR invite carrying the group key +
backend hint) makes a device a peer of someone else's storage; every
member signs into their *own* provider account. The provider's folder ACL
is coarse plumbing — the group key is the security boundary, rotated on
member removal. Full design in
[ADR 0004](decisions/0004-sharing-groups.md).

### The mailbox is a transport, not a backup

The cloud-drive mailbox looks like a folder full of files in your Drive, so it
is tempting to treat it as a backup. It is not, and must not be relied on as
one:

- It holds **deltas plus periodic snapshots**, not a full, self-contained
  export. Once every peer's cursor has passed a changeset, compaction deletes
  it — old history is intentionally discarded.
- It converges devices to the **current** state. A delete or a bad bulk edit
  replicates to every device; the mailbox faithfully propagates the loss rather
  than preserving what was there before.
- Its contents are keyed to the paired devices' session keys. It is not a
  portable artifact a user can hand to a new, unpaired device to recover data.

For an actual backup, use the **encrypted backup file** (TASKS.md 6.41,
`lib/data/backup_service.dart`): a passphrase-derived key (PBKDF2-HMAC-SHA256)
sealing a full JSON export with XChaCha20-Poly1305. It is a point-in-time
snapshot, independent of any pairing, that a user restores by hand — the
counterpart to the mailbox's live replication.

### Orchestration
- Triggers: app foreground, debounced local mutation, periodic timer.
- Prefer LAN when a peer is visible; mailbox otherwise. Both can run — merge
  idempotency makes duplicate delivery harmless.

### Unattended viewer and restart behavior (TASKS.md 6.10)

`SyncBootstrap` starts `SyncService` automatically during app startup. Once a
mailbox folder, provider account, or paired group is already configured, a
relaunch needs no extra tap: startup restores persisted mailbox settings,
starts LAN discovery/server where pairing exists, runs an immediate sync pass,
then continues with mutation, resume, and five-minute periodic triggers.

This is enough for an unattended wallboard/kiosk viewer that is relaunched by
the OS or by a desktop login item: open the app and it resumes sync on its own.
It is not a promise that sync runs while the app process is stopped. Current v1
limits are:

- Android Doze, app standby, and OEM battery savers can delay or stop background
  network work when the app is not foregrounded.
- iOS background fetch is opportunistic and cannot be used as a reliable
  always-on sync daemon.
- Desktop builds do not yet install a background tray/login helper; that remains
  tracked by the desktop background tasks.

Verification checklist: configure a mailbox/provider, quit the app, relaunch
it, and confirm Sync settings shows a new last-sync time without pressing
"Sync now". A full device reboot check belongs in the manual release matrix,
because mobile background behavior depends on real OS power policy.

### Latency targets (TASKS.md 6.3)

What "synced" should feel like per transport, and why:

| Path | Target | Dominated by |
|---|---|---|
| LAN, both apps foreground | **< 6 s** | 5 s mutation debounce + transfer |
| App brought to foreground | seconds | immediate pass on resume |
| Mailbox, apps open | **≤ ~5 min + cloud lag** | our 5-min poll ∨ the drive client's own upload/download cadence (outside our control) |
| Either app closed | until next launch/resume | no background daemon in v1 (see 5.1/5.2) |

The receiving side applies deltas in one transaction, so "arrived" ≈
"visible". LAN transfer itself is millisecond-scale (loopback protocol
tests); the debounce *is* the LAN latency budget, chosen to batch bursts of
edits into one changeset. Real-network measurements (Wi-Fi, congested
mDNS) fold into the manual device matrix (2.11/4.21). Sync settings shows
the live "last sync" time + trigger cadence (6.3's status line).

## Failure modes considered

- Clock skew between devices → HLC handles ordering.
- Same todo edited offline on two devices → per-field LWW; no user-facing
  conflict dialogs by design.
- Partial mailbox file (cloud drive mid-upload) → changesets are length-prefixed
  and checksummed; incomplete files skipped until complete.
- Device lost/stolen → revoke from any paired device; key rotation locks it out
  of future changesets.
