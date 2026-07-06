# REQUIREMENTS.md — user-sourced feature requirements

Requirements gathered 2026-07-06 from online user requests and reviews of
comparable cross-platform todo apps (Todoist, TickTick, Microsoft To Do,
Any.do) plus a real-world multi-device use case (dispatcher → driver with a
dashboard-mounted phone). Each item is tagged with its status against the
current codebase and must respect the non-negotiable invariants in CLAUDE.md —
in particular **no central server**: "real-time" here means best-effort push
over the existing LAN P2P and cloud-mailbox transports, never a hosted relay.

Status legend: ✅ already covered · 🔶 partially covered · 🆕 new requirement

## R1. Sync & multi-device (from the driver/dispatcher scenario)

- **R1.1 🔶 Near-real-time propagation.** Edits made on one device should
  appear on a paired device within seconds when both are on the same LAN
  (mDNS+TCP push, not poll), and within one cloud-drive poll interval
  otherwise. Define and document the target latency for each transport.
- **R1.2 🆕 Change notification on receiving device.** When a sync merge
  changes the visible list (items added/edited/completed remotely), the
  receiving device shows a local notification ("List updated"), so a passive
  device (e.g. phone mounted in a car) surfaces changes without the user
  watching the screen. Must reuse the existing platform alarm/notification
  abstraction; desktop follows the opt-in notification toggle.
- **R1.3 ✅ Checkable items on every device.** Ticking an item on one device
  syncs the completion to all others (LWW-per-field CRDT already covers this).
- **R1.4 🆕 Asymmetric-use pairing works unattended.** A device that is only
  ever a *viewer* (car phone) must keep receiving updates with zero
  interaction: sync resumes after reboot/app restart without re-pairing, and
  survives the app being backgrounded on Android/iOS within platform limits.
  Document the platform limits (Doze, iOS background fetch) honestly.

## R2. Content & interaction

- **R2.1 🆕 Tappable links in item text.** URLs in a task's title or notes are
  auto-detected, rendered as links, and open in the platform browser/handler
  with one tap (e.g. a Google Maps link opens the Maps app). No markup
  required from the user.
- **R2.2 ✅ Natural-language quick add.** Todoist-style natural date entry
  ("pay rent tomorrow 5pm") — shipped in PR #7; keep extending recognized
  phrases as gaps are reported.
- **R2.3 🆕 Large-touch-target / glanceable mode.** A display density option
  (or automatic landscape layout) with bigger checkboxes and text suitable for
  a dashboard-mounted phone or wall tablet: readable at arm's length,
  tick-off with one imprecise tap.

## R3. Appearance

- **R3.1 🔶 Light and dark mode.** Both themes fully supported, following the
  system setting by default with a manual override in settings. Verify every
  screen (including QR pairing and settings) is legible in both.
- **R3.2 🆕 Minimalist default UI.** Any.do-style: the default list view stays
  visually clean — power features (sync status, HLC debug, filters) live
  behind menus, not on the main screen.

## R4. Planning features (from TickTick/Todoist power users)

- **R4.1 🆕 Calendar view.** A built-in month/week view showing tasks with due
  dates; tapping a day filters to that day's tasks. Local rendering only — no
  external calendar service required.
- **R4.2 🆕 Recurring tasks / daily list templates.** Support repeating tasks
  ("every day", "every Monday") and/or a "duplicate yesterday's list" action,
  so a dispatcher can stand up each morning's duty list quickly. Recurrence
  expansion must go through the injected clock provider and produce
  CRDT-clean rows (each occurrence is its own item; no mutation loops).
- **R4.3 🆕 (Optional tail) Habit tracker.** Streak-style tracking for
  recurring personal tasks. Low priority; only if R4.2 lands cleanly.
- **R4.4 🆕 (Optional tail) Pomodoro/focus timer.** Per-task focus timer with
  a local notification at the end of the interval. Desktop obeys the alarms
  opt-in toggle. Low priority.

## R5. Positioning (non-functional)

- **R5.1 ✅ 100% free, no account, no subscription.** Already inherent to the
  local-first, serverless design (MIT licensed). Keep it true: no feature may
  introduce a paid dependency or mandatory sign-in.
- **R5.2 ✅ All five platforms from one codebase.** Windows, macOS, Linux,
  iOS, Android — already the project premise; every requirement above must
  state its per-platform behavior where platforms differ.

## Out of scope (would violate invariants)

- Hosted real-time relay / push-notification server (breaks "no central
  server"). Remote-change notifications (R1.2) must be generated locally on
  the receiving device when a merge lands.
- Microsoft 365 / third-party account integrations that require a cloud
  identity. Cloud drives remain dumb encrypted mailboxes only.
