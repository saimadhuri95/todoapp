# Testing strategy

Test-heavy where bugs are silent and catastrophic (sync, time), lighter where
failures are visible (UI). Everything below CI-enforced unless marked manual.

## 1. Unit tests (every phase, from Phase 0)

- **HLC**: monotonicity, tie-breaking by deviceId, behavior under wall-clock
  regression.
- **Repositories**: CRUD, tombstone semantics, restore.
- **Recurrence**: next-occurrence expansion — monthly on the 31st, Feb/leap
  years, weekly masks, count/until termination.
- **Merge engine**: LWW per field, delete-vs-edit, duplicate application.
- Coverage floor: **80% on data + sync layers** (UI excluded from the floor).

## 2. Property-based convergence tests (Phase 3 gate)

The single most important suite in the project.

- Harness: N in-memory simulated devices, generator produces random op
  sequences (create/edit/complete/delete/move), random partitions, duplicated
  and reordered delivery, injected clock skew.
- Property: after full exchange, **all devices hold byte-identical state**.
- Second property: idempotency — re-applying any prefix of changesets changes
  nothing.
- No release while any convergence property fails. Shrunk counterexamples get
  committed as regression tests.

## 3. Multi-device integration tests (CI)

In-process devices with fake transports (fake LAN, fake mailbox directory):
- 3-device chains: A edits offline → syncs to B via LAN → B to C via mailbox.
- Pairing, revocation, key rotation.
- Partial/corrupt mailbox files are skipped, not crashed on.
- Alarm dismissal propagation cancels the right scheduled notification.

## 4. Widget tests

Per screen as built: list grouping (Today/Upcoming/Overdue), editor
validation, quick-add parsing, settings toggles. Golden tests for the two
layout modes (phone single-pane, desktop dual-pane).

## 5. Platform smoke tests (`integration_test`, CI matrix)

On each of the five platforms: launch → add todo → complete → kill →
relaunch → data persisted. Runs on GitHub Actions (macOS/Windows/Linux runners;
Android emulator; iOS simulator).

## 6. Time & timezone suite

Fixed/fake clock injected everywhere (no `DateTime.now()` outside the clock
provider — lint-enforced). Cases: DST spring-forward alarm at a nonexistent
time, fall-back duplicated hour, device timezone change, alarm across zone
travel, recurrence around DST.

## 7. Manual test matrix (per release)

The things automation can't reach — one checklist doc per release under
docs/releases/:
- Alarm actually rings with app closed: Android, iOS, Windows (opt-in),
  macOS (opt-in).
- Permission flows: fresh install, denied-then-granted, revoked-in-settings.
- QR pairing between each platform pair that matters (phone↔desktop both ways).
- Real cloud-drive sync: iCloud (iPhone↔Mac), Google Drive folder
  (Android↔Windows), plain synced folder (Linux).
- Reboot: alarms survive on Android; toggle-off cancels on desktop.

## 8. Performance & battery (Phase 5)

- 10k-todo dataset: list scroll jank, search latency, sync round time.
- Sync payload size budget per 1k changes.
- Android battery: no wake locks held outside sync windows (verified with
  Battery Historian on a beta build).
