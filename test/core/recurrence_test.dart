import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/recurrence.dart';

void main() {
  DateTime utc(int y, int m, int d, [int h = 9, int min = 0]) =>
      DateTime.utc(y, m, d, h, min);

  /// Expands the series from [anchor], returning [count] occurrences.
  List<DateTime> series(Recurrence r, DateTime anchor, int count) {
    final out = <DateTime>[];
    var cursor = anchor.subtract(const Duration(days: 1));
    for (var i = 0; i < count; i++) {
      cursor = r.nextAfter(cursor, anchor: anchor);
      out.add(cursor);
    }
    return out;
  }

  group('parse/encode', () {
    test('roundtrips', () {
      for (final rule in [
        'FREQ=DAILY',
        'FREQ=DAILY;INTERVAL=3',
        'FREQ=WEEKLY;BYDAY=MO,WE,FR',
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=SA,SU',
        'FREQ=MONTHLY',
        'FREQ=YEARLY',
      ]) {
        expect(Recurrence.parse(rule).encode(), rule);
      }
    });

    test('rejects garbage', () {
      expect(() => Recurrence.parse(''), throwsFormatException);
      expect(() => Recurrence.parse('FREQ=HOURLY'), throwsFormatException);
      expect(() => Recurrence.parse('INTERVAL=2'), throwsFormatException);
      expect(
        () => Recurrence.parse('FREQ=DAILY;INTERVAL=0'),
        throwsFormatException,
      );
      expect(
        () => Recurrence.parse('FREQ=DAILY;BYDAY=MO'),
        throwsFormatException,
      );
      expect(
        () => Recurrence.parse('FREQ=WEEKLY;BYDAY=XX'),
        throwsFormatException,
      );
      expect(
        () => Recurrence.parse('FREQ=DAILY;UNTIL=20260101'),
        throwsFormatException,
      );
    });
  });

  group('daily', () {
    final rule = Recurrence.parse('FREQ=DAILY');

    test('series starts at anchor and steps one day', () {
      expect(series(rule, utc(2026, 7, 5), 3), [
        utc(2026, 7, 5),
        utc(2026, 7, 6),
        utc(2026, 7, 7),
      ]);
    });

    test('same-day earlier time returns that day; later time returns next', () {
      final anchor = utc(2026, 7, 5); // 09:00
      expect(
        rule.nextAfter(utc(2026, 7, 6, 8), anchor: anchor),
        utc(2026, 7, 6),
      );
      expect(
        rule.nextAfter(utc(2026, 7, 6, 10), anchor: anchor),
        utc(2026, 7, 7),
      );
    });

    test('interval 3 with far-future after jumps correctly', () {
      final rule3 = Recurrence.parse('FREQ=DAILY;INTERVAL=3');
      final anchor = utc(2020, 1, 1);
      final next = rule3.nextAfter(utc(2026, 7, 5), anchor: anchor);
      expect(next.difference(anchor).inDays % 3, 0);
      expect(next.isAfter(utc(2026, 7, 5)), isTrue);
      expect(next.difference(utc(2026, 7, 5)).inDays, lessThanOrEqualTo(3));
    });
  });

  group('weekly', () {
    test('BYDAY walks the mask within and across weeks', () {
      final rule = Recurrence.parse('FREQ=WEEKLY;BYDAY=MO,WE');
      // Anchor Mon 2026-07-06.
      expect(series(rule, utc(2026, 7, 6), 4), [
        utc(2026, 7, 6), // Mon
        utc(2026, 7, 8), // Wed
        utc(2026, 7, 13), // Mon next week
        utc(2026, 7, 15), // Wed
      ]);
    });

    test('no BYDAY uses anchor weekday', () {
      final rule = Recurrence.parse('FREQ=WEEKLY');
      expect(series(rule, utc(2026, 7, 7), 2), [
        utc(2026, 7, 7), // Tue
        utc(2026, 7, 14), // next Tue
      ]);
    });

    test('INTERVAL=2 skips alternate weeks from the anchor week', () {
      final rule = Recurrence.parse('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO');
      expect(series(rule, utc(2026, 7, 6), 3), [
        utc(2026, 7, 6),
        utc(2026, 7, 20),
        utc(2026, 8, 3),
      ]);
    });

    test('never yields an occurrence before the anchor', () {
      // Anchor Wed 2026-07-08 with BYDAY=MO: Mon 07-06 is in the anchor
      // week but precedes the anchor.
      final rule = Recurrence.parse('FREQ=WEEKLY;BYDAY=MO,WE');
      final first = rule.nextAfter(utc(2020, 1, 1), anchor: utc(2026, 7, 8));
      expect(first, utc(2026, 7, 8));
    });
  });

  group('monthly', () {
    test('same day each month', () {
      final rule = Recurrence.parse('FREQ=MONTHLY');
      expect(series(rule, utc(2026, 1, 15), 3), [
        utc(2026, 1, 15),
        utc(2026, 2, 15),
        utc(2026, 3, 15),
      ]);
    });

    test('day 31 skips short months (RFC 5545)', () {
      final rule = Recurrence.parse('FREQ=MONTHLY');
      expect(series(rule, utc(2026, 1, 31), 4), [
        utc(2026, 1, 31),
        utc(2026, 3, 31), // Feb skipped
        utc(2026, 5, 31), // Apr skipped
        utc(2026, 7, 31), // Jun skipped
      ]);
    });

    test('INTERVAL=2 counts skipped months against the interval', () {
      final rule = Recurrence.parse('FREQ=MONTHLY;INTERVAL=2');
      // Anchor Jan 31, every 2 months: Mar 31, May 31, Jul 31...
      expect(series(rule, utc(2026, 1, 31), 3), [
        utc(2026, 1, 31),
        utc(2026, 3, 31),
        utc(2026, 5, 31),
      ]);
    });

    test('day 30 skips only February', () {
      final rule = Recurrence.parse('FREQ=MONTHLY');
      expect(series(rule, utc(2026, 1, 30), 3), [
        utc(2026, 1, 30),
        utc(2026, 3, 30),
        utc(2026, 4, 30),
      ]);
    });
  });

  group('yearly', () {
    test('same date each year', () {
      final rule = Recurrence.parse('FREQ=YEARLY');
      expect(series(rule, utc(2026, 7, 5), 2), [
        utc(2026, 7, 5),
        utc(2027, 7, 5),
      ]);
    });

    test('Feb 29 fires only in leap years', () {
      final rule = Recurrence.parse('FREQ=YEARLY');
      expect(series(rule, utc(2024, 2, 29), 3), [
        utc(2024, 2, 29),
        utc(2028, 2, 29),
        utc(2032, 2, 29),
      ]);
    });
  });

  test('time of day is preserved from the anchor', () {
    final rule = Recurrence.parse('FREQ=DAILY');
    final next = rule.nextAfter(
      utc(2026, 7, 6, 23, 59),
      anchor: DateTime.utc(2026, 7, 5, 17, 45),
    );
    expect(next, DateTime.utc(2026, 7, 7, 17, 45));
  });

  group('completion-anchored chores (6.56)', () {
    test('defaults to a schedule anchor', () {
      expect(Recurrence.parse('FREQ=DAILY').anchor, RecurrenceAnchor.schedule);
    });

    test('parse/encode round-trips the ANCHOR extension', () {
      final r = Recurrence.parse('FREQ=DAILY;INTERVAL=3;ANCHOR=COMPLETION');
      expect(r.anchor, RecurrenceAnchor.completion);
      expect(r.interval, 3);
      expect(r.encode(), 'FREQ=DAILY;INTERVAL=3;ANCHOR=COMPLETION');
    });

    test('rejects an unknown ANCHOR value', () {
      expect(
        () => Recurrence.parse('FREQ=DAILY;ANCHOR=WHENEVER'),
        throwsFormatException,
      );
    });

    test('daily chore: N days after completion, at the anchor time', () {
      final r = Recurrence.parse('FREQ=DAILY;INTERVAL=3;ANCHOR=COMPLETION');
      // Completed late in the day; next due is 3 days on at the anchor's 09:00.
      final next = r.nextFromCompletion(
        utc(2026, 7, 6, 20, 30),
        anchor: utc(2026, 7, 1, 9, 0),
      );
      expect(next, utc(2026, 7, 9, 9, 0));
    });

    test('weekly chore steps whole weeks from completion', () {
      final r = Recurrence.parse('FREQ=WEEKLY;INTERVAL=2;ANCHOR=COMPLETION');
      expect(
        r.nextFromCompletion(utc(2026, 7, 6), anchor: utc(2026, 6, 1, 8, 0)),
        utc(2026, 7, 20, 8, 0),
      );
    });

    test('monthly chore clamps a too-large day to month end', () {
      final r = Recurrence.parse('FREQ=MONTHLY;ANCHOR=COMPLETION');
      // Completed Jan 31 → Feb has no 31st, clamp to Feb 28 (2026 not leap).
      expect(
        r.nextFromCompletion(utc(2026, 1, 31), anchor: utc(2026, 1, 1, 7, 0)),
        utc(2026, 2, 28, 7, 0),
      );
    });

    test('yearly chore clamps Feb 29 to Feb 28 in a non-leap year', () {
      final r = Recurrence.parse('FREQ=YEARLY;ANCHOR=COMPLETION');
      expect(
        r.nextFromCompletion(utc(2028, 2, 29), anchor: utc(2028, 2, 29, 6, 0)),
        utc(2029, 2, 28, 6, 0),
      );
    });
  });
}
