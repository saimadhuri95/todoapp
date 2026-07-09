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

/// What the next occurrence is measured from. [schedule] is a fixed calendar
/// series anchored to the original due date (a normal RRULE). [completion] is
/// a "chore" rule — the next due date is computed from when the task was last
/// *completed*, so a "water the plants every 3 days" item slips forward if you
/// do it late instead of piling up overdue copies (TASKS.md 6.56).
enum RecurrenceAnchor { schedule, completion }

class Recurrence {
  Recurrence({
    required this.freq,
    this.interval = 1,
    this.byWeekdays = const {},
    this.anchor = RecurrenceAnchor.schedule,
  }) : assert(interval >= 1),
       assert(
         byWeekdays.isEmpty || freq == Frequency.weekly,
         'BYDAY only applies to weekly rules',
       );

  factory Recurrence.parse(String rule) {
    Frequency? freq;
    var interval = 1;
    var byWeekdays = const <int>{};
    var anchor = RecurrenceAnchor.schedule;
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
        // Knot extension (not RFC 5545): reschedule from completion time.
        case 'ANCHOR':
          anchor = switch (value) {
            'SCHEDULE' => RecurrenceAnchor.schedule,
            'COMPLETION' => RecurrenceAnchor.completion,
            _ => throw FormatException('Unsupported ANCHOR: $value'),
          };
        default:
          throw FormatException('Unsupported RRULE key: $key');
      }
    }
    if (freq == null) throw const FormatException('RRULE missing FREQ');
    if (byWeekdays.isNotEmpty && freq != Frequency.weekly) {
      throw const FormatException('BYDAY only supported with FREQ=WEEKLY');
    }
    return Recurrence(
      freq: freq,
      interval: interval,
      byWeekdays: byWeekdays,
      anchor: anchor,
    );
  }

  final Frequency freq;
  final int interval;

  /// [DateTime.monday]..[DateTime.sunday]; empty = use the anchor's weekday.
  final Set<int> byWeekdays;

  /// Whether the next due date is measured from the schedule or from the
  /// completion time. See [RecurrenceAnchor].
  final RecurrenceAnchor anchor;

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
    if (anchor == RecurrenceAnchor.completion) buf.write(';ANCHOR=COMPLETION');
    return buf.toString();
  }

  /// The next due date for a completion-anchored ("chore") rule: [interval]
  /// units after the date the task was completed, kept at [anchor]'s time of
  /// day so alarms still fire at the intended hour. Month/year steps clamp a
  /// too-large day to the end of the target month (e.g. Jan 31 + 1 month →
  /// Feb 28/29), and everything is built from calendar components so a local
  /// DST shift doesn't drift the time of day.
  DateTime nextFromCompletion(
    DateTime completedAt, {
    required DateTime anchor,
  }) {
    DateTime at(int year, int month, int day) => anchor.isUtc
        ? DateTime.utc(year, month, day, anchor.hour, anchor.minute)
        : DateTime(year, month, day, anchor.hour, anchor.minute);
    final c = completedAt;
    return switch (freq) {
      Frequency.daily => at(c.year, c.month, c.day + interval),
      Frequency.weekly => at(c.year, c.month, c.day + 7 * interval),
      Frequency.monthly => _clampedDate(at, c.year, c.month + interval, c.day),
      Frequency.yearly => _clampedDate(at, c.year + interval, c.month, c.day),
    };
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

  /// Builds a date [monthsOrYear] steps out via [make], normalizing month
  /// overflow (month 13 → next January) and clamping [day] to the target
  /// month's length so Jan 31 + 1 month lands on Feb 28/29, not Mar 3.
  static DateTime _clampedDate(
    DateTime Function(int, int, int) make,
    int year,
    int month,
    int day,
  ) {
    final y = year + (month - 1) ~/ 12;
    final m = (month - 1) % 12 + 1;
    final dim = _daysInMonth(y, m);
    return make(y, m, day > dim ? dim : day);
  }

  static const _weekdayNames = ['', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  static int _parseWeekday(String s) {
    final i = _weekdayNames.indexOf(s);
    if (i < 1) throw FormatException('Bad BYDAY value: $s');
    return i;
  }
}
