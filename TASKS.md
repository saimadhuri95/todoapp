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

- **Session 2026-07-08 (groups schema, 8.2):** issue #94 done on `feature/8.2-groups-schema`. Schema v4: `sync_groups` (synced name/backendKind; device-local `local_account_ref` excluded from syncColumns), `group_members` (deterministic `<groupId>:<deviceId>` ids, nullable FKs for row-springing), `todo_lists.groupId` (null = local-only default). `LwwApplier` FK springing generalized to a map (todos.listId, todo_lists.groupId, member FKs). `MailboxTransport.groupId` → cursor keys `group:<gid>:mailbox:<peer>` (applied to the post-PR#110 native/web split; web placeholder takes the param). `GroupRepository` + `ListRepository.setGroup` + providers. Rebased over PR #110 (web support; mailbox_transport is now a conditional-export shim — edits go in `_native.dart`). 13 new tests + repositories stamp-count updated (5 list fields now); 332 local (4 fails = 3 known macOS-host + none new); lib/data 85.7%; DST green. **iPhone verified:** v4 app builds, installs, launches on iPhone 17 Pro sim (fresh-install path; upgrade path unit-tested), integration smoke green, sqlite shows user_version=4 + both tables. **Next: 8.3 scoped changesets (#95) — `changesFor(vector, {groupId})` + per-scope convergence gate; then 8.6 multi-mailbox orchestrator (#98).**
- **Session 2026-07-08 (WebDAV backend, 8.11):** PR #91 (cloud accounts + ADR 0003/0004) merged after CI green — its one real CI failure was a stale sync-health wording assertion, fixed. Then 8.11 done as PR #108 (merged, issue #107 closed): `WebDavMailboxStore` (PROPFIND depth-1 namespace-agnostic XML via `package:xml` now a direct dep, GET/PUT/DELETE, MKCOL-on-demand + one PUT retry, recursive wipe, rooted `<server>/knot-mailbox/`), `CloudAccountService.connectWebDav` with connect-time probe + slash-safe URL join, keychain `WebDavCredentials`, connect-screen WebDAV row + URL/user/password dialog (iCloud taps scoped — two rows say Connect now), `FakeHttp` moved to `test/support/`. 316 tests, lib/data 86.4%, DST green; same 3 macOS-host local fails. **User decision 2026-07-08: iCloud + WebDAV first, OAuth registrations (7.8/#103) after the iPhone app is ready.** **Next: 8.2 schema (`sync_groups`, `todo_lists.groupId`, per-group membership + sync_log namespacing — issue #94), own session; then 8.3 scoped changesets (#95).**
- **Session 2026-07-08 (sharing groups design, 8.1):** user direction refined: local-only stays the default; **multiple** cloud storages at once; per-list *sharing groups* — e.g. Local + "Family" list shared with wife over iCloud + "Friends" list shared with a non-Apple friend over Dropbox. Wrote ADR 0004 (`docs/decisions/0004-sharing-groups.md`: group = backend + per-group key + members + lists; scoped changesets subsume 6.28; QR invite = `{groupId, key, backend hint}`; members bring their own accounts; incremental Dropbox consent; per-group rotation; drawer/wizard UI blueprint), docs/sync.md §Sharing groups, TASKS.md Phase 8 (8.1 done, 8.2–8.10 fine-grained implementation slices). Branch `feature/iphone-cloud-storage` merged with latest main (conflicts resolved: 6.45 allowlist ported onto the `MailboxStore` refactor — 303 tests pass, 3 pre-existing macOS-host fails; my ADR renumbered 0002→0003 after the attachments ADR took 0002). GitHub issues filed for 7.8–7.10 + 8.2–8.10; 8.1 tracked in-progress → closes with PR #91. **Next:** merge PR #91 when CI is green, then 8.2 (schema) — own session.
- **Session 2026-07-07 (iPhone cloud accounts, ADR 0003):** user direction executed in worktree `todoapp-wt-iphone`, branch `feature/iphone-cloud-storage`, PR #91. New: `MailboxStore` seam (mailbox protocol over any file store; `FolderMailboxStore` = old behavior), `lib/data/cloud/` (PkceFlow OAuth2+PKCE no-SDK, TokenSet in keychain, `CloudAccountService`, Dropbox/GDrive-appdata/OneDrive-approot REST stores, scripted-HTTP unit tests), solo-device sync (`buildOrchestrator` creates group key when a mailbox is configured, pairing shares it later), Settings → Cloud storage connect screen + "Your data" source overview + first-launch sheet (skippable, invariant 1), iOS `knot://` scheme + AppDelegate → `OAuthCallbackChannel`. Verified: iPhone 17 Pro sim boots + onboarding renders + integration smoke passes; 301 tests, lib/data 85.8%, DST green; 3 local fails = pre-existing macOS-host class (also on clean main). **Remaining: 7.8 provider app registrations (user, free) → end-to-end OAuth; 7.9 account labels; 7.10 Android/desktop redirect parity.** See docs/decisions/0003-cloud-provider-accounts.md + docs/cloud-providers.md.
- **Session 2026-07-07 (attachments design, 6.47):** 6.47 done (design-doc deliverable). New ADR `docs/decisions/0002-attachments.md`: split small synced metadata rows (new `attachments` table, per-field LWW + tombstone) from large immutable bytes; content-addressed local blob store (`<appSupport>/attachments/<sha256>`), 25 MB/attachment + 500 MB soft device cap; lazy out-of-band blob fetch over the mailbox (`blobs/<hash>.bin`, group-key sealed, reusing the 6.45 allowlist) and a LAN `GET blob`; ciphertext-only in transit, plaintext at rest (matching the local DB); tombstone + grace-period GC. Implementation slices (schema, BlobStore, transport hooks, UI) are the follow-up tail, gated on sign-off. Docs-only PR, isolated worktree.
- **Session 2026-07-07 (Syncthing-tolerant mailbox, 6.45):** 6.45 done. `MailboxTransport.consume`/`compactIfNeeded` now allowlist only our own changeset files (`^\d{15}_[0-9a-f]{4,}_[^.\s()~]+\.bin$`, the `_fileNameFor` shape) and treat only non-dot subdirs as peer outboxes, so third-party artifacts are ignored: Syncthing `*.sync-conflict-*` + `.stversions`/`.stfolder`, Dropbox "(conflicted copy)", iCloud `.icloud`, `~`/`.tmp`. Fixes a latent bug where a conflict copy could sort past a real file and advance the cursor, stranding later changesets; also stops compaction from counting/deleting foreign files. New tests in `test/data/mailbox_transport_test.dart` (consume-ignores-artifacts + compaction-ignores-artifacts, both green with the full 10-case file). docs/sync.md gains a "Third-party tolerance" bullet. Sync-layer only, no UI. Isolated worktree/branch.
- **Session 2026-07-07 (encrypted backup, 6.41):** 6.41 done. New `lib/data/backup_service.dart` (`BackupService`): passphrase → PBKDF2-HMAC-SHA256 (210k rounds, overridable for tests) → XChaCha20-Poly1305 via `PairingCrypto.seal/open` over the JSON export, wrapped in a versioned JSON envelope (`app/kind/v/kdf/iterations/salt/payload`). `restoreBackup` decrypts + `importJson`; wrong passphrase/tamper → `BackupPassphraseError`, non-backup files → `FormatException`. Settings gains "Encrypted backup"/"Restore encrypted backup" tiles + a `_PassphraseDialog` (confirm on create). docs/sync.md gains a "mailbox is a transport, not a backup" subsection. New `test/data/backup_service_test.dart` (7 cases: roundtrip, no-plaintext envelope, wrong-passphrase, tamper, empty-passphrase, bad-file, default work factor). Isolated worktree/branch, parallel to the other loop.
- **Session 2026-07-07 (external import, 6.40):** 6.40 done. New pure `lib/data/import_parsers.dart` (`ImportedTodo` + `parseTodoTxt`/`parseCsv`) parses todo.txt, generic CSV, and Todoist/TickTick CSV exports — hand-rolled RFC-4180 tokenizer (quotes/embedded newlines, comma/tab autodetect), alias-based column matching, TickTick preamble skip, source-specific priority maps (Todoist 1–4, TickTick 0/1/3/5 → Knot 0–3). `ExportService.importParsed()` writes fresh uuid-v7 rows with one batch HLC stamp (mirrors `importJson`); Settings import now accepts json/txt/csv/tsv and dispatches by extension. New `test/data/import_parsers_test.dart` (19 cases); `lib/data/import_parsers.dart` + `export_service.dart` 100% covered, `lib/data` 88.1%. Analyzer/format/DST clean. Only failure locally is the pre-existing macOS `settings_screen_test` "Sync now" fold (also fails on base; tracked by PR #17). Done in an isolated worktree/branch to run in parallel with the 6.33 loop.
- **Session 2026-07-07 (completion recap):** 6.33 done. New pure `completionRecap()` + `CompletionRecap` in `todo_sections.dart` buckets completed todos into Today / Earlier this week (Mon-first) / Older, preserving repo order, unstamped rows → Older. List screen's flat "Completed (N)" ExpansionTile replaced by `_CompletedRecapTile`: subtitle "`X done today · Y this week`" (week folds in today), items grouped under labelled subheaders. New `test/features/completion_recap_test.dart` (5 unit + 1 widget). Full suite green except the pre-existing macOS-local `settings_screen_test` "Sync now" fold failure (also fails on clean `main`; tracked by PR #17). Analyzer clean; coverage 85.7% on lib/data; DST pass. Optional end-of-day shutdown ritual deferred as a follow-up. Pure Dart/UI, no platform paths → integration smoke via CI.
- **Session 2026-07-07 (multi-line paste):** 6.26 done. Quick-add `_AddTodoDialog` field is now multi-line (`TextInputType.multiline`, `maxLines: 5`, Enter still submits via `textInputAction.done`) so a pasted list keeps its line breaks; `_showAddDialog` splits via new pure `splitTodoLines()` and, when >1 line, shows `_SplitLinesDialog` ("Single todo" vs "N todos"). One-todo path collapses lines with spaces. New `test/features/multiline_add_test.dart` (unit + widget). 241 tests green locally; analyzer clean; coverage 85.7% on lib/data; DST pass. macOS/Windows integration smoke left to CI (pure Dart/UI change, no platform paths).
- **Update 2026-07-06:** testing hardening complete and rebased onto latest `main` after PR #15 landed. Landed: shared simulated-device + fake-transport harnesses, missing screen widget tests, `integration_test` smoke flow, CI/release gates, the coverage floor script, and manual release checklist docs.
- **Local verification:** 234 `flutter test` cases, `dart tool/check_coverage.dart --lcov coverage/lcov.info --min 80 --scope lib/data` (85.7% on `lib/data`), `test/core/dst_test.dart`, and Windows `integration_test/app_smoke_test.dart` all pass.
- **Next action:** fresh session -> 6.8 calendar view or 6.13 subtasks (each big - own session). Phase 6 P1 small items are now exhausted except 6.7 minimalist audit (do after using 6.3's line a while), 6.10 unattended-viewer doc, 6.14/6.18 (need platform/native or doc work).

- **Current task:** Apple-first push (user direction 2026-07-06) — session complete. Merged: PR #7 quick-add, PR #8 macOS fixes 4.16–4.20 + iCloud channel, PR #9 camera QR (6.1). REQUIREMENTS.md triaged → Phase 6. ASO 4.9–4.11 decided ("Knot – Todo List & Sync" / "Collaborative Task Manager", docs/packaging.md). 188 tests.
- **Automatable Apple work is now exhausted** except 4.12 screenshot staging (simulators) and Phase 6 cross-platform features that also serve Apple (6.2 notifications, 6.4 links, 6.6 theme override, 6.8 calendar).
- **Blocked on user:** 4.21 re-verify on a fresh installed release build (folder→relaunch→syncs; QR renders; camera scan; LAN prompt). Apple Developer account unlocks: iCloud entitlement + Keychain Sharing (steps in docs/packaging.md), TestFlight 4.3, notarized dmg 4.4, App Store Connect metadata entry (values ready in packaging.md). Also Play Console/MSIX cert; device testing (2.11, 5.5, 5.8, 5.10).
- **Requirements session 2026-07-06:** REQUIREMENTS.md expanded to R1–R17 (two research passes: competitor features, abandonment psychology, ADHD, GTD, routines, caregivers, kiosk) and fully triaged → Phase 6 wave 2 (6.13–6.57, prioritized P1/P2/alarms-phase/P3). Wave-1 tasks' stale R-refs fixed to current numbering. No code changed.
- **Session 2026-07-06 (links+theme):** 6.4 + 6.6 merged as PR #12. New: `lib/core/linkify.dart`, `LinkifiedText` (urlOpenerProvider), themeModeProvider + settings dropdown, QR white background for dark mode.
- **Session 2026-07-06 (inbox+overdue):** 6.15 + 6.16 merged as PR #13. Inbox = null listId (see 6.15 note re: sync safety), `kInboxFilter` sentinel + `watchActive(unfiledOnly:)`, tile move-to-list popup; sectionize folds Overdue→Today + pure `overdueLabel`.
- **Session 2026-07-06 (export):** 6.17 merged as PR #14. exportMarkdown/exportTodoTxt in ExportService + settings format picker.
- **Session 2026-07-06 (latency+density+recurrence):** 6.3 + 6.5 + 6.9 landed on `main` as PR #15. Latency table in docs/sync.md + status line (`lastSyncPassProvider`); glanceable `DisplayDensity`; recurring complete() advances due in place (CRDT-safe). 226 tests at merge time.

## Phase 0 — Foundations

- [x] 0.1 Scaffold Flutter project with all five platform targets enabled (Flutter 3.44.4, org `com.sai`)
- [x] 0.2 Verify builds: all 5 platforms green on CI **and** local toolchain complete (Xcode 26.6 + Android SDK 36): Knot.app built & launched on macOS, iOS Runner.app built --no-codesign
- [x] 0.3 Repo hygiene: strict `analysis_options.yaml`, .gitignore, Knot Source Available LICENSE (updated user decision 2026-07-06)
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

- [x] 4.1 Name **Knot**, bundle id `com.sai.knot`, Knot Source Available LICENSE, generated icon (`tool/gen_icon.dart` → all platforms via flutter_launcher_icons)
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

- [x] 4.9 App Store name: **"Knot – Todo List & Sync"** (user pick 2026-07-06); recorded in docs/packaging.md
- [x] 4.10 Subtitle: **"Collaborative Task Manager"** (26 chars, no name-word repeats); recorded in docs/packaging.md
- [x] 4.11 Keyword field pruned against final name/subtitle (95 chars, docs/packaging.md): `shared,checklist,organizer,p2p,private,group,team,family,planner,grocery,reminders,productivity` — enter in App Store Connect with 4.3
- [ ] 4.12 Screenshot set for conversion: first 3 shots show the sync/pairing UI with a value-prop caption overlay ("Instant Sync, Zero Cloud Accounts"); produce required iPhone/iPad/Mac sizes (can stage from simulators before the dev account exists)
- [x] 4.13 Google Play counterpart documented in [docs/launch.md](docs/launch.md):
  title (30), short description (80), and full description written for keyword
  coverage; Play can lean on description indexing more than Apple
- [x] 4.14 Launch-velocity plan documented in [docs/launch.md](docs/launch.md):
  store release timed with Product Hunt / Hacker News / r/selfhosted as one
  coordinated spike instead of a dribbled multi-day launch
- [x] 4.15 Post-launch ASO loop documented in [docs/launch.md](docs/launch.md):
  App Store Connect acquisition metrics, release-over-release hypotheses, and
  keyword iteration bundled into the next version's metadata pass

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

## Phase 6 — User-sourced requirements (REQUIREMENTS.md, triaged 2026-07-06)

Only 🆕/🔶 items become tasks. Wave 1 (6.1–6.12) triaged the first draft;
R-references are updated to the current expanded file (R1–R17). Wave 2
(6.13+) triages the 2026-07-06 research passes. ✅/already-built requirements
map to existing work instead of new tasks: R1.3→0.6, R2.1→1.9, R3.3/R3.4→1.3,
R3.5→1.8, R5.1→1.7, R5.4→1.10 (move to FTS only if perf demands), R10.x→5.5,
R11.1-JSON→5.3, R12.1→6.12, R12.2/R12.3→project premise. Ordering favors the
driver/dispatcher scenario and Apple-first direction.

- [x] 6.1 (R1.4 + pairing UX) Camera QR scan for pairing: mobile_scanner 7.2
  screen (`scan_invitation_screen.dart`) on iOS/Android/macOS feeding the
  shared `_acceptInvitation` flow; NSCameraUsageDescription both platforms +
  macOS camera entitlement; camera-unavailable fallback points to paste.
  Real-camera verify on devices = part of 4.21/2.11 manual pass
- [x] 6.2 (R1.2) Remote-change notification: when a merge changes visible
  todos, post one local "List updated" notification via the existing
  AlarmScheduler abstraction; desktop obeys the notifications opt-in; batch
  per sync pass (no per-row spam); generated locally — never a push server
- [x] 6.3 (R1.1) Sync latency: targets table in docs/sync.md (LAN <6 s =
  5 s debounce + transfer; mailbox ≤ poll ∨ cloud-client lag); "last sync +
  cadence" status line in sync settings via `lastSyncPassProvider` (written
  by SyncService passes and Sync now). In-process LAN measurement is
  ms-scale/meaningless — real-network numbers folded into manual matrix
  (2.11/4.21)
- [x] 6.4 (R4.1) Tappable links: pure `lib/core/linkify.dart` (http/https
  only, trailing-punctuation + paren-balance trimming) + `LinkifiedText`
  widget in list tiles; editor shows open-link chips under notes (no read
  mode exists); url_launcher behind injectable `urlOpenerProvider`; Android
  manifest https VIEW query added
- [x] 6.5 (R4.2) Glanceable mode: `DisplayDensity` setting (standard/large,
  pref-seeded, settings switch); large = titleLarge tile type + 1.4× checkbox
  (Transform.scale grows the hit target too) + taller tiles. Kiosk extras
  (keep-screen-on, boot launch) stay in 6.38
- [x] 6.6 (R9.1) Theme override setting (system/light/dark):
  `themeModeProvider` (pref-seeded in main, persisted via settings dropdown)
  → MaterialApp.themeMode; pairing QR given explicit white background so it
  stays scannable in dark mode. On-device legibility check folds into 4.21
- [ ] 6.7 (R9.2) Minimalist audit: main list shows only user content — move
  any sync/debug affordances behind the app bar/menus (mostly true today;
  audit once 6.3's status line lands, keep it inside sync settings)
- [ ] 6.8 (R5.2) Calendar view: month/week screen from due dates, local only;
  day tap filters the list; reuse `todo_sections` date logic
- [x] 6.9 (R5.3) Recurrence UX gap closed: complete() on a recurring todo
  now advances dueAt to the next occurrence in place (CRDT-safe: concurrent
  completes converge via LWW; spawning rows would duplicate on merge);
  overdue completes jump past now, early completes skip the pending one,
  stale snooze cleared, malformed rules fall back to normal completion.
  "Duplicate yesterday's list" lives in 6.37 templates (which subsumes it)
- [ ] 6.10 (R1.4) Unattended viewer doc + audit: sync auto-resumes after
  restart (SyncBootstrap does), document Doze/iOS background-fetch limits
  honestly in docs/sync.md; verify no interaction needed post-reboot
- [ ] 6.11 (R14.6/R14.2, optional tail) Habit streaks; per-task focus timer
  with end notification (desktop behind alarms opt-in)
- [ ] 6.12 Licensing follow-up (deferred 2026-07-06): the MIT → Knot Source
  Available 1.0 relicense (commits c8cb74a/ef55a29) landed without an ADR —
  write docs/decisions/000X-license.md making the final call; reconcile the
  no-redistribution terms with Flathub submission (4.6) and the
  winget/Flathub auto-update plan (4.8); revisit R12.1 "free-with-privacy"
  positioning and store-listing wording accordingly

### Wave 2 — full triage of expanded REQUIREMENTS.md (R1–R17, 2026-07-06)

**P1 — core usability**

- [ ] 6.13 (R3.1) Subtasks/checklists: `parentId` column (schema migration),
  repository support, editor checklist UI; sub-items are ordinary CRDT rows
  with per-field HLC; unit + widget tests
- [ ] 6.14 (R2.2) Global quick capture: desktop global-hotkey quick-add
  window; Android long-press app shortcut + iOS Home-screen quick action
  straight into quick add (widgets themselves = 6.24)
- [x] 6.15 (R13.3) Inbox: modeled as `listId == null` (deliberately not a
  synced list row — per-device auto-created "Inbox" rows would duplicate on
  merge); drawer Inbox view (`kInboxFilter` sentinel, `watchActive
  unfiledOnly`), quick-add already lands there, tile popup-menu move-to-list
  triage, editor "No list" renamed Inbox
- [x] 6.16 (R13.1) No-shame overdue: Overdue section folded into Today
  (oldest first); tiles show subtle `overdueLabel` tag ("since Tue" <7 days,
  "since Jun 12" beyond, same-day lateness untagged); no red anywhere
- [x] 6.17 (R11.1) Human-readable export: `exportMarkdown` (lists as
  headings, Inbox first, notes indented, tombstones excluded) +
  `exportTodoTxt` (spec-compliant: x/priority/due:/rec:/+List/@tag; notes
  dropped, BYDAY rules omit rec: rather than lie) in ExportService; settings
  export tile now offers a format picker. One-way — restore stays JSON-only
- [ ] 6.18 (R13.9) Zero-config gate: add to docs/testing.md release
  checklist — first launch is one plain usable list; every R13–R15 feature
  ships opt-in

**P2 — differentiators**

- [ ] 6.19 (R3.2) Sections within a list (schema + drag between sections)
- [ ] 6.20 (R3.6) Manual drag-to-reorder with a CRDT-safe fractional order
  key (never integer indexes); merge property tests for concurrent reorders
- [ ] 6.21 (R3.7) Saved filters / smart lists: list+label+priority+date
  queries persisted as user views, local-only computation
- [ ] 6.22 (R3.9) Completed archive: browseable per-list history screen
  beyond the current Completed expansion tile
- [ ] 6.23 (R4.3) Undo snackbars for complete/delete/edit
- [ ] 6.24 (R8.1) Home-screen widgets (Android + iOS): today list,
  interactive check-off where the OS allows, quick-add button
- [ ] 6.25 (R2.3) Share-sheet capture target (Android/iOS/macOS): shared
  text/URL becomes a task (title + notes)
- [x] 6.26 (R2.5) Multi-line paste into quick add → "create one task per
  line" prompt
- [ ] 6.27 (R1.5) Sync health panel: extend 6.3's status line with transport
  in use + pending-outbound count, kept inside sync settings (6.7 audit)
- [ ] 6.28 (R7.1) Per-list sharing: ADR + docs/sync.md design first (per-list
  group keys, scoped changesets), then implementation — crypto/protocol
  change, own session(s)
- [ ] 6.29 (R13.2) Bulk reschedule ("overdue amnesty"): sweep overdue to
  today/tomorrow/Someday as a gentle periodic prompt
- [ ] 6.30 (R13.4) Someday/Maybe parking area excluded from Today/Upcoming
  and all counts (extend the existing Someday section semantics)
- [ ] 6.31 (R13.5) Stale-task review: surface tasks untouched N weeks with
  reschedule / Someday / delete exits
- [ ] 6.32 (R13.6) Guided weekly review flow (process Inbox → scan lists →
  review Someday); optional, skippable, never nags by default
- [x] 6.33 (R13.7) Completion recap: "done today/this week" view (grouped
  Today / Earlier this week / Older with a count summary). The optional
  end-of-day shutdown ritual (rolling leftovers deliberately) is deferred as
  its own follow-up.
- [ ] 6.34 (R14.1) "Top 3" pinned must-dos above everything in Today
- [ ] 6.35 (R14.3) Time-estimate + energy metadata; "I have 10 minutes"
  quick-win filter
- [ ] 6.36 (R14.5) Task-breakdown helper: one-tap multi-line split onto 6.13
  subtasks + reusable breakdown templates (local only, no AI) — depends 6.13
- [ ] 6.37 (R15.1) Checklist templates: save list/task+subtasks as template,
  instantiate with checked-state reset (subsumes 6.9's "duplicate yesterday")
- [ ] 6.38 (R16.1) Kiosk mode, extends 6.5: keep-screen-on while charging,
  Android boot auto-launch, burn-in-safe dimming + clock header
- [ ] 6.39 (R16.2) Old-hardware floor: verify on ~2 GB-RAM Android / oldest
  supported OS; document minimum versions in README
- [x] 6.40 (R11.2) Import: todo.txt, CSV, Todoist/TickTick export formats;
  imports stamp fresh HLCs (same pattern as 5.3 restore)
- [x] 6.41 (R11.3) Encrypted local backup/restore file; document "mailbox is
  a transport, not a backup" in docs/sync.md
- [ ] 6.42 (R12.4) Perf budgets: cold start <2 s, quick-add <500 ms, 5k-task
  scroll without jank — measure (extends 5.7), automate what CI can hold

**Cloud provider accounts — iPhone-first (user direction 2026-07-07, ADR 0003)**

- [x] 7.1 `MailboxStore` seam: mailbox protocol over any file store;
  `FolderMailboxStore` keeps the original behavior
- [x] 7.2 OAuth 2.0 + PKCE (`lib/data/cloud/oauth.dart`): no SDKs, no client
  secret; tokens in the keychain; injectable HTTP + clock
- [x] 7.3 Provider mailbox stores: Dropbox app folder, Google Drive
  `appDataFolder`, OneDrive Graph approot (narrowest scopes each)
- [x] 7.4 Solo-device sync: configured mailbox creates the group key without
  pairing; later pairing shares it (buildOrchestrator gate change)
- [x] 7.5 Connect screen (Settings → Cloud storage): iCloud Drive +
  three OAuth providers, connect/disconnect, setup-required states,
  "Your data" source overview (iPhone / cloud / peers)
- [x] 7.6 First-launch onboarding sheet ("Just this iPhone" / "Also in my
  cloud") — optional, never a wall (invariant 1)
- [x] 7.7 iOS plumbing: `knot://` URL scheme, AppDelegate redirect →
  `OAuthCallbackChannel`; verified app boots + onboarding on iPhone 17 Pro
  simulator
- [ ] 7.8 Register the three provider apps (free; docs/cloud-providers.md),
  inject `KNOT_*_CLIENT_ID` dart-defines, verify OAuth end-to-end on a
  simulator/device — **blocked on user accounts**
- [ ] 7.9 Account label on the connect screen (fetch display name/email from
  the provider after connect)
- [ ] 7.10 Android/desktop parity for the OAuth redirect (intent filter /
  loopback listener) — iPhone-first for now

**Phase 8 — Sharing groups & multi-cloud (user direction 2026-07-08,
ADR 0004; subsumes 6.28).** Target UX: lists live *Local* by default;
"Family" list shared with wife over an iCloud folder; "Friends" list
shared with a non-Apple friend over Dropbox — all three side by side in
one app. A device can hold many groups, each with its own backend,
per-group key, mailbox, and cursors; joining a group via QR invite makes
you a peer of someone else's storage without sharing credentials.

- [x] 8.1 Design: ADR 0004 (groups = backend + key + members + lists;
  local-by-default; scoped changesets; invite/join; per-group rotation;
  incremental Dropbox consent; UI blueprint) + docs/sync.md update
- [x] 8.2 (issue #94) Schema v4: `sync_groups` (+ device-local
  `local_account_ref`, never synced), `group_members` with deterministic
  `<groupId>:<deviceId>` row ids, `todo_lists.groupId` nullable FK (null =
  local-only default), per-group `sync_log` cursor keys
  (`group:<gid>:mailbox:<peer>` via `MailboxTransport.groupId`),
  generalized FK row-springing in `LwwApplier`, `GroupRepository` +
  `ListRepository.setGroup`, v3→v4 migration; 13 new tests
- [x] 8.3 (issue #95) Scoped changesets: `changesFor(vector, {groupId})`
  filters to the group's lists/todos/row/memberships/member devices;
  `setGroup` re-stamps the list + its todos with one fresh HLC so rows
  *entering* a scope always outrun published vector markers (that is the
  snapshot-republish-on-move mechanism); group transports publish scoped;
  per-scope convergence gate + move-in/move-out/leak tests
- [x] 8.4 (issue #96) Multi-account `CloudAccountService`: accounts
  registry in the keychain, per-account secret namespacing
  (`cloud_tokens:<id>`/`cloud_webdav:<id>`), same-provider coexistence,
  per-account refresh, legacy single-account migration (no re-auth),
  `removeAccount` guarded by `sync_groups.local_account_ref`, primary
  account = personal mailbox (back-compat), accounts section on the
  connect screen
- [ ] 8.5 Per-group keys + invites: group key creation/storage/rotation
  per group; invite QR payload `{groupId, name, groupKey, backend hint}`
  over the existing X25519 pairing handshake; join flow wiring
- [ ] 8.6 Multi-mailbox orchestrator: one `MailboxTransport` per
  configured group per pass (own store/key/cursors); per-group
  `SyncReport` + sync-health rows; soft-fail isolation (one group's
  network error must not block the others)
- [ ] 8.7 Shared-folder backends: Dropbox shared-folder mode behind
  incremental consent (broader scopes requested only when creating or
  joining a shared group; personal mailbox keeps the app folder); iCloud
  `UICloudSharingController` via the cloud-folder channel with manual
  Files-app sharing as the documented fallback
- [ ] 8.8 UI — Sharing & storage screen (evolves the 7.5 connect screen):
  "Your groups" cards (Local first, then name + provider chip + member
  and list counts; invite / manage lists / leave), "New group" wizard
  (name → backend → sign-in/reuse account → pick lists → invite QR),
  "Join group" scan flow, accounts list
- [ ] 8.9 UI — drawer sections per group (people icon + provider glyph,
  shared-list badges) and a "Sync" selector in list creation/editor
  (`Local only` default / group names); move-list-between-groups flow
  with its "past members keep received history" copy
- [ ] 8.10 Cross-ecosystem validation matrix: Apple↔Apple over a shared
  iCloud folder; Apple↔non-Apple over a shared Dropbox folder; solo
  local-only regression — extend the simulated-device convergence
  harness with per-group scopes before touching real devices
- [x] 8.11 WebDAV mailbox backend (issue #107, PR #108) — zero registration:
  server URL + username/app-password (Basic auth over TLS, keychain),
  `WebDavMailboxStore` via PROPFIND/GET/PUT/DELETE/MKCOL over the
  existing `CloudHttp`; connect form instead of a browser hop; the only
  backend verifiable end-to-end with no external accounts.
  **Priority (user decision 2026-07-08): iCloud + WebDAV first; the
  OAuth provider registrations (7.8/#103) come after the iPhone app is
  ready.**

**Alarms-phase additions (execute with Phase 2, per execution order)**

- [ ] 6.43 (R6.2) Snooze presets on the notification (10 min / 1 h / this
  evening / tomorrow) — extends 2.8's fixed 10 min
- [ ] 6.44 (R6.3) Nag/escalating reminders: per-task "repeat every N minutes
  until done", local scheduling only

**P3 — optional tail (one line each; expand into subtasks when picked up)**

- [x] 6.45 (R1.6) Syncthing-tolerant mailbox: audit format for third-party
  folder replication (conflicted-copy filenames), document in docs/sync.md
- [ ] 6.46 (R2.4) Voice input via platform speech APIs (on-device only)
- [x] 6.47 (R3.8) Attachments — design doc first (size caps, lazy fetch in
  encrypted mailbox), implementation only after sign-off
  — design landed as `docs/decisions/0002-attachments.md`; implementation
  (schema + BlobStore + mailbox/LAN blob transport + UI) is the follow-up
  tail, gated on sign-off
- [ ] 6.48 (R4.4) Configurable swipe actions (complete/snooze/delete)
- [ ] 6.49 (R5.5/R5.6) Kanban board (sections as columns) + Eisenhower view
- [ ] 6.50 (R6.4/R6.5) Location reminders (on-device geofencing only) +
  Android sticky today-notification
- [ ] 6.51 (R7.2/R7.3) Assignee chip on shared-list tasks + "changed by
  <device>" attribution from HLC metadata (feeds 6.2 notification text)
- [ ] 6.52 (R8.2/R8.3/R8.4) iOS lock-screen widget; Siri Shortcuts / Android
  App Actions; desktop tray quick-add + today count (ties into 5.1/5.2)
- [ ] 6.53 (R9.3) Theming: accent color + per-list colors/icons
- [ ] 6.54 (R13.8) Celebration feedback: check-off animation/haptics,
  Today-cleared moment, easy off switch
- [ ] 6.55 (R14.4) Realistic-day meter: sum of Today's estimates vs. hours
  left, gentle over-commitment hint — depends 6.35
- [ ] 6.56 (R15.2/R15.3) Frequency-based chores (due N days after last
  completion, injected clock) + chore rotation among paired people
- [ ] 6.57 (R17.1/R17.2) Simple mode preset (extra-large, high contrast,
  list+check only) + caregiver setup guide (per-list share + nag reminders);
  "not a medical device" wording in store listings

## Testing (cross-cutting — details in docs/testing.md)

- [x] T.1 Unit test suites wired into CI from Phase 0 (HLC, repositories, recurrence, merge)
- [x] T.2 Widget tests for every screen as it's built
- [x] T.3 Property-based convergence harness (Phase 3 gate: no release with a failing convergence property)
- [x] T.4 Multi-device sync simulator (in-process fake transports; runs in CI)
- [x] T.5 integration_test smoke suite per platform in CI (launch, add todo, complete, restart-persists)
- [x] T.6 Timezone/DST regression suite
- [x] T.7 Manual test matrix doc per release: alarms, pairing, permission flows per platform
- [x] T.8 Coverage floor: 80% on data/sync layers, enforced in CI
