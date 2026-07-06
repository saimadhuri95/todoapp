# Architecture

## Overview

A **local-first** todo app: every device holds the complete dataset in a local
SQLite database and is fully functional offline. There is no central server —
devices sync directly with each other (LAN) or through the user's own cloud-drive
folder acting as an encrypted mailbox.

```
┌────────────────────────────── Flutter app ──────────────────────────────┐
│  UI (feature-first screens)                                             │
│  ────────────────────────────────────────────                           │
│  Domain: repositories, recurrence engine, alarm scheduler (abstraction)  │
│  ────────────────────────────────────────────                           │
│  Data: SQLite (drift) · HLC-stamped mutations · changeset log           │
│  ────────────────────────────────────────────                           │
│  Sync engine: merge (LWW/CRDT) · crypto · transports (LAN, mailbox)     │
└──────────────────────────────────────────────────────────────────────────┘
        │                          │                        │
   OS notifications        mDNS + TCP (LAN)       cloud-drive folder
   (per-platform)          peer devices           (iCloud/GDrive/any)
```

## Stack

- **Flutter/Dart** — single codebase for Windows, macOS, Linux, iOS, Android
- **SQLite via drift** — local store, typed queries, migrations
- **Riverpod** — state management (pending confirmation in Phase 0)
- **CRDT layer** — cr-sqlite or hand-rolled LWW-per-field; decided by Phase 0 spike
  (see docs/decisions/ once written)

## Data model

- `Todo` — uuid, title, notes, dueAt, alarms[], recurrenceRule, completedAt,
  listId, tags[], priority, per-field HLC timestamps, deleted (tombstone)
- `TodoList` — uuid, name, color, sortOrder
- `Device` — deviceId, publicKey, name, platform, lastSeenAt
- `SyncLog` — per-peer cursor / vector clock
- `AlarmDismissal` — todoId, alarmAt, dismissedBy, hlc (syncs so other devices
  cancel the same alarm)

All ids are UUIDv7. Deletes are tombstones (never hard-delete synced rows);
tombstones are pruned only after all paired devices have acknowledged them.

## Key invariants

1. The app must be 100% functional with sync never configured.
2. Merge is idempotent and commutative — applying the same changeset twice, or
   changesets in any order, yields the same state.
3. Nothing leaves the device unencrypted. The cloud-drive mailbox only ever
   contains ciphertext.
4. Alarms fire only on devices where the user enabled them (mobile default-on,
   desktop opt-in).

## Related docs

- [sync.md](sync.md) — sync engine, pairing, crypto, transports
- [alarms.md](alarms.md) — per-platform alarm behavior
- [testing.md](testing.md) — testing strategy
