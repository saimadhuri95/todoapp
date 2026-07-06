# TASKS

Detailed task breakdown. High-level plan and rationale live in [PLAN.md](PLAN.md);
design details in [docs/](docs/). Check items off as they land.

## Token budget & scheduling (Claude Pro, $20/mo)

Constraints: usage limits reset per ~5-hour session window, plus a weekly cap.
The planning unit below is one **work session** = one focused Claude Code sitting
that comfortably fits inside a window (roughly 15–30 substantial prompts).

### Budget rules

1. **One task group per session.** Finish and check off before the window ends;
   never open a big task with <30% of a window left.
2. **Session start ritual:** read CLAUDE.md + the `RESUME` section below + the
   current phase's tasks only. Do not re-read docs/ or old phases unless the
   task touches them.
3. **Session end ritual (or when limit warning appears):** check off finished
   tasks, update `RESUME` with exact state + next action, stop cleanly. This is
   what makes a token-limit interruption cost ~zero to restart from.
4. Subagents only for broad codebase searches, and only on **Haiku/Sonnet**.
   Main-line coding happens directly in the session — subagents re-derive
   context and usually cost more than they save.
5. Long command output (flutter build/test) gets tailed, not dumped.

### Execution order (changed 2026-07-05, user decision)

Alarms are deprioritized to last-but-one. Task IDs keep their original phase
numbers; the **order we execute** is:

1. Phase 0 ✓ → Phase 1 (core app)
2. **Phase 3 — Sync engine** (next after Phase 1)
3. **Phase 4 — Packaging**
4. **Phase 2 — Alarms** (last-but-one; includes Linux alarms 5.1/5.2)
5. Phase 5 — Polish & hardening

### Phase cost estimates

| Phase | Est. sessions | Token-heavy spots |
|---|---|---|
| 0 — Foundations | 2–3 | CRDT spike (0.6) is half of it |
| 1 — Core app | 4–6 | Editor UI, recurrence tests |
| 2 — Alarms | 4–6 | Per-platform native glue, permission flows |
| 3 — Sync | 6–8 | Biggest phase: merge engine + convergence tests, two transports |
| 4 — Packaging | 2–3 | Mostly config, but CI debugging can eat a session |
| 5 — Polish + Linux alarms | 4–6 | Linux background process, accessibility pass |
| **Total** | **~22–32** | ≈ 6–10 weeks at Pro's weekly limits |

### Near-term session schedule

