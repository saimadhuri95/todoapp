# REQUIREMENTS.md — user-sourced feature requirements

Requirements gathered 2026-07-06 from online user requests, app-comparison
research (Todoist, TickTick, Things 3, Microsoft To Do, Any.do, Super
Productivity, Joplin, Due, Taskito), Reddit/forum wish-lists, and a real-world
multi-device use case (dispatcher → driver with a dashboard-mounted phone).
Sources are listed at the bottom.

Every requirement must respect the non-negotiable invariants in CLAUDE.md — in
particular **no central server, ever**: "real-time" means best-effort push over
the existing LAN P2P and encrypted cloud-mailbox transports; "sharing" means
device pairing, never accounts; notifications are generated locally on the
receiving device, never pushed from a relay.

Status legend: ✅ already covered · 🔶 partially covered · 🆕 new requirement
Priority legend: **P1** core usability · **P2** strong differentiator ·
**P3** optional tail

## R1. Sync & multi-device

- **R1.1 🔶 P1 Near-real-time propagation.** Edits on one device appear on a
  paired device within seconds on the same LAN (mDNS+TCP push, not poll) and
  within one poll interval over the cloud mailbox. Define and document the
  target latency for each transport.
- **R1.2 🆕 P1 Change notification on receiving device.** When a sync merge
  changes the visible list (items added/edited/completed remotely), the
  receiving device shows a local notification ("List updated"), so a passive
  device (car phone, kitchen tablet) surfaces changes without being watched.
  Reuses the platform notification abstraction; desktop obeys the opt-in
  toggle. Generated locally at merge time — never from a server.
- **R1.3 ✅ Checkable items on every device.** Completion syncs everywhere
  (LWW-per-field CRDT already covers this).
- **R1.4 🆕 P1 Unattended viewer devices.** A device used only as a display
  keeps receiving updates with zero interaction: sync resumes after
  reboot/app restart without re-pairing and survives backgrounding within
  platform limits. Document Doze / iOS background-fetch limits honestly.
- **R1.5 🆕 P2 Sync health visibility.** A quiet per-device indicator (last
  successful sync time, transport in use, pending outbound changes) behind a
  menu — users of local-first apps consistently ask "did it actually sync?"
- **R1.6 🆕 P3 Syncthing-friendliness.** The cloud-mailbox folder format
  should work when the folder is replicated by third-party tools like
  Syncthing/Nextcloud/WebDAV-mounted dirs (no reliance on provider-specific
  APIs, tolerant of conflicted-copy filenames). This widens serverless
  transport options for free.

## R2. Capture & input

