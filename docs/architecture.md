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
- **Riverpod** — state management
- **CRDT layer** — hand-rolled LWW-per-field with HLC stamps; decided by the
  Phase 0 spike ([ADR 0001](decisions/0001-crdt-choice.md))

## Data model

- `Todo` — uuid, title, notes, dueAt, alarm fields (offset minutes,
  lastDismissedMs, snoozeUntilMs — plain LWW fields since schema v3),
  recurrenceRule, completedAt, listId, tags[], priority, per-field HLC
  timestamps, deleted (tombstone)
- `TodoList` — uuid, name, color, sortOrder
- `Device` — deviceId, publicKey, name, platform, lastSeenAt
- `SyncLog` — per-peer last-exchange info (status UI); sync cursors are
  version vectors derived from the `field_clocks` table

Alarm dismissal/snooze state lives on the todo itself (design change
2026-07-06), so dismissals replicate through the ordinary merge engine — the
schema-v1 `todo_alarms` / `alarm_dismissals` tables are unused.

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
