# Serverless Cross-Platform TODO App — Plan

**Goal:** A TODO app for Windows, macOS, Linux, iOS, and Android with cross-device
sync and per-item alarms, with **no central server operated by us**.

Detailed task checklist: [TASKS.md](TASKS.md). Design details: [docs/](docs/).

## Architecture decisions

| Decision | Choice | Rationale |
|---|---|---|
| Framework | Flutter | Only mainstream option with first-class support for all 5 target platforms from one codebase |
| Local storage | SQLite via drift | Reliable, queryable, works everywhere |
| Sync model | Local-first + CRDTs | Every device holds full data; edits merge without conflicts; no server needed |
| CRDT approach | LWW-per-field with hybrid logical clocks + tombstones; cr-sqlite vs hand-rolled decided by Phase 0 spike | Todo data is simple; semantics fixed, implementation open |
| Sync transports | 1) LAN P2P (mDNS + TCP), 2) user's cloud-drive folder as encrypted mailbox | LAN when devices are together; mailbox for cross-network async; both serverless from our perspective ([docs/sync.md](docs/sync.md)) |
| Security | QR-code device pairing; E2E encryption (X25519 + XChaCha20-Poly1305) | Mailbox never contains plaintext |
| Alarms | OS-scheduled notifications; mobile default-on, Windows/macOS **opt-in**, Linux deferred to Phase 5 | Details in [docs/alarms.md](docs/alarms.md) |

## Data model (first cut)

`Todo`, `TodoList`, `Device`, `SyncLog`, `AlarmDismissal` — full field lists and
invariants in [docs/architecture.md](docs/architecture.md). All ids UUIDv7,
per-field HLC timestamps, deletes are tombstones.

Alarm policy: alarms fire on every device where alarms are **enabled** — on by
default on Android/iOS, opt-in via settings toggle on Windows/macOS, Linux in
Phase 5. Dismissing on one device syncs a dismissal record so others stop
reminding.

## Phases

Task-level detail for every phase lives in [TASKS.md](TASKS.md).

> **Execution order (revised 2026-07-05):** Phase 1 → **Phase 3 (sync)** →
> **Phase 4 (packaging)** → **Phase 2 (alarms, incl. Linux)** → Phase 5
> (polish). Alarms deprioritized to last-but-one; phase numbers kept stable
> because task IDs reference them.

- **Phase 0 — Foundations:** Flutter scaffold for all 5 platforms, CI matrix,
  CRDT spike (cr-sqlite vs hand-rolled → ADR), schema v1, HLC implementation.
- **Phase 1 — Core app (local-only):** todo/list CRUD, tags, recurrence,
  search/filter, responsive phone + desktop UI, settings scaffold.
- **Phase 2 — Alarms (Android, iOS, Windows, macOS):** exact alarms on Android,
  64-cap refill on iOS, opt-in toggle gating Windows (scheduled toasts,
  `scenario="alarm"`) and macOS (UNUserNotificationCenter), snooze/dismiss,
  recurrence rescheduling, DST correctness.
- **Phase 3 — Sync engine:** changesets + merge, property-based convergence
  tests, pairing + crypto, LAN transport, mailbox transport + compaction,
  sync UI, alarm-dismissal sync.
- **Phase 4 — Packaging:** stores (Play, App Store), notarized macOS, MSIX,
  Flatpak, release pipeline, auto-update.
- **Phase 5 — Polish, hardening & Linux alarms:** Linux resident tray process
  for alarms (opt-in), background-at-login option, import/export, accessibility,
  localization, performance/battery, onboarding, beta.

## Testing strategy (summary)

Full strategy in [docs/testing.md](docs/testing.md). Highlights:

- Unit tests from Phase 0 (HLC, repositories, recurrence, merge); 80% coverage
  floor on data/sync layers, CI-enforced.
- **Property-based convergence suite is the release gate for sync**: N simulated
  devices, random ops, partitions, reordering, clock skew → identical state.
- Multi-device integration tests with fake transports in CI.
- Platform smoke tests (`integration_test`) on all 5 platforms in CI.
- Fake-clock-everywhere rule enables the timezone/DST regression suite.
- Manual per-release matrix for what automation can't reach: alarms ringing
  with the app closed, permission flows, QR pairing, real cloud-drive sync.

## Open questions

1. cr-sqlite maturity on Flutter across all 5 platforms — resolved by Phase 0 spike
2. iCloud Drive access from Flutter on iOS/macOS (native channel work likely)
3. LAN sync while mobile app backgrounded — iOS will mostly say no; mailbox is
   the reliable cross-network path there
4. Recurrence scope for v1 — daily/weekly/monthly/yearly subset of RRULE
5. ~~App name~~ → **Knot** (decided 2026-07-06; bundle id `com.sai.knot`, MIT license)
