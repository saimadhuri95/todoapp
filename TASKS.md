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

- **Current task:** Apple-focus session (user direction 2026-07-06: Apple ecosystem first). Done: PR #7 quick-add merged; PR #8 = macOS bug fixes 4.16–4.20 (entitlements, FileKeyStore fallback for QR, bookmarks, Bonjour keys, error SnackBars) + 3.12 iCloud channel; 188 tests; macOS launched OK, iOS builds.
- **Blocked on user:** 4.21 re-verify on a fresh installed release build (pick folder → relaunch → still syncs; QR renders; LAN discovery prompts). Apple Developer account for: iCloud entitlement flip + Keychain Sharing capability (steps in docs/packaging.md), TestFlight 4.3, notarized dmg 4.4. Also Play Console/MSIX cert; real-device testing (2.11, 5.5, 5.8, 5.10).
- **Apple tail (next per user direction):** camera QR scan for pairing (iOS), ASO metadata 4.9–4.12, screenshot staging from simulators. Then: Linux tray 5.1/5.2, Android SAF verification, ARB extraction.
- **Next action:** PR #8 merged (all 6 checks green). Fresh session: camera QR scan for pairing (iOS first, per Apple-first direction) or ASO metadata 4.9–4.12. User: re-verify per 4.21.

## Phase 0 — Foundations

- [x] 0.1 Scaffold Flutter project with all five platform targets enabled (Flutter 3.44.4, org `com.sai`)
- [x] 0.2 Verify builds: all 5 platforms green on CI **and** local toolchain complete (Xcode 26.6 + Android SDK 36): Knot.app built & launched on macOS, iOS Runner.app built --no-codesign
- [x] 0.3 Repo hygiene: strict `analysis_options.yaml`, .gitignore, MIT LICENSE (user decision 2026-07-06)
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
- [x] 1.9 Quick-add natural date parsing (`lib/core/natural_date.dart`, pure Dart, caller passes injected now): today/tonight/tomorrow, weekdays±next, "in N units", month-day, times; live "Due …" preview in add dialog; 36 tests
- [x] 1.10 Search bar filtering title/notes/tags (client-side)
- [x] 1.11 Responsive: master-detail split ≥840px, editor route below
- [x] 1.12 Keyboard shortcut Ctrl/Cmd+N for new todo (more shortcuts with Phase 5 accessibility pass)
- [x] 1.13 Settings scaffold (theme/alarm/sync placeholders wired to later phases)
- [x] 1.14 Widget tests: add/complete/delete/cancel flows, sections, editor save, search, completed section, wide layout, drawer list filter (12 tests)

## Phase 2 — Alarms (executed LAST-BUT-ONE — after Phases 3 & 4)

**Design change (2026-07-06):** alarms are LWW fields on the todo (offset
minutes + lastDismissedMs + snoozeUntilMs, schema v3) — dismissals sync via
the ordinary merge engine; todo_alarms/alarm_dismissals tables unused.

- [x] 2.1 AlarmScheduler interface + pure `planAlarms` (`lib/core/alarm_planner.dart`); Noop/fake for tests
- [x] 2.2 flutter_local_notifications scheduler (`notification_scheduler.dart`); payload carries todoId+occurrence; foreground action handling (background-isolate handler → polish)
- [x] 2.3 Android: exactAllowWhileIdle, POST_NOTIFICATIONS + SCHEDULE_EXACT_ALARM permission flow, boot receiver, alarm channel, gradle desugaring
- [x] 2.4 iOS: planner cap 50 (<64 limit); every replan (mutation/sync/foreground) is the refill. BGAppRefreshTask → polish
- [x] 2.5 Opt-in toggle (mobile default-on, desktop off) + permission request on enable; off = cancelAll
- [ ] 2.6 Windows: plugin schedules toasts, but firing while the app is closed needs MSIX identity — verify once MSIX packaging lands (blocked on cert, docs/packaging.md)
- [x] 2.7 macOS: UNUserNotificationCenter via plugin, same cap/refill
- [x] 2.8 Snooze (10 min) / dismiss actions on the notification (Android actions + Darwin categories)
- [x] 2.9 Recurring: planner expands occurrences; dismissal only silences ≤ dismissed occurrence
- [x] 2.10 TZ/DST: expansion runs in local calendar space; DST suite green under TZ=America/New_York (CI step). Cross-zone wall-clock storage documented as v1 limitation (docs/alarms.md), deferred
- [ ] 2.11 Manual alarm matrix — needs real devices (user; iOS also needs Xcode)
- [x] 3.15 (moved here) Alarm dismissal sync — by construction: dismissal is a synced field write; test in sync_engine_test
- [ ] 5.1 (moved here) Linux resident process — in-app timers while running done; tray/autostart still open
- [ ] 5.2 (moved here) "Run in background at login" toggle — open

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
- [x] 3.8 Device management: rename + revoke (tombstone replicates, group key rotates, mailbox wiped, re-pair flow); devices.deleted via schema v2 migration

