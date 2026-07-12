/// Snooze presets offered on the alarm notification (TASKS.md 6.43),
/// extending 2.8's fixed 10-minute snooze.
enum SnoozePreset {
  tenMinutes,
  oneHour,
  thisEvening,
  tomorrow;

  /// The action id encoded on the notification button/payload.
  String get actionId => switch (this) {
    SnoozePreset.tenMinutes => 'snooze_10m',
    SnoozePreset.oneHour => 'snooze_1h',
    SnoozePreset.thisEvening => 'snooze_evening',
    SnoozePreset.tomorrow => 'snooze_tomorrow',
  };

  String get label => switch (this) {
    SnoozePreset.tenMinutes => 'Snooze 10 min',
    SnoozePreset.oneHour => 'Snooze 1 hour',
    SnoozePreset.thisEvening => 'This evening',
    SnoozePreset.tomorrow => 'Tomorrow',
  };

  static SnoozePreset? fromActionId(String actionId) {
    for (final preset in SnoozePreset.values) {
      if (preset.actionId == actionId) return preset;
    }
    return null;
  }
}

/// "This evening" wall-clock hour: chosen to read as early evening on any
/// device without a settings knob for it (like "tomorrow" below).
const kThisEveningHour = 18;

/// "Tomorrow" wall-clock hour — a normal start-of-day snooze rather than a
/// literal 24h-from-now offset, which would drift with when the alarm rang.
const kTomorrowHour = 9;

/// Resolves [preset] against [now] to a concrete snooze-until moment. Local
/// wall-clock presets ("this evening"/"tomorrow") always land in the future:
/// if the target hour has already passed today, they roll forward a day.
DateTime resolveSnoozeUntil(SnoozePreset preset, DateTime now) {
  switch (preset) {
    case SnoozePreset.tenMinutes:
      return now.add(const Duration(minutes: 10));
    case SnoozePreset.oneHour:
      return now.add(const Duration(hours: 1));
    case SnoozePreset.thisEvening:
      final evening = DateTime(now.year, now.month, now.day, kThisEveningHour);
      return evening.isAfter(now)
          ? evening
          : evening.add(const Duration(days: 1));
    case SnoozePreset.tomorrow:
      return DateTime(now.year, now.month, now.day + 1, kTomorrowHour);
  }
}
