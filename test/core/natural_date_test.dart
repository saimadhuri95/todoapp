import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/natural_date.dart';

void main() {
  // A Monday, mid-afternoon.
  final now = DateTime(2026, 7, 6, 15, 30);

  QuickAddResult parse(String s) => parseQuickAdd(s, now);

  group('day words', () {
    test('today defaults to 09:00', () {
      final r = parse('pay rent today');
      expect(r.title, 'pay rent');
      expect(r.dueAt, DateTime(2026, 7, 6, 9));
    });

    test('tomorrow', () {
      final r = parse('call mom tomorrow');
      expect(r.title, 'call mom');
      expect(r.dueAt, DateTime(2026, 7, 7, 9));
    });

    test('tonight implies 20:00', () {
      final r = parse('take out trash tonight');
      expect(r.title, 'take out trash');
      expect(r.dueAt, DateTime(2026, 7, 6, 20));
    });

    test('explicit time overrides tonight hour', () {
      final r = parse('gym tonight at 9pm');
      expect(r.title, 'gym');
      expect(r.dueAt, DateTime(2026, 7, 6, 21));
    });

    test('case-insensitive', () {
      expect(parse('X Tomorrow').dueAt, DateTime(2026, 7, 7, 9));
    });
  });

  group('weekdays', () {
    test('bare weekday is soonest future occurrence', () {
      final r = parse('dentist friday'); // now is Monday
      expect(r.title, 'dentist');
      expect(r.dueAt, DateTime(2026, 7, 10, 9));
    });

    test('same weekday as today means a week ahead', () {
      expect(parse('standup monday').dueAt, DateTime(2026, 7, 13, 9));
    });

    test('next weekday adds a week', () {
      expect(parse('review next fri').dueAt, DateTime(2026, 7, 17, 9));
    });

    test('abbreviations', () {
      expect(parse('a tue').dueAt, DateTime(2026, 7, 7, 9));
      expect(parse('b thurs').dueAt, DateTime(2026, 7, 9, 9));
      expect(parse('c Wednesday').dueAt, DateTime(2026, 7, 8, 9));
    });

    test('weekday with time', () {
      expect(parse('lunch sat at 12:30').dueAt, DateTime(2026, 7, 11, 12, 30));
    });

    test('embedded weekday letters do not match', () {
      final r = parse('satisfy the monitor'); // "sat", "mon" inside words
      expect(r.dueAt, isNull);
      expect(r.title, 'satisfy the monitor');
    });
  });

  group('relative', () {
    test('in N days', () {
      expect(parse('x in 3 days').dueAt, DateTime(2026, 7, 9, 9));
    });

    test('in 1 week', () {
      expect(parse('x in 1 week').dueAt, DateTime(2026, 7, 13, 9));
    });

    test('in N hours keeps clock time', () {
      expect(parse('x in 2 hours').dueAt, DateTime(2026, 7, 6, 17, 30));
    });

    test('in N minutes', () {
      expect(parse('x in 90 minutes').dueAt, DateTime(2026, 7, 6, 17, 0));
    });

    test('in 1 month clamps the day', () {
      final r = parseQuickAdd('x in 1 month', DateTime(2026, 1, 31, 8));
      expect(r.dueAt, DateTime(2026, 2, 28, 9));
    });

    test('relative wins over a time phrase, which stays in the title', () {
      final r = parse('x in 2 hours at 5pm');
      expect(r.dueAt, DateTime(2026, 7, 6, 17, 30));
      expect(r.title, 'x at 5pm');
    });

    test('an absurd offset is left unparsed, not overflowed into the past '
        '(#146)', () {
      // "in 999999999 days" used to wrap DateTime into year -182837; it must
      // now be treated as unrecognized: phrase kept in the title, no due date.
      final r = parse('y in 999999999 days');
      expect(r.dueAt, isNull);
      expect(r.title, 'y in 999999999 days');
    });

    test('offset just past the ~11-year horizon is left unparsed', () {
      final r = parse('x in 200 months');
      expect(r.dueAt, isNull);
    });

    test('a large-but-in-range offset still parses', () {
      final r = parse('x in 365 days');
      expect(r.dueAt, DateTime(2027, 7, 6, 9));
    });
  });

  group('month-day', () {
    test('future date this year', () {
      final r = parse('flight jul 10');
      expect(r.title, 'flight');
      expect(r.dueAt, DateTime(2026, 7, 10, 9));
    });

    test('past date rolls to next year', () {
      expect(parse('x jan 5').dueAt, DateTime(2027, 1, 5, 9));
    });

    test('today rolls to next year', () {
      expect(parse('x jul 6').dueAt, DateTime(2027, 7, 6, 9));
    });

    test('day month order', () {
      expect(parse('x 10 december').dueAt, DateTime(2026, 12, 10, 9));
    });

    test('invalid day is left alone', () {
      final r = parse('x feb 30');
      expect(r.dueAt, isNull);
      expect(r.title, 'x feb 30');
    });

    test('month word inside another word does not match', () {
      final r = parse('sort junk 10');
      expect(r.dueAt, isNull);
      expect(r.title, 'sort junk 10');
    });

    test('month name alone without a day does not match', () {
      expect(parse('email jan about report').dueAt, isNull);
    });
  });

  group('times', () {
    test('bare pm time later today', () {
      expect(parse('x 5pm').dueAt, DateTime(2026, 7, 6, 17));
    });

    test('time already past moves to tomorrow', () {
      expect(parse('x at 9am').dueAt, DateTime(2026, 7, 7, 9));
    });

    test('at H without am/pm is 24-hour', () {
      expect(parse('x at 5').dueAt, DateTime(2026, 7, 7, 5));
    });

    test('at HH:MM', () {
      expect(parse('x at 17:45').dueAt, DateTime(2026, 7, 6, 17, 45));
    });

    test('12am and 12pm', () {
      expect(parse('x tomorrow at 12am').dueAt, DateTime(2026, 7, 7, 0));
      expect(parse('x tomorrow at 12pm').dueAt, DateTime(2026, 7, 7, 12));
    });

    test('invalid times are left in the title', () {
      final r = parse('x at 25:00');
      expect(r.dueAt, isNull);
      expect(r.title, 'x at 25:00');

      expect(parse('y at 17pm').dueAt, isNull);
    });

    test('date and time combine', () {
      expect(parse('demo tomorrow at 5pm').dueAt, DateTime(2026, 7, 7, 17));
    });

    test('bare number without am/pm is not a time', () {
      final r = parse('buy 2 lemons');
      expect(r.dueAt, isNull);
      expect(r.title, 'buy 2 lemons');
    });
  });

  group('title stripping', () {
    test('no date phrase leaves input untouched', () {
      final r = parse('just a plain todo');
      expect(r.dueAt, isNull);
      expect(r.title, 'just a plain todo');
    });

    test('mid-string phrase collapses whitespace', () {
      expect(parse('pay rent tomorrow please').title, 'pay rent please');
    });

    test('only a date phrase leaves an empty title', () {
      expect(parse('tomorrow at 5pm').title, isEmpty);
    });

    test('glued time is a time, not a month-day', () {
      final r = parse('x jun 10pm');
      // "10pm" has no word boundary after "10", so "jun 10" is not a date.
      expect(r.dueAt, DateTime(2026, 7, 6, 22));
      expect(r.title, 'x jun');
    });
  });
}