- **R2.1 ✅ P1 Natural-language quick add.** "pay rent tomorrow 5pm" — shipped
  (PR #7); keep extending recognized phrases as gaps are reported. Top-ranked
  capture feature across every comparison reviewed.
- **R2.2 🆕 P1 Global quick-capture entry points.** Desktop: global hotkey
  opens a minimal quick-add window. Mobile: home-screen widget button and app
  shortcut (long-press icon) straight into quick add. Capture friction is the
  #1 reason users abandon todo apps.
- **R2.3 🆕 P2 Share-sheet capture.** Register as a share target
  (Android/iOS/macOS): sharing text or a URL from any app creates a task with
  the shared content in title/notes.
- **R2.4 🆕 P3 Voice input.** Dictation into quick add via the platform speech
  APIs (on-device where available); no cloud speech service dependency.
- **R2.5 🆕 P2 Paste-to-multiple-tasks.** Pasting multi-line text into quick
  add offers "create one task per line" — repeatedly requested for moving
  lists out of notes apps.

## R3. Task model & organization

- **R3.1 🆕 P1 Subtasks / checklists.** At least one level of sub-items under
  a task, individually checkable, synced as ordinary CRDT rows with a parent
  reference. The single most-cited missing feature in user complaints.
- **R3.2 🆕 P1 Multiple lists/projects with sections.** User-created lists
  (Groceries, Work, Car-duties) with optional sections inside a list; tasks
  belong to exactly one list.
- **R3.3 🆕 P2 Tags/labels.** Free-form labels across lists; filter by label.
- **R3.4 🆕 P2 Priorities.** Small fixed set (e.g. P1–P4) with visual
  affordance and sort support.
- **R3.5 🆕 P2 Task notes/description.** A free-text notes field per task
  (plain text first; links auto-detected per R4.2).
- **R3.6 🆕 P2 Manual ordering + due-date sort.** Drag-to-reorder within a
  list, persisted and synced (order key must merge sanely under CRDT — use a
  fractional/ordered-key scheme, not integer indexes).
- **R3.7 🆕 P2 Saved filters / smart lists.** User-defined views combining
  list, label, priority, and date (e.g. "today + P1 across all lists").
  Todoist's "killer feature" for power users; entirely local computation.
- **R3.8 🆕 P3 Attachments.** Photos/files on a task. Must fit the encrypted
  mailbox (size caps, lazy fetch); design doc required before implementation.
- **R3.9 🆕 P2 Completed-tasks archive.** Browseable history of completed
  items per list (tombstone-friendly: completed ≠ deleted).

## R4. Content & interaction

- **R4.1 🆕 P1 Tappable links in item text.** URLs in title or notes are
  auto-detected, rendered as links, and open in the platform handler with one
  tap (a Google Maps link opens Maps). No markup required.
- **R4.2 🆕 P2 Glanceable mode.** A display-density option (or automatic
  landscape layout) with large checkboxes and text for a dashboard-mounted
  phone or wall tablet: readable at arm's length, tick-off with one imprecise
  tap, screen-on option while charging.
- **R4.3 🆕 P2 Undo.** Snackbar undo for complete/delete/edit — top usability
  complaint category ("I fat-fingered a task away").
- **R4.4 🆕 P3 Swipe gestures.** Configurable swipe actions on mobile
  (complete, snooze, delete) with sensible defaults.

## R5. Views & planning

- **R5.1 🆕 P1 Today / Upcoming views.** Cross-list "Today" and chronological
  "Upcoming" views — the cleanest mental model in the category (Things 3) and
  table stakes in every app compared.
- **R5.2 🆕 P2 Calendar view.** Built-in month/week view of dated tasks;
  tapping a day filters to it. Local rendering only.
- **R5.3 🆕 P1 Recurring tasks / daily list templates.** Repeating tasks
  ("every day", "every Monday", "every 3rd of the month") and a "duplicate
  yesterday's list" action. Recurrence expansion goes through the injected
  clock and produces CRDT-clean rows (each occurrence its own item; no
  mutation loops). Poor recurring-task support is a top complaint across apps.
- **R5.4 🆕 P1 Search.** Fast full-text search across titles and notes, fully
  offline (SQLite FTS).
- **R5.5 🆕 P3 Kanban/board view.** Optional column view per list (sections as
  columns). Only after core views ship.
- **R5.6 🆕 P3 Eisenhower matrix view.** Urgent/important quadrants derived
  from priority + due date (TickTick differentiator). Pure view; no schema
  change.

## R6. Reminders & alarms (executes in the alarms phase, per CLAUDE.md order)

- **R6.1 🔶 P1 Per-item alarms.** Already designed (docs/alarms.md); mobile
  default-on, desktop opt-in stays as decided.
- **R6.2 🆕 P1 Snooze from the notification.** Snooze presets (10 min, 1 h,
  this evening, tomorrow) directly on the notification actions.
- **R6.3 🆕 P2 Nag/escalating reminders.** Optional per-task "repeat every N
  minutes until done" (Due's signature feature; frequently requested for
  medication/critical tasks). Local scheduling only.
- **R6.4 🆕 P3 Location-based reminders.** "Remind me when arriving/leaving
  X" using on-device geofencing APIs only; no location data ever enters the
  sync payload unencrypted (it syncs like any other encrypted field).
- **R6.5 🆕 P3 Persistent/sticky notification.** Optional pinned notification
  on Android showing today's remaining tasks.

## R7. Shared lists & collaboration (serverless)