- **S1:** 0.1–0.4 — scaffold, verify local builds, repo hygiene, state-mgmt pick
- **S2:** 0.7 + 0.8 — schema + HLC (pure Dart, cheap, high value)
- **S3:** 0.6 — CRDT spike (isolated on purpose: it's exploratory and can burn a window)
- **S4:** 0.5 — CI matrix (isolated: CI debugging is slow-feedback)
- **S5+:** Phase 1 in slices: data layer → list screen → editor → tests

## RESUME

> Update this before ending every session. Next session starts by reading this.

- **Current task:** Phase 3 functionally complete end-to-end; main green on all 5 platforms; 116 tests.
- **State:** Done: 3.1–3.7 (camera QR scan pending), 3.9 (protocol; mDNS pending), 3.10, 3.13, partial 3.12/3.14. The core promise works: pair via invitation → shared folder → Sync now → encrypted todos flow, serverless. Merged via PRs #1–#2; pairing chunk landed direct on main (gh pr merge --delete-branch switches local checkout to main — create the next branch BEFORE committing).
- **Phase 3 oddments (non-blocking):** 3.8 device revoke + key rotation, 3.11 mailbox compaction, mDNS discovery, camera QR scan, iCloud/SAF folder access, auto-sync triggers, per-device last-synced display.
- **Blockers for user:** install Xcode + Android Studio (needed NOW for Phase 4 packaging); pick a LICENSE; app name (PLAN.md open question 5)
- **Next action (Phase 4):** 4.1 app identity (name/icon/bundle ids — ask user for app name first), 4.7 release pipeline (tag → CI builds artifacts), then per-platform store/packaging configs (4.2–4.6; signing needs user accounts/certs).

## Phase 0 — Foundations

- [x] 0.1 Scaffold Flutter project with all five platform targets enabled (Flutter 3.44.4, org `com.sai`)
- [x] 0.2 Verify builds: **all 5 platforms build green on CI** (run 28763958480). Local iOS/macOS/Android builds still need user to install Xcode + Android Studio (required for Phase 2 device testing, not for CI)
- [x] 0.3 Repo hygiene: strict `analysis_options.yaml` done; .gitignore from scaffold; LICENSE pending (ask user which license)
- [x] 0.4 State management: **Riverpod** (dependency added when first used); feature-first folders
- [x] 0.5 CI: GitHub Actions (.github/workflows/ci.yml) — format/analyze/test gate + 5-target debug-build matrix; repo public (free Actions)
- [x] 0.6 CRDT spike → **hand-rolled per-field LWW** (docs/decisions/0001-crdt-choice.md); LwwApplier + 7 convergence tests landed as proof
- [x] 0.7 SQLite schema v1 (drift): todo_lists, todos, todo_alarms, devices, sync_log, alarm_dismissals, field_clocks; FK enforcement + tombstones tested
- [x] 0.8 HLC implementation (`lib/core/hlc.dart`) + injectable Clock (`lib/core/clock.dart`); 17 unit tests incl. clock-regression and lexical-sort properties

## Phase 1 — Core app (local-only)

### Data layer
- [x] 1.1 TodoRepository: create/edit/complete/uncomplete/softDelete/restore + watchActive/watchCompleted (`lib/data/repositories/`)
- [x] 1.2 ListRepository: create/rename/setColor/setSortOrder/archive; move todo via edit(listId)
- [x] 1.3 Tags (JSON column + typed extension) + priority
- [x] 1.4 Recurrence engine (`lib/core/recurrence.dart`): RRULE subset (FREQ/INTERVAL/BYDAY), RFC 5545 skip semantics for invalid dates, anchor-based series
- [x] 1.5 Every mutation stamps per-field HLC in-transaction (shared `sync_fields.dart`, also used by LwwApplier)
- [x] 1.6 Unit tests: repository CRUD/tombstones (11) + recurrence edge cases (16: Jan-31 monthly, Feb-29 yearly, interval jumps, anchor floor)

### UI
- [x] 1.7 List screen: Overdue/Today/Upcoming/Someday sections (pure `todo_sections.dart`), Completed expansion tile, per-list via drawer filter
- [x] 1.8 Todo editor: title, notes, due date/time pickers, recurrence dropdown, list, tags, priority. **Alarm times deferred to Phase 2** (needs scheduler + alarm repo)
- [ ] 1.9 Quick-add natural date parsing — deferred (nice-to-have; revisit in Phase 5 polish)
- [x] 1.10 Search bar filtering title/notes/tags (client-side)
- [x] 1.11 Responsive: master-detail split ≥840px, editor route below
- [x] 1.12 Keyboard shortcut Ctrl/Cmd+N for new todo (more shortcuts with Phase 5 accessibility pass)
- [x] 1.13 Settings scaffold (theme/alarm/sync placeholders wired to later phases)
- [x] 1.14 Widget tests: add/complete/delete/cancel flows, sections, editor save, search, completed section, wide layout, drawer list filter (12 tests)

## Phase 2 — Alarms (executed LAST-BUT-ONE — after Phases 3 & 4)

- [ ] 2.1 Alarm scheduler abstraction: platform-agnostic interface, per-platform implementations behind it
- [ ] 2.2 Integrate flutter_local_notifications; notification tap → open todo
- [ ] 2.3 Android: exact alarms (AlarmManager), `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` permission UX, BOOT_COMPLETED rescheduling, notification channels
- [ ] 2.4 iOS: UNUserNotificationCenter; 64-pending cap — schedule nearest N, refill on foreground + BGAppRefreshTask
- [ ] 2.5 Desktop opt-in: "Enable alarms on this device" toggle (default off) + OS permission request on enable; toggle off cancels all scheduled OS notifications
- [ ] 2.6 Windows: MSIX package identity; ScheduledToastNotification with `scenario="alarm"`, looping audio, snooze/dismiss buttons
- [ ] 2.7 macOS: UNUserNotificationCenter scheduled notifications; schedule-nearest-N + refill on launch
- [ ] 2.8 Snooze/dismiss actions from the notification itself (all enabled platforms)
- [ ] 2.9 Recurring todo → reschedule next alarm on completion/dismissal
- [ ] 2.10 Timezone & DST correctness: store alarms as local-time + zone id, recompute on zone change; test suite around DST transitions
- [ ] 2.11 Manual alarm test matrix executed per platform (see docs/testing.md)

## Phase 3 — Sync engine (executed SECOND — right after Phase 1)

### Core
- [x] 3.1 Changeset format (`changeset.dart`): versioned JSON envelope of HLC-stamped field writes; encryption/transport wrap this later
- [x] 3.2 Merge engine: LwwApplier + LWW-map row springing (incl. FK-referenced rows); idempotent + commutative
- [x] 3.3 Convergence tests: 3 devices × 3 seeds, random ops, clock skew, partial connectivity, shuffled delivery → byte-identical dumps
- [x] 3.4 Version vectors (max HLC per origin, derived from field_clocks) — replaced scalar cursors, which can lose relayed writes; sync_log kept as last-exchange info for the status UI

### Identity & crypto
- [x] 3.5 Device identity: X25519 keypair, `KeyStore` abstraction (SecureKeyStore → platform keychain; InMemoryKeyStore in tests), load-or-create in `device_identity.dart`
- [x] 3.6 Pairing flow: invitation = QR/pasteable JSON carrying inviter payload + group key (Syncthing-style trust model, `pairing_service.dart`); accept via paste works on all 5 platforms; fingerprint confirmation dialog; device rows replicate through sync itself. **Camera QR scanning pending** (mobile polish)
- [x] 3.7 Encryption: X25519 ECDH + HKDF session keys; XChaCha20-Poly1305 seal/open (`pairing_crypto.dart`); key rotation on revoke still pending (part of 3.8)
- [ ] 3.8 Device management UI: list paired devices, rename, revoke (+ group-key rotation on revoke)

### Transports
- [x] 3.9 LAN P2P protocol (`lan_transport.dart`): sealed length-framed TCP, one session syncs both directions; group key = authentication; 5 loopback tests. **mDNS advertise/browse still pending** (needs `bonsoir` platform plugin — wire with pairing UI)
- [x] 3.10 Cloud-drive mailbox (`mailbox_transport.dart`): sealed delta files `{deviceId}/{hlc}.bin` + encrypted vector marker; local cursors in sync_log; torn-upload retry; 6 tests incl. ciphertext-only check
- [ ] 3.11 Mailbox compaction: periodic snapshot + prune of applied changesets
- [ ] 3.12 Platform folder access: desktop directory picker done (`file_selector` in sync settings); **pending:** iCloud Drive container (iOS/macOS native channel), SAF verification on Android
- [x] 3.13 SyncOrchestrator: syncNow (consume→publish→LAN peers), reentry guard, periodic timer, per-transport error reporting; foreground/mutation triggers hook in at UI wiring

### Product
- [ ] 3.14 Sync status UI: first cut done (device list, Sync now with report snackbar in `sync_settings_screen.dart`); pending: per-device last-synced timestamps, auto-sync triggers (foreground/mutation debounce), background orchestrator start
- [ ] 3.15 Alarm dismissal sync: dismissal records propagate; receiving device cancels matching scheduled notification
- [ ] 3.16 Integration tests: 3-device simulation — offline edits, delete-vs-edit races, clock skew, pairing/revocation

## Phase 4 — Packaging & distribution (executed THIRD — before alarms)

- [ ] 4.1 App icon, name, bundle ids
- [ ] 4.2 Android: signing config, Play internal track
- [ ] 4.3 iOS: provisioning, notification entitlements, TestFlight
- [ ] 4.4 macOS: hardened runtime, notarized .dmg
- [ ] 4.5 Windows: MSIX + code signing cert
- [ ] 4.6 Linux: Flatpak manifest (primary); AppImage secondary
- [ ] 4.7 Release pipeline: tag → CI builds + uploads all artifacts
- [ ] 4.8 Auto-update strategy per platform (stores handle mobile/mac; Sparkle-style or winget/Flathub for desktop)

## Phase 5 — Polish & hardening (executed LAST)

- [ ] 5.1 *(moved into the alarms phase)* Linux alarms (opt-in, same toggle): resident background/tray process at login (autostart + XDG Background portal under Flatpak) posting libnotify notifications; systemd user timers as fallback
- [ ] 5.2 *(moved into the alarms phase)* Optional "run in background at login" toggle on all desktops (live sync + cross-device dismissal while window closed)
- [ ] 5.3 Import/export JSON; full local backup/restore
- [ ] 5.4 Dark mode + theming
- [ ] 5.5 Accessibility pass: screen readers, contrast, font scaling, full keyboard nav
- [ ] 5.6 Localization scaffold (intl), English strings extracted
- [ ] 5.7 Performance: 10k-todo list scrolling, sync payload size, app start time budget
- [ ] 5.8 Battery audit: sync frequency, wake locks, background refresh behavior
- [ ] 5.9 Onboarding: first-run + "add your second device" flow
- [ ] 5.10 Beta round on all five platforms; triage and fix

## Testing (cross-cutting — details in docs/testing.md)

- [ ] T.1 Unit test suites wired into CI from Phase 0 (HLC, repositories, recurrence, merge)
- [ ] T.2 Widget tests for every screen as it's built
- [ ] T.3 Property-based convergence harness (Phase 3 gate: no release with a failing convergence property)
- [ ] T.4 Multi-device sync simulator (in-process fake transports; runs in CI)
- [ ] T.5 integration_test smoke suite per platform in CI (launch, add todo, complete, restart-persists)
- [ ] T.6 Timezone/DST regression suite
- [ ] T.7 Manual test matrix doc per release: alarms, pairing, permission flows per platform
- [ ] T.8 Coverage floor: 80% on data/sync layers, enforced in CI
