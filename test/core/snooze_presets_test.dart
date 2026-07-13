import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/snooze_presets.dart';

void main() {
  group('resolveSnoozeUntil (TASKS.md 6.43)', () {
    test('10 min / 1 hour are simple offsets from now', () {
      final now = DateTime(2026, 7, 5, 9, 0);
      expect(
        resolveSnoozeUntil(SnoozePreset.tenMinutes, now),
        DateTime(2026, 7, 5, 9, 10),
      );
      expect(
        resolveSnoozeUntil(SnoozePreset.oneHour, now),
        DateTime(2026, 7, 5, 10, 0),
      );
    });

    test('this evening rings today when the hour is still ahead', () {
      final now = DateTime(2026, 7, 5, 9, 0);
      expect(
        resolveSnoozeUntil(SnoozePreset.thisEvening, now),
        DateTime(2026, 7, 5, kThisEveningHour),
      );
    });

    test('this evening rolls to tomorrow once the hour has passed', () {
      final now = DateTime(2026, 7, 5, 20, 0); // 8pm, past the evening hour
      expect(
        resolveSnoozeUntil(SnoozePreset.thisEvening, now),
        DateTime(2026, 7, 6, kThisEveningHour),
      );
    });

    test('this evening at exactly the hour rolls to tomorrow (never a '
        'past-or-now result)', () {
      final now = DateTime(2026, 7, 5, kThisEveningHour);
      expect(
        resolveSnoozeUntil(SnoozePreset.thisEvening, now),
        DateTime(2026, 7, 6, kThisEveningHour),
      );
    });

    test('tomorrow always lands the next calendar day at the fixed hour', () {
      final morning = DateTime(2026, 7, 5, 6, 0);
      final night = DateTime(2026, 7, 5, 23, 0);
      expect(
        resolveSnoozeUntil(SnoozePreset.tomorrow, morning),
        DateTime(2026, 7, 6, kTomorrowHour),
      );
      expect(
        resolveSnoozeUntil(SnoozePreset.tomorrow, night),
        DateTime(2026, 7, 6, kTomorrowHour),
      );
    });
  });

  group('SnoozePreset.fromActionId', () {
    test('round-trips every preset', () {
      for (final preset in SnoozePreset.values) {
        expect(SnoozePreset.fromActionId(preset.actionId), preset);
      }
    });

    test('unknown action id resolves to null (treated as dismiss)', () {
      expect(SnoozePreset.fromActionId('dismiss'), isNull);
      expect(SnoozePreset.fromActionId('bogus'), isNull);
    });

    test('legacy pre-6.43 "snooze" id maps to the 10-minute preset', () {
      // Notifications scheduled by the previous app version can outlive
      // the update; their snooze button must keep snoozing, not dismiss.
      expect(SnoozePreset.fromActionId('snooze'), SnoozePreset.tenMinutes);
    });
  });
}
