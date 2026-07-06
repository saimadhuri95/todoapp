/// RRULE subset for repeating todos (see TASKS.md 1.4): FREQ
/// (DAILY/WEEKLY/MONTHLY/YEARLY), INTERVAL, and BYDAY for weekly rules.
/// Stored in `todos.recurrenceRule` in RFC 5545 text form, e.g.
/// `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE`.
///
/// Occurrence semantics follow RFC 5545: dates that don't exist are
/// skipped — monthly-on-the-31st fires only in 31-day months, yearly on
/// Feb 29 only in leap years.
library;

enum Frequency { daily, weekly, monthly, yearly }

class Recurrence {
  Recurrence({
    required this.freq,
    this.interval = 1,
    this.byWeekdays = const {},
  }) : assert(interval >= 1),
       assert(
         byWeekdays.isEmpty || freq == Frequency.weekly,
         'BYDAY only applies to weekly rules',
       );

  factory Recurrence.parse(String rule) {
    Frequency? freq;
    var interval = 1;
    var byWeekdays = const <int>{};
    for (final part in rule.split(';')) {
      final eq = part.indexOf('=');
      if (eq == -1) throw FormatException('Invalid RRULE part: $part');
      final key = part.substring(0, eq);
      final value = part.substring(eq + 1);
      switch (key) {
        case 'FREQ':
          freq = switch (value) {
            'DAILY' => Frequency.daily,
            'WEEKLY' => Frequency.weekly,
            'MONTHLY' => Frequency.monthly,
            'YEARLY' => Frequency.yearly,
            _ => throw FormatException('Unsupported FREQ: $value'),
          };
        case 'INTERVAL':
          interval = int.parse(value);
          if (interval < 1) throw FormatException('Bad INTERVAL: $value');
        case 'BYDAY':
          byWeekdays = value.split(',').map(_parseWeekday).toSet();
        default:
          throw FormatException('Unsupported RRULE key: $key');
      }
    }
    if (freq == null) throw const FormatException('RRULE missing FREQ');
    if (byWeekdays.isNotEmpty && freq != Frequency.weekly) {
      throw const FormatException('BYDAY only supported with FREQ=WEEKLY');
    }
    return Recurrence(freq: freq, interval: interval, byWeekdays: byWeekdays);
  }

  final Frequency freq;
  final int interval;

  /// [DateTime.monday]..[DateTime.sunday]; empty = use the anchor's weekday.
  final Set<int> byWeekdays;

  String encode() {
    final freqStr = switch (freq) {
      Frequency.daily => 'DAILY',
      Frequency.weekly => 'WEEKLY',
      Frequency.monthly => 'MONTHLY',
      Frequency.yearly => 'YEARLY',
    };
    final buf = StringBuffer('FREQ=$freqStr');
    if (interval != 1) buf.write(';INTERVAL=$interval');
    if (byWeekdays.isNotEmpty) {
      final days = (byWeekdays.toList()..sort()).map(_weekdayNames.elementAt);
      buf.write(';BYDAY=${days.join(',')}');
    }
    return buf.toString();
  }

  /// The first occurrence strictly after [after]. [anchor] is the todo's
  /// original due datetime: it fixes the time of day, the day-of-month /
  /// date for monthly/yearly rules, and the base week for INTERVAL > 1.
  /// The series starts at [anchor]; nothing before it is ever returned.
  DateTime nextAfter(DateTime after, {required DateTime anchor}) {
    final floor = anchor.subtract(const Duration(microseconds: 1));
    final effectiveAfter = after.isBefore(floor) ? floor : after;
    return switch (freq) {
      Frequency.daily => _nextDaily(effectiveAfter, anchor),
      Frequency.weekly => _nextWeekly(effectiveAfter, anchor),
      Frequency.monthly => _nextMonthly(effectiveAfter, anchor),
      Frequency.yearly => _nextYearly(effectiveAfter, anchor),
    };
  }

  DateTime _nextDaily(DateTime after, DateTime anchor) {
    var k = _daysBetween(anchor, after) ~/ interval;
    if (k < 0) k = 0;
    var candidate = _onDay(anchor, dayOffset: k * interval);
    while (!candidate.isAfter(after)) {
      k++;
      candidate = _onDay(anchor, dayOffset: k * interval);
    }
    return candidate;
  }

  DateTime _nextWeekly(DateTime after, DateTime anchor) {
    final weekdays =
        (byWeekdays.isEmpty ? {anchor.weekday} : byWeekdays).toList()..sort();
    // Monday of the anchor's week is the base for interval spacing.
    final baseOffset = -(anchor.weekday - DateTime.monday);
    var week = (_daysBetween(anchor, after) - baseOffset) ~/ (7 * interval);
    if (week < 0) week = 0;
    while (true) {
      for (final weekday in weekdays) {
        final candidate = _onDay(
          anchor,
          dayOffset:
              baseOffset + week * 7 * interval + (weekday - DateTime.monday),
        );
        if (candidate.isAfter(after)) return candidate;
      }
      week++;
    }
  }

  DateTime _nextMonthly(DateTime after, DateTime anchor) {
    final anchorIdx = anchor.year * 12 + (anchor.month - 1);
    final afterIdx = after.year * 12 + (after.month - 1);
    var k = (afterIdx - anchorIdx) ~/ interval;
    if (k < 0) k = 0;
    while (true) {
      final idx = anchorIdx + k * interval;
      final year = idx ~/ 12;
      final month = idx % 12 + 1;
      k++;
      if (anchor.day > _daysInMonth(year, month)) continue; // RFC: skip
      final candidate = _at(anchor, year, month, anchor.day);
      if (candidate.isAfter(after)) return candidate;
    }
  }

  DateTime _nextYearly(DateTime after, DateTime anchor) {
    var k = (after.year - anchor.year) ~/ interval;
    if (k < 0) k = 0;
    while (true) {
      final year = anchor.year + k * interval;
      k++;
      if (anchor.day > _daysInMonth(year, anchor.month)) continue; // Feb 29
      final candidate = _at(anchor, year, anchor.month, anchor.day);
      if (candidate.isAfter(after)) return candidate;
    }
  }

  /// Anchor's time of day on anchor's date + [dayOffset] days. Built from
  /// calendar components (not Duration) so local-time DST shifts don't
  /// drift the time of day.
  static DateTime _onDay(DateTime anchor, {required int dayOffset}) =>
      anchor.isUtc
      ? DateTime.utc(
          anchor.year,
          anchor.month,
          anchor.day + dayOffset,
          anchor.hour,
          anchor.minute,
        )
      : DateTime(
          anchor.year,
          anchor.month,
          anchor.day + dayOffset,
          anchor.hour,
          anchor.minute,
        );

  static DateTime _at(DateTime anchor, int year, int month, int day) =>
      anchor.isUtc
      ? DateTime.utc(year, month, day, anchor.hour, anchor.minute)
      : DateTime(year, month, day, anchor.hour, anchor.minute);

  /// Whole calendar days from [from]'s date to [to]'s date (negative if
  /// [to] is earlier). Computed on date-only UTC values so it is exact.
  static int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static int _daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  static const _weekdayNames = ['', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  static int _parseWeekday(String s) {
    final i = _weekdayNames.indexOf(s);
    if (i < 1) throw FormatException('Bad BYDAY value: $s');
    return i;
  }
}
