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
- Alternative under evaluation (Phase 0 spike): **cr-sqlite**, which provides
  this machinery at the SQLite layer. Decision recorded in docs/decisions/.

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

### Orchestration
- Triggers: app foreground, debounced local mutation, periodic timer.
- Prefer LAN when a peer is visible; mailbox otherwise. Both can run — merge
  idempotency makes duplicate delivery harmless.

## Failure modes considered

- Clock skew between devices → HLC handles ordering.
- Same todo edited offline on two devices → per-field LWW; no user-facing
  conflict dialogs by design.
- Partial mailbox file (cloud drive mid-upload) → changesets are length-prefixed
  and checksummed; incomplete files skipped until complete.
- Device lost/stolen → revoke from any paired device; key rotation locks it out
  of future changesets.
