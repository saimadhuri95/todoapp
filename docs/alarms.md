# Alarms

## Implementation model (revised 2026-07-06)

Alarms are **LWW fields on the todo row** (schema v3), not separate tables:
`alarmOffsetsJson` (minute-offsets before the due time), `lastDismissedMs`,
`snoozeUntilMs`. This makes dismissal/snooze ordinary synced field writes —
no FK headaches in the CRDT, no extra changeset types. The pure
`planAlarms()` expands recurrences and emits the next ≤50 concrete fire
times; `AlarmService` replans on any todos change (local or synced) and the
platform scheduler replaces its whole schedule. The original todo_alarms /
alarm_dismissals tables are unused.

## Policy

- Alarms fire on every device where alarms are **enabled**.
- Mobile (Android/iOS): enabled by default.
- Desktop (Windows/macOS): **opt-in** via Settings → "Enable alarms on this
  device" (default off). Enabling triggers the OS permission flow; disabling
  cancels everything scheduled with the OS.
- Linux: last item within the alarms phase. Until then, in-app reminders only
  while the app window is open.
- The entire alarms phase executes last-but-one (after sync and packaging) —
  see "Execution order" in TASKS.md.
- Dismissing/snoozing an alarm on one device writes an `AlarmDismissal` record
  that syncs; other devices cancel their matching scheduled notification.
  Caveat: a closed desktop app can't receive the dismissal, so its pre-scheduled
  OS notification may still fire — acceptable for opt-in users; mitigated later
  by the "run in background at login" option (Phase 5).

## Per-platform mechanics

### Android
- `AlarmManager` exact alarms. Android 12+: request `SCHEDULE_EXACT_ALARM`
  (settings deep-link UX) or declare `USE_EXACT_ALARM` (alarm-app category).
- `BOOT_COMPLETED` receiver reschedules after reboot.
- Notification channel with alarm importance; full-screen intent optional later.

### iOS
- `UNUserNotificationCenter` with `UNCalendarNotificationTrigger`.
- **64 pending-notification cap**: schedule the nearest N (≈50, leaving head-
  room), refill on every foreground and via `BGAppRefreshTask`.
- Notification actions: Complete, Snooze 10m.

### Windows (opt-in)
- `ScheduledToastNotification` — delivered by the OS even when the app is
  closed. Requires MSIX package identity.
- `scenario="alarm"`: toast stays on screen, looping alarm audio, Snooze/Dismiss
  buttons. Activation launches/foregrounds the app.

### macOS (opt-in)
- `UNUserNotificationCenter` (same API family as iOS) — system-delivered when
  the app is closed. Use the same schedule-nearest-N + refill pattern.
- Limitation: sound plays once; no persistent ring while the app is closed
  (critical alerts need a special entitlement — not planned).

### Linux (Phase 5, opt-in)
- No OS-level scheduled-notification API; requires a resident process.
- Plan: background/tray process started at login (autostart entry; XDG
  Background portal under Flatpak) posting via libnotify/DBus.
- Fallback considered and rejected: cron (one-shot misfit, session-env problems,
  skips missed jobs, absent on some distros, Flatpak-hostile). systemd user
  timers (`systemd-run --user --on-calendar`, `Persistent=true`) are the viable
  non-resident fallback.

## Timezones & DST (v1 semantics)

Due times are stored as UTC epoch ms, but recurrence/alarm expansion runs
in **local calendar space**, so wall-clock times survive DST transitions in
the device's zone (verified by test/core/dst_test.dart, run under
`TZ=America/New_York` in CI). Known v1 limitation: devices in *different*
zones expand a recurring todo against their own wall clock, so their fire
instants (and dismissal occurrence keys) can diverge after a DST shift that
only one zone observes. Full wall-clock storage (local time + IANA zone id)
is the eventual fix; deferred until real users travel with it.

## Scheduling rules

- Alarms stored as local time + IANA zone id; recomputed when device zone
  changes. DST transitions covered by a dedicated test suite.
- Recurring todos: completing or dismissing an occurrence schedules the next.
- Editing/deleting a todo cancels and reschedules its OS notifications.