### Transports
- [x] 3.9 LAN P2P: sealed length-framed TCP protocol (5 loopback tests) + mDNS advertise/browse via bonsoir (`lan_discovery.dart` — CI-untestable, in manual matrix)
- [x] 3.10 Cloud-drive mailbox (`mailbox_transport.dart`): sealed delta files `{deviceId}/{hlc}.bin` + encrypted vector marker; local cursors in sync_log; torn-upload retry; 6 tests incl. ciphertext-only check
- [x] 3.11 Mailbox compaction: outbox >20 deltas → single snapshot (idempotent for late peers); runs inside orchestrator pass
- [ ] 3.12 Platform folder access: desktop picker done; iCloud Drive container done (`cloud_folder.dart` interface + `com.sai.knot/cloud_folder` channel on iOS/macOS, "Use iCloud Drive" in sync settings — returns nil until the iCloud entitlement lands with real signing, docs/packaging.md); **pending:** SAF verification on Android
- [x] 3.13 SyncOrchestrator: syncNow (consume→publish→LAN peers), reentry guard, periodic timer, per-transport error reporting; foreground/mutation triggers hook in at UI wiring

### Product
- [x] 3.14 Sync status + triggers: per-device last-synced (sync_log.lastSyncedAtMs, schema v2), SyncService (foreground resume, 5s mutation debounce, 5min periodic, LAN server + mDNS start) via SyncBootstrap in main()
- [ ] 3.15 Alarm dismissal sync: dismissal records propagate; receiving device cancels matching scheduled notification
- [x] 3.16 Integration tests: 3-device convergence (3 seeds), delete-vs-edit races, clock skew, pairing + revocation, transport relays — spread across convergence/sync_engine/mailbox/pairing suites

## Phase 4 — Packaging & distribution (executed THIRD — before alarms)

- [x] 4.1 Name **Knot**, bundle id `com.sai.knot`, MIT LICENSE, generated icon (`tool/gen_icon.dart` → all platforms via flutter_launcher_icons)
- [x] 4.2 Android signing: gradle reads `android/key.properties` (gitignored) else debug key. **User steps** (keystore + Play Console) in docs/packaging.md
- [ ] 4.3 iOS TestFlight — **blocked on user**: Xcode install + Apple Developer Program; steps in docs/packaging.md
- [ ] 4.4 macOS notarized dmg — **blocked on user**: Apple Developer ID cert; steps in docs/packaging.md
- [x] 4.5 Windows: release zip in pipeline; MSIX deferred until a code-signing cert exists (docs/packaging.md)
- [x] 4.6 Linux: Flatpak manifest + desktop + metainfo in packaging/flatpak/; Flathub submission is a user step
- [x] 4.7 Release pipeline (.github/workflows/release.yml): tag v* → draft GitHub Release with linux/windows/macos/android artifacts
- [x] 4.8 Auto-update strategy documented (docs/packaging.md): stores for mobile; GitHub Releases v1 for desktop; winget/Flathub/Sparkle post-v1

### ASO — App Store search ranking (added 2026-07-06)

Goal: rank for "todo app"-style searches. Name + subtitle carry the highest
index weight; the hidden keyword field fills the rest; velocity + conversion
do the ranking after that. Drafting (4.9–4.12) is automatable now; entering
metadata in App Store Connect is blocked on the Apple Developer account (4.3).

