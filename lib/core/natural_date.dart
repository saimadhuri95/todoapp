/// Natural-language date parsing for quick-add (TASKS.md 1.9).
///
/// Pure Dart, no clock access: callers pass `now` from the injected [Clock]
/// (see CLAUDE.md). Recognizes a pragmatic subset anywhere in the input and
/// strips the matched phrase from the title:
///
/// - `today`, `tonight` (20:00), `tomorrow`
/// - weekday names, full or 3-letter (`fri`, `friday`); bare = soonest future
///   occurrence (1–7 days ahead), `next fri` = the one after (8–14 days)
/// - `in N minutes|hours|days|weeks|months`
/// - month + day (`jul 10`, `10 jul`): this year if still ahead, else next
/// - times: `at 5pm`, `at 17:30`, bare `5pm`; combine with any date phrase
///
/// A date phrase with no time defaults to [defaultDueHour]:00. A time with no
/// date means today, or tomorrow if that moment has already passed. Hours
/// without am/pm are read as 24-hour ("at 5" is 05:00). Phrases that don't
/// resolve to a valid moment (`at 25:00`, `feb 30`) are left in the title.
library;

/// Hour used when a phrase names a day but no time ("tomorrow" → 09:00).
const defaultDueHour = 9;

/// Upper bound on relative "in N …" phrases, matching the editor date
/// picker's `now.year + 10` horizon; larger offsets are treated as unparsed.
const _maxHorizonDays = 366 * 11;
const _maxHorizonMonths = 12 * 11;

/// Hour implied by "tonight".
const tonightHour = 20;

class QuickAddResult {
  const QuickAddResult({required this.title, this.dueAt});

  /// Input with the recognized date/time phrase removed.
  final String title;

  /// Parsed due moment, or null when no phrase was recognized.
  final DateTime? dueAt;
}

final _dayWord = RegExp(r'\b(today|tonight|tomorrow)\b', caseSensitive: false);

final _weekday = RegExp(
  r'\b(?:(next)\s+)?'
  r'(mon(?:day)?|tue(?:s|sday)?|wed(?:nesday)?|thu(?:rs?|rsday)?|'
  r'fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b',
  caseSensitive: false,
);

final _relative = RegExp(
  r'\bin\s+(\d+)\s+(minute|min|hour|hr|day|week|month)s?\b',
  caseSensitive: false,
);

const _monthNames =
    r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
    r'jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|'
    r'dec(?:ember)?)';

final _monthDay = RegExp(
  '\\b$_monthNames\\s+(\\d{1,2})\\b',
  caseSensitive: false,
);

final _dayMonth = RegExp(
  '\\b(\\d{1,2})\\s+$_monthNames\\b',
  caseSensitive: false,
);

/// "at 5", "at 5pm", "at 17:30", or bare "5pm" (am/pm required without "at").
final _time = RegExp(
  r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b|\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
  caseSensitive: false,
);

