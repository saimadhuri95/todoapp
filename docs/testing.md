# Testing strategy

Test-heavy where bugs are silent and catastrophic (sync, time), lighter where
failures are visible (UI). Everything below is CI-enforced unless marked
manual.

## 1. Unit tests (every phase, from Phase 0)

- HLC: monotonicity, tie-breaking by deviceId, behavior under wall-clock
  regression.
- Repositories: CRUD, tombstone semantics, restore.
- Recurrence: next-occurrence expansion, including monthly-on-the-31st and
  leap-year cases.
- Merge engine: LWW per field, delete-vs-edit, duplicate application.
- CI wires the Phase 0 suites explicitly:
  `test/core/hlc_test.dart`, `test/data/repositories_test.dart`,
  `test/core/recurrence_test.dart`, `test/data/lww_applier_test.dart`, and
  `test/data/sync_engine_test.dart`.
- Coverage floor: 80% on `lib/data/**`, excluding generated `*.g.dart`,
  enforced by `tool/check_coverage.dart`.

## 2. Property-based convergence tests (Phase 3 gate)

The single most important suite in the project.

- The harness lives in `test/data/convergence_test.dart`, backed by the shared
  simulated-device helpers under `test/support/`.
- N in-memory simulated devices, random op sequences, partial connectivity,
  shuffled delivery, and clock skew must still converge.
- Property 1: after full exchange, all devices hold byte-identical state.
- Property 2: re-applying any published prefix is idempotent.
- No release while the convergence gate fails. The release workflow reruns it
  before artifact builds start.

## 3. Multi-device integration tests (CI)

The fake transport simulator lives in `test/support/sync_simulator.dart`, with
its CI suite in `test/data/sync_simulator_test.dart`.

- Fake LAN and fake mailbox transports exercise relay behavior without TCP or
  filesystem dependence.
- 3-device chains: A edits offline -> syncs to B via LAN -> B to C via mailbox.
- Partial/corrupt mailbox entries are left unread and retried on the next
  pass, rather than crashing the consumer.
- Alarm dismissal propagation suppresses the matching scheduled occurrence.
- Pairing, revocation, and key rotation remain covered by the dedicated
  pairing/mailbox suites.

## 4. Widget tests

Per screen as built, with the current coverage split across:

- `test/widget_test.dart`
- `test/features/sync_settings_test.dart`
- `test/features/settings_screen_test.dart`
- `test/features/scan_invitation_screen_test.dart`

These cover list grouping, quick-add parsing, editor save flows, completed
flows, drawer/list filters, wide-layout detail behavior, settings navigation,
alarm-toggle persistence, sync invitation/pairing flows, and QR scan result
handling through an injected fake scanner surface.

## 5. Platform smoke tests (`integration_test`, CI matrix)

`integration_test/app_smoke_test.dart` runs on all five platforms in CI:
Linux, Windows, macOS, Android emulator, and iOS simulator.

- Flow: launch -> add todo -> complete -> restart -> data persisted.
- Desktop smoke runs use native runners (`xvfb` on Linux).
- Mobile smoke runs use an Android emulator and an iOS simulator.

## 6. Time and timezone suite

Fixed/fake clock injected everywhere. The Linux notification timer path also
takes an injected clock now, so there is no direct `DateTime.now()` use in the
time-sensitive app logic.

- DST correctness lives in `test/core/dst_test.dart`.
- CI reruns it under `TZ=America/New_York`.
- Local Windows runs are useful, but GitHub CI is the source of truth for that
  exact timezone environment.

## 7. Manual test matrix (per release)

The things automation cannot reach live under `docs/releases/`.

- Start from `docs/releases/v0.1.0-checklist.md`.
- Copy it forward for the next release and keep notes in the release file.
- Cover alarms with the app closed, permission flows, QR pairing between real
  platform pairs, real cloud-folder sync, and reboot behavior.
- Include the R13.9 zero-config gate in every release checklist:
  fresh install / first launch must stay one plain usable list with no
  mandatory onboarding, pairing, sync setup, or permission prompt needed to
  add and complete a todo.
- For every R13-R15 feature shipped in that release, add an explicit manual
  check that the default state stays opt-in, off, hidden, or otherwise quiet
  until the user deliberately enables or enters it.

## 8. Performance and battery (Phase 5)

### Budgets (TASKS.md 6.42)

| Metric | Budget | How it's checked |
|---|---|---|
| Cold start → interactive | < 2 s | manual profiling on a mid/low-tier device; the `integration_test` smoke boots the app on the CI matrix |
| Quick-add (submit → row on screen) | < 500 ms | manual; the write path is a single stamped insert (`TodoRepository.create`) plus a reactive `watch` refresh |
| 5k-task list: active query + `sectionize` + `filterTodos` | comfortably interactive (dev-machine reference well under 100 ms each) | `test/perf/large_dataset_test.dart` |

`test/perf/large_dataset_test.dart` builds a 5k-todo database and prints the
measured timings, but asserts only correctness plus a loose 2 s ceiling — a
guard against an accidental O(n²) or a hang, **not** a real-time budget, so it
can't flake on a slow CI runner. The wall-clock budgets above are verified by
profiling and the smoke flow, not by unit-test timing.

### Still to measure

- 10k-todo dataset: list scroll jank, search latency, sync round time.
- Sync payload size budget per 1k changes.
- Android battery: no wake locks held outside sync windows.
