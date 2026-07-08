# 0002 — Attachments: content-addressed blobs with lazy, encrypted sync

Date: 2026-07-07
Status: accepted

## Context

TASKS.md 6.47 (R something) asks for file attachments on todos. Attachments are
different in kind from every field we sync today: those are small, text-ish,
per-field LWW values that fit comfortably in one changeset. A photo or PDF is
large, opaque, and immutable once created. Bolting bytes onto the existing
change-tracking path would defeat the sync design — a single 10 MB image would
dwarf every real edit in a changeset, blow past cloud-drive quotas, and force
every device to download it on the next sync whether the user opens it or not.

This ADR fixes the design so the implementation tasks that follow (schema
migration, capture/pick UI, blob store, transport hooks) have a settled target.
It touches the sync design in PLAN.md, hence an ADR.

Constraints inherited from CLAUDE.md's non-negotiable invariants:

1. Fully functional with sync never configured (attachments must work purely
   locally).
2. Merge stays idempotent + commutative.
3. Nothing leaves a device unencrypted — the mailbox holds ciphertext only.
5. Deletes are tombstones; never hard-delete synced rows.

## Decision

### 1. Split metadata (synced eagerly) from bytes (synced lazily)

Add an `attachments` table synced exactly like every other row — per-field LWW
with HLC stamps and a `deleted` tombstone:

| column        | notes                                                            |
|---------------|------------------------------------------------------------------|
| `id`          | uuid v7                                                           |
| `todoId`      | FK → `todos.id`                                                   |
| `contentHash` | SHA-256 of the **plaintext** bytes; the blob's stable identity   |
| `fileName`    | original display name                                            |
| `mimeType`    | sniffed/declared type                                            |
| `sizeBytes`   | plaintext length (for the UI and cap checks)                     |
| `createdAtMs` | injected-clock timestamp                                        |
| `deleted`     | tombstone                                                        |

The metadata row is tiny, so it rides the normal changeset path and converges
like any edit. The **bytes never enter the changeset.** A device that receives
an attachment row it has no blob for shows a placeholder ("tap to download")
and fetches the blob on demand.

### 2. Content-addressed local blob store

Bytes live outside the database in an app-managed directory
(`<appSupport>/attachments/`, via `path_provider` per platform), one file per
blob named by its plaintext `contentHash`. Content addressing means:

- **Dedup for free** — the same image attached to two todos, or arriving from
  two devices, is stored once.
- **Integrity for free** — a fetched blob is trusted only if its hash matches
  the `contentHash` in the metadata row.
- **Immutability** — blobs are never edited, only created and (eventually)
  garbage-collected, which is what makes lazy, out-of-band sync safe.

The blob store is behind a `BlobStore` interface (mirrors how alarms, folder
access, and the keychain are abstracted) so the on-disk location and any
platform quirks stay swappable.

### 3. Size caps

- **Per attachment: 25 MB.** Above this the picker refuses with an explanation.
- **Per device total: soft-warn at 500 MB.** The mailbox replicates through the
  user's own cloud drive (iCloud/Drive/Dropbox/Syncthing), whose quota is the
  real limit; we surface usage rather than silently filling their Drive.

Caps are enforced at capture time in the repository layer, not the UI, so every
entry point (share sheet, paste, drag-drop) is covered. The numbers are
recorded here so they're reviewable, not scattered as magic constants.

### 4. Lazy blob transport

Blobs move out of band from changesets, over the same two transports:

- **Cloud-drive mailbox:** each device that holds a blob may publish it to a
  shared `blobs/<contentHash>.bin` file, sealed with the group key
  (XChaCha20-Poly1305), exactly like changesets. A device needing a blob reads
  `blobs/<hash>.bin`, opens it, verifies the hash, and caches it locally. Fetch
  is **on demand** (user opens the attachment) or an optional background
  prefetch on WiFi — never a blocking part of `consume()`.
- **LAN P2P:** a `GET blob <hash>` request/response added to the existing
  session protocol; preferred when a peer is visible because it avoids the
  Drive round-trip and quota entirely.

Because blobs are content-addressed and immutable, delivering one twice or from
two sources is harmless — this preserves invariant 2 (idempotent/commutative)
without any per-blob ordering.

### 5. Encryption

- **In transit / in the mailbox:** ciphertext only. A blob is sealed with the
  group key via the existing `PairingCrypto.seal`/`open`, satisfying invariant
  3. XChaCha20-Poly1305 uses a random nonce, so ciphertext is non-deterministic
  — hence the mailbox file is keyed by the **plaintext** `contentHash` (stable
  and dedupable) while each device seals its own copy; the plaintext hash is
  never exposed outside the already-encrypted metadata row.
- **At rest:** local blobs are stored plaintext, matching the current local
  SQLite database (also plaintext at rest). At-rest encryption of the whole
  local store is a separate, app-wide decision (see the encrypted-backup work,
  ADR-worthy if pursued) and is explicitly out of scope here.

### 6. Garbage collection

- Deleting an attachment tombstones the metadata row (invariant 5). The blob is
  **not** deleted immediately: another todo (or device) may reference the same
  hash.
- A local GC pass deletes a blob only when no live (non-tombstoned) attachment
  row on that device references its hash, after a grace period.
- Mailbox `blobs/` entries are cleaned during the existing compaction pass once
  every peer's cursor shows they have the referencing metadata (or the row is
  tombstoned everywhere).

## Consequences

- **New schema version** adds the `attachments` table plus the sync-field
  bookkeeping for it; the migration is additive and the app remains fully
  local-first with sync unconfigured.
- **Sync stays fast and quota-friendly:** changesets never carry bytes; a device
  syncs metadata instantly and pulls only the blobs the user actually opens.
- **`sync_engine`/transport work is bounded:** metadata needs no engine change
  (it's just another synced table); the new surface is the blob publish/fetch
  hooks on the mailbox and LAN transports and the `BlobStore` abstraction.
- **Follow-up tasks unblocked by this ADR:** (a) schema + `attachments`
  repository with cap enforcement and tombstones; (b) `BlobStore` per-platform;
  (c) mailbox `blobs/` publish + lazy fetch, reusing the 6.45 filename
  allowlist for the new `blobs/` names; (d) LAN `GET blob`; (e) capture/pick UI
  and the attachment tile with on-demand download. Each is its own PR.
- **Deliberately deferred:** at-rest encryption of local blobs, inline
  previews/thumbnails beyond a basic icon, and non-image types in the first
  cut — the first implementation slice is capped images only.