QuickAddResult parseQuickAdd(String input, DateTime now) {
  final matched = <Match>[];

  // Date part: first pattern that matches wins.
  DateTime? date; // date component only (midnight); null = no date phrase
  DateTime? absolute; // full moment for relative phrases ("in 2 hours")
  var timeImplied = false; // "tonight" carries its own hour

  final dayWord = _dayWord.firstMatch(input);
  final weekday = _weekday.firstMatch(input);
  final relative = _relative.firstMatch(input);
  final monthDay = _monthDay.firstMatch(input);
  final dayMonth = _dayMonth.firstMatch(input);

  final today = DateTime(now.year, now.month, now.day);
  if (dayWord != null) {
    matched.add(dayWord);
    switch (dayWord[1]!.toLowerCase()) {
      case 'today':
        date = today;
      case 'tonight':
        date = today;
        timeImplied = true;
      case 'tomorrow':
        date = today.add(const Duration(days: 1));
    }
  } else if (weekday != null) {
    matched.add(weekday);
    final target = _weekdayNumber(weekday[2]!);
    var ahead = (target - now.weekday + 7) % 7;
    if (ahead == 0) ahead = 7; // bare weekday is always in the future
    if (weekday[1] != null) ahead += 7; // "next"
    date = today.add(Duration(days: ahead));
  } else if (relative != null) {
    final n = int.tryParse(relative[1]!) ?? 0;
    // Reject absurd offsets ("in 999999999 days") that would overflow
    // DateTime arithmetic into a far-past/garbage year. The bound matches
    // the editor's date-picker horizon (now.year + 10) so typed and picked
    // dates agree; out-of-range phrases stay in the title, dueAt null.
    final withinHorizon = switch (relative[2]!.toLowerCase()) {
      'minute' || 'min' => n <= _maxHorizonDays * 24 * 60,
      'hour' || 'hr' => n <= _maxHorizonDays * 24,
      'day' => n <= _maxHorizonDays,
      'week' => n <= _maxHorizonDays ~/ 7,
      'month' => n <= _maxHorizonMonths,
      _ => false,
    };
    if (withinHorizon) {
      matched.add(relative);
      switch (relative[2]!.toLowerCase()) {
        case 'minute' || 'min':
          absolute = now.add(Duration(minutes: n));
        case 'hour' || 'hr':
          absolute = now.add(Duration(hours: n));
        case 'day':
          date = today.add(Duration(days: n));
        case 'week':
          date = today.add(Duration(days: 7 * n));
        case 'month':
          date = _addMonthsClamped(today, n);
      }
    }
  } else if (monthDay != null || dayMonth != null) {
    final m = monthDay ?? dayMonth!;
    final month = _monthNumber((monthDay != null ? m[1] : m[2])!);
    final day = int.parse((monthDay != null ? m[2] : m[1])!);
    var candidate = DateTime(now.year, month, day);
    if (candidate.day == day) {
      // day was valid for that month (no overflow into the next one)
      if (!candidate.isAfter(today)) {
        candidate = DateTime(now.year + 1, month, day);
      }
      if (candidate.day == day) {
        matched.add(m);
        date = candidate;
      }
    }
  }

  // Time part. Skipped when a relative phrase already fixed the moment
  // ("in 2 hours at 5pm" — the leftover time text stays in the title), and
  // when it overlaps the date text ("jun 10pm" must not parse twice).
  int? hour;
  var minute = 0;
  var time = absolute == null ? _time.firstMatch(input) : null;
  if (time != null &&
      matched.any((m) => time!.start < m.end && time.end > m.start)) {
    time = null;
  }
  if (time != null) {
    final h = int.parse((time[1] ?? time[4])!);
    final min = int.parse(time[2] ?? time[5] ?? '0');
    final ampm = (time[3] ?? time[6])?.toLowerCase();
    var resolved = h;
    if (ampm != null) {
      if (h >= 1 && h <= 12) {
        resolved = h % 12 + (ampm == 'pm' ? 12 : 0);
      } else {
        resolved = -1; // "at 17pm" is nonsense
      }
    }
    if (resolved >= 0 && resolved <= 23 && min <= 59) {
      hour = resolved;
      minute = min;
      matched.add(time);
    }
  }

  DateTime? dueAt;
  if (absolute != null) {
    dueAt = absolute;
  } else if (date != null) {
    dueAt = DateTime(
      date.year,
      date.month,
      date.day,
      hour ?? (timeImplied ? tonightHour : defaultDueHour),
      hour == null ? 0 : minute,
    );
  } else if (hour != null) {
    dueAt = DateTime(today.year, today.month, today.day, hour, minute);
    if (!dueAt.isAfter(now)) dueAt = dueAt.add(const Duration(days: 1));
  }

  return QuickAddResult(title: _strip(input, matched), dueAt: dueAt);
}

int _weekdayNumber(String word) => switch (word.substring(0, 3).toLowerCase()) {
  'mon' => DateTime.monday,
  'tue' => DateTime.tuesday,
  'wed' => DateTime.wednesday,
  'thu' => DateTime.thursday,
  'fri' => DateTime.friday,
  'sat' => DateTime.saturday,
  _ => DateTime.sunday,
};

int _monthNumber(String word) => switch (word.substring(0, 3).toLowerCase()) {
  'jan' => 1,
  'feb' => 2,
  'mar' => 3,
  'apr' => 4,
  'may' => 5,
  'jun' => 6,
  'jul' => 7,
  'aug' => 8,
  'sep' => 9,
  'oct' => 10,
  'nov' => 11,
  _ => 12,
};

/// Month arithmetic with day clamped to the target month's length
/// ("in 1 month" from Jan 31 → Feb 28/29).
DateTime _addMonthsClamped(DateTime d, int months) {
  final total = d.month - 1 + months;
  final year = d.year + total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

String _strip(String input, List<Match> matches) {
  matches.sort((a, b) => b.start.compareTo(a.start));
  var out = input;
  for (final m in matches) {
    out = out.replaceRange(m.start, m.end, ' ');
  }
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}
