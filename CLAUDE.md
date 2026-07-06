# CLAUDE.md

## What this project is

Local-first, **serverless** todo app targeting Windows, macOS, Linux, iOS, and
Android from a single Flutter codebase, with CRDT-based cross-device sync and
per-item alarms. There is deliberately **no central server** — do not introduce
one, not even "just for sync" or push notifications.

## Current status

**Planning stage — no code yet.** The Flutter project has not been scaffolded
(Phase 0). Start there before any feature work.

## Where things live

- [PLAN.md](PLAN.md) — architecture decisions, phases, open questions
- [TASKS.md](TASKS.md) — the detailed task checklist; **check items off as you
  complete them** and add newly discovered tasks under the right phase
- [docs/architecture.md](docs/architecture.md) — stack, data model, invariants
- [docs/sync.md](docs/sync.md) — merge semantics, pairing, crypto, transports
- [docs/alarms.md](docs/alarms.md) — per-platform alarm design
- [docs/testing.md](docs/testing.md) — testing strategy and CI gates
- docs/decisions/ — ADRs; write one for any decision that changes PLAN.md

## Token efficiency (Claude Pro plan — hard session + weekly limits)

The user is on a $20/mo Pro subscription. Treat tokens as a scarce resource:

- **Session start:** read this file + the `RESUME` section and current phase in
  TASKS.md. Nothing else unless the task requires it.
- **Session end / limit warning:** check off completed tasks in TASKS.md and
  update its `RESUME` section (current task, exact state, next action) so an
  interrupted task restarts without re-exploration.
- **Subagents:** avoid by default — they re-derive context and count against
  the same limits. When a broad search genuinely needs one, use **Haiku or
  Sonnet** (note: Opus is the *large* model, not a small one).
- Read files with targeted offsets/limits; never re-read a file just edited.
- Tail long build/test output instead of dumping it.
- Batch independent tool calls; batch related edits into one pass.
- Follow the session schedule in TASKS.md — one task group per session; don't
  start a large task near the end of a usage window.

## Non-negotiable invariants

1. App is fully functional with sync never configured (local-first).
2. Merge is idempotent + commutative; the property-based convergence suite must
   pass before any release.
3. Nothing leaves a device unencrypted; the cloud-mailbox folder holds
   ciphertext only.
4. Alarms fire only where enabled: mobile default-on, Windows/macOS opt-in
   toggle (default off), Linux deferred to Phase 5.
5. Deletes are tombstones; never hard-delete synced rows.

## Conventions (once code exists)

- Flutter/Dart, feature-first folder structure, Riverpod (pending Phase 0
  confirmation), drift for SQLite.
- No `DateTime.now()` outside the injected clock provider — everything
  time-related must be testable with a fake clock.
- Per-field HLC stamping happens in the repository layer on every mutation;
  UI never writes to the database directly.
- Platform-specific code (alarms, folder access, keychain) goes behind a Dart
  abstract interface with per-platform implementations.
- Tests land in the same PR as the feature; data/sync layers hold an 80%
  coverage floor.

## Things already decided (don't re-litigate without an ADR)

- Flutter over React Native/KMP/Tauri (only option covering all 5 targets well)
- LWW-per-field CRDT with HLC timestamps (cr-sqlite vs hand-rolled: Phase 0
  spike decides the implementation, not the semantics)
- Two transports: LAN P2P (mDNS+TCP) and encrypted cloud-drive mailbox
- QR-code device pairing, X25519 + XChaCha20-Poly1305
- Desktop alarms opt-in; cron rejected for Linux (see docs/alarms.md)