- [ ] 4.9 App Store name with keyword modifier (30-char cap; highest search weight — bare "Knot" won't index for "todo"). Candidates: "Knot – Todo List & Sync" (23) or "Knot: Shared Todo List" (22). Decide + record in docs/packaging.md
- [ ] 4.10 Subtitle (30-char cap, second-highest weight; must not repeat any word from the name). Candidates: "Collaborative Task Manager" (26) or "Shared Tasks, Private Sync" (only if name drops "Sync")
- [ ] 4.11 Hidden 100-char keyword field: comma-separated, no spaces, no words already in name/subtitle (Apple auto-combines singles into phrases). Draft (93 chars): `shared,checklist,organizer,p2p,private,group,team,cooperative,planning,reminders,productivity` — re-prune against final 4.9/4.10 word choices
- [ ] 4.12 Screenshot set for conversion: first 3 shots show the sync/pairing UI with a value-prop caption overlay ("Instant Sync, Zero Cloud Accounts"); produce required iPhone/iPad/Mac sizes (can stage from simulators before the dev account exists)
- [ ] 4.13 Google Play counterpart: title (30), short description (80, indexed), full description written for keyword coverage — Play indexes the description, unlike Apple, so the no-repeat rule doesn't apply there
- [ ] 4.14 Launch-velocity plan: time the store release with a Product Hunt / Hacker News / r/selfhosted post so the download spike lands while the listing is fresh (velocity drives rank for competitive terms)
- [ ] 4.15 Post-launch ASO loop: watch search rank for "todo app"/"shared todo list" + impression→download conversion in App Store Connect analytics; iterate keyword field each release (it's updatable without an app review... but only alongside a new build)

### macOS sandbox fixes (manual-test findings 2026-07-06)

User-reported on the installed macOS app: sync-folder picker missing/broken +
pairing QR dialog never appears. Root cause: `Release.entitlements` contains
**only** `app-sandbox` — no user-selected-files, no network, no keychain —
and errors are swallowed silently by the UI. 4.16/4.17/4.19/4.20 are direct
fixes; 4.18 is the follow-on persistence bug the picker fix will expose.

- [x] 4.16 Entitlements: user-selected.read-write, network.client+server, bookmarks.app-scope in both Release and DebugProfile. NOTE: keychain-access-groups deliberately excluded — restricted entitlement, breaks ad-hoc signing (Xcode refuses to build); see 4.17
- [x] 4.17 Keychain failure fixed the buildable way: `FallbackKeyStore` (keychain → `FileKeyStore` JSON in app container) in device_identity.dart — the capability itself needs real signing, so QR now works on ad-hoc builds via the file store and auto-upgrades to keychain once signing lands (add Keychain Sharing capability then, docs/packaging.md)
- [x] 4.18 Security-scoped bookmarks: createBookmark/resolveBookmark on the 3.12 interface (macOS Swift side in MainFlutterWindow), bookmark persisted as `mailboxBookmark` pref on pick, resolved + access-started in main() before the container is built; iCloud path clears it
- [x] 4.19 Local-network privacy keys in macOS + iOS Info.plist: `NSLocalNetworkUsageDescription` + `NSBonjourServices` (`_todosync._tcp`)
- [x] 4.20 Surface platform errors in sync settings UI: `_guarded` wrapper (error SnackBars) around invitation/picker/iCloud actions + generic catch in `_enterInvitation`
- [ ] 4.21 Re-verify on a fresh installed (release) build: pick folder → relaunch → folder still syncs; QR dialog renders; LAN peer discovery works

## Phase 5 — Polish & hardening (executed LAST)

- [ ] 5.1 *(moved into the alarms phase)* Linux alarms (opt-in, same toggle): resident background/tray process at login (autostart + XDG Background portal under Flatpak) posting libnotify notifications; systemd user timers as fallback
- [ ] 5.2 *(moved into the alarms phase)* Optional "run in background at login" toggle on all desktops (live sync + cross-device dismissal while window closed)
- [x] 5.3 Export/import JSON (`export_service.dart` + settings UI): includes tombstones; import upserts with fresh HLC stamps so restores sync onward
- [x] 5.4 Dark mode (light/dark themes since Phase 1, follows system)
- [ ] 5.5 Accessibility pass: screen readers, contrast, font scaling, full keyboard nav (manual work, needs devices)
- [x] 5.6 L10n scaffold: gen_l10n wired (l10n.yaml, app_en.arb, delegates in MaterialApp); full string extraction is ongoing as screens are touched
- [x] 5.7 List perf: flattened rows + ListView.builder (lazy at 10k); sync payload/start-time budgets still to measure
- [ ] 5.8 Battery audit: sync frequency, wake locks, background refresh behavior (needs devices)
- [x] 5.9 Onboarding: guided empty state (add hint + shortcut + pair-device button); richer flow post-beta if needed
- [ ] 5.10 Beta round on all five platforms; triage and fix (user + devices)

## Testing (cross-cutting — details in docs/testing.md)

- [ ] T.1 Unit test suites wired into CI from Phase 0 (HLC, repositories, recurrence, merge)
- [ ] T.2 Widget tests for every screen as it's built
- [ ] T.3 Property-based convergence harness (Phase 3 gate: no release with a failing convergence property)
- [ ] T.4 Multi-device sync simulator (in-process fake transports; runs in CI)
- [ ] T.5 integration_test smoke suite per platform in CI (launch, add todo, complete, restart-persists)
- [ ] T.6 Timezone/DST regression suite
- [ ] T.7 Manual test matrix doc per release: alarms, pairing, permission flows per platform
- [ ] T.8 Coverage floor: 80% on data/sync layers, enforced in CI