- **R7.1 🆕 P2 Per-list sharing via pairing.** Sharing = pairing scoped to
  specific lists: QR-pair another person's device and grant it selected lists
  (Groceries with partner) rather than the whole database. The #1 use case in
  couples/family app roundups — and none of the compared apps do it without
  accounts; we can.
- **R7.2 🆕 P3 Assignment.** An "assigned device/person" field on tasks in
  shared lists, shown as a chip; purely informational (no enforcement).
- **R7.3 🆕 P3 Edit attribution.** "Changed by <device name>" on merge, using
  data already present in HLC metadata; surfaces in task history, feeds R1.2
  notification text.

## R8. Platform integration

- **R8.1 🆕 P2 Home-screen widgets.** Android + iOS widgets: today list with
  interactive check-off where the OS allows, plus a quick-add button.
- **R8.2 🆕 P3 Lock-screen widgets / complications.** iOS lock-screen widget;
  watch support explicitly deferred (new build targets, high cost).
- **R8.3 🆕 P3 System shortcuts/intents.** Siri Shortcuts / Android App
  Actions for "add task" and "show today".
- **R8.4 🆕 P3 Desktop tray/menu-bar quick access.** Tray icon with today
  count and quick add (aligns with existing Linux tray tasks 5.1/5.2).

## R9. Appearance & UX

- **R9.1 🔶 P1 Light and dark mode.** Follow system by default, manual
  override in settings; verify every screen (QR pairing included) in both.
- **R9.2 🆕 P1 Minimalist default UI.** Any.do-style: the default list view
  stays visually clean; power features (sync status, filters, debug) live
  behind menus.
- **R9.3 🆕 P3 Theming.** Accent color choice and per-list colors/icons.

## R10. Accessibility (P1 as a block — cheap now, expensive later)

- **R10.1 🆕 Screen-reader support.** Semantic labels on all interactive
  elements (Flutter Semantics); check-off, edit, and delete reachable and
  announced with VoiceOver/TalkBack. Delete/complete must not be
  hover-or-swipe-only anywhere.
- **R10.2 🆕 Full keyboard operation on desktop.** Add, navigate, complete,
  edit, reorder without a mouse; shortcuts documented and discoverable.
- **R10.3 🆕 Touch-target & contrast floors.** ≥48dp touch targets, WCAG AA
  contrast in both themes, honor system font-scaling without clipped layouts.

## R11. Data portability & trust

- **R11.1 🆕 P1 Export.** One-tap export of all data to JSON (lossless) and
  Markdown/todo.txt (human-readable). "Can I get my data out?" is the
  recurring trust question in local-first communities; we have no excuse not
  to answer yes.
- **R11.2 🆕 P2 Import.** Import from todo.txt, CSV, and Todoist/TickTick
  export formats (migration path = adoption path).
- **R11.3 🆕 P2 Local backup/restore.** Manual encrypted backup file +
  restore; document that the cloud mailbox is a transport, not a backup.
- **R11.4 🆕 P3 Automatic periodic local backup.** Rolling local snapshots
  with retention cap.

## R12. Positioning (non-functional)

- **R12.1 ✅ 100% free, no account, no subscription, MIT.** Inherent to the
  design; no feature may add a paid dependency or mandatory sign-in. Every
  compared competitor gates core features (recurring tasks, reminders,
  calendar) behind $3–4/month — free-with-privacy is the positioning.
- **R12.2 ✅ All five platforms, one codebase.** Windows, macOS, Linux, iOS,
  Android; each requirement above must state per-platform behavior where
  platforms differ.
- **R12.3 ✅ Fully offline-capable.** Every feature works with sync never
  configured (invariant #1). New features must be spec'd offline-first.
- **R12.4 🆕 P2 Performance floors.** Cold start to interactive list < 2 s on
  mid-range mobile; quick-add ready < 500 ms from hotkey/widget; lists with
  5k+ tasks scroll without jank (virtualized lists, indexed queries).

## Out of scope (would violate invariants or the project premise)

- Hosted real-time relay, push-notification server, or "just a small
  signaling server" (breaks no-central-server). Remote-change notifications
  (R1.2) are generated locally when a merge lands.
- Accounts of any kind; Microsoft 365 / Google / third-party identity
  integrations. Cloud drives remain dumb encrypted mailboxes only.
- Team/workspace features (comments threads, per-user permissions, admin
  roles) — this is a personal/household app, not Asana.
- AI features requiring cloud inference.
- Email-in / calendar-service two-way sync (needs a server endpoint).

## Sources

- [Zapier — 7 best to do list apps of 2026](https://zapier.com/blog/best-todo-list-apps/)
- [TheSoftwareScout — Best To-Do List Apps 2026 compared](https://thesoftwarescout.com/best-to-do-list-apps-2026/)
- [Unstar — Todoist vs TickTick vs Things 3 ranked (2026)](https://unstar.app/blog/todoist-ticktick-things-3-microsoft-todo-apple-reminders-todo-apps-ranked-2026)
- [TaskSpot — Todoist vs TickTick vs Microsoft To Do vs Google Tasks](https://www.taskspot.app/blog/todoist-vs-ticktick-vs-microsoft-to-do-vs-google-tasks)
- [Any.do — The 9 Best To-Do List Apps in 2026](https://www.any.do/blog/the-9-best-to-do-list-apps-in-2026-tested-and-compared/)
- [Super Productivity — Best Local-First To-Do Apps in 2026](https://super-productivity.com/blog/best-local-first-todo-apps-2026/)
- [Super Productivity — Private alternatives to Todoist/TickTick/Notion/MS To Do](https://super-productivity.com/blog/private-alternatives-todoist-ticktick-notion-microsoft-todo/)
- [How-To Geek — Syncing local-first apps without cloud services (Syncthing)](https://www.howtogeek.com/free-open-source-tool-solves-the-main-problem-with-local-first-apps/)
- [Todoist — Features](https://www.todoist.com/features)
- [Todoist — Introduction to reminders](https://www.todoist.com/help/articles/introduction-to-reminders-9PezfU)
- [Todoist — Location reminders](https://www.todoist.com/help/articles/use-location-reminders-in-todoist-uGcwH2AJ6)
- [Taskito — 4 must-have notification features in a to-do app](https://taskito.io/blog/4-must-have-notification-features-todo-list-app/)
- [GTD Forums — Cross-platform task list with escalating reminders](https://forum.gettingthingsdone.com/threads/cross-platform-task-list-with-escalating-reminders.17895/)
- [Any.do — Best shared to-do list app for families & couples in 2026](https://www.any.do/blog/the-best-shared-to-do-list-app-for-families-couples-in-2026/)
- [Cupla — 11 best shared to-do list apps for couples](https://cupla.app/blog/11-best-shared-to-do-list-apps-for-couples-in-2025-that-actually-work/)
- [Todoist — Collaborate with friends or family](https://www.todoist.com/help/articles/collaborate-with-friends-or-family-in-todoist-tzkGUy)
- [Inclusive Components — A Todo List (accessibility patterns)](https://inclusive-components.design/a-todo-list/)
- [Material Design — Accessibility](https://m2.material.io/design/usability/accessibility.html)
- [Android Developers — Test your app's accessibility](https://developer.android.com/guide/topics/ui/accessibility/testing)
- [daily.dev — I tried every todo app and ended up with a .txt file](https://daily.dev/posts/i-tried-every-todo-app-and-ended-up-with-a-txt-file-phgmruiea)
- [todo.txt-style formats — matthewpalmer/.todo](https://github.com/matthewpalmer/.todo)
- [Toodledo — Import/export tools (CSV/XML/JSON)](https://www.toodledo.com/tools/import_export.php)
- [Todoist — Apple Watch](https://www.todoist.com/help/articles/use-todoist-on-apple-watch-vTvnTJFz) / [Wear OS](https://www.todoist.com/help/articles/use-todoist-on-wear-os-t8tzJ0mO)
- [Todoist — Widgets on Apple devices](https://www.todoist.com/help/articles/use-a-todoist-widget-on-an-apple-device-ptRdme)
