import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/alarm_planner.dart';
import 'package:todoapp/core/recurrence.dart';
import 'package:todoapp/data/db/database.dart';

/// DST correctness (TASKS.md 2.10). Dart's local zone is fixed at VM
/// start, so these tests only mean something in a zone that observes DST:
/// CI runs them under `TZ=America/New_York`; elsewhere they self-skip.
/// US 2026: spring forward Mar 8, fall back Nov 1.
void main() {
  final observesDst =
      DateTime(2026, 1, 15).timeZoneOffset !=
      DateTime(2026, 7, 15).timeZoneOffset;
  if (!observesDst) {
    test(
      'DST suite',
      () {},
      skip: 'Local zone has no DST — run with TZ=America/New_York',
    );
    return;
  }

  Todo todo(int dueAtMs, {String? rrule}) => Todo(
    id: 't',
    title: 't',
    notes: '',
    dueAtMs: dueAtMs,
    recurrenceRule: rrule,
    priority: 0,
    tagsJson: '[]',
    alarmOffsetsJson: '[0]',
    pinned: false,
    deleted: false,
  );

  test('daily recurrence keeps 9:00 local across spring forward', () {
    final anchor = DateTime(2026, 3, 7, 9); // day before the jump
    final rule = Recurrence.parse('FREQ=DAILY');
    var cursor = anchor;
    for (var i = 0; i < 4; i++) {
      cursor = rule.nextAfter(cursor, anchor: anchor);
      expect(cursor.hour, 9, reason: 'day ${cursor.day}');
    }
    // The skipped hour makes Mar 7→Mar 8 only 23h apart in real time.
    final mar8 = rule.nextAfter(anchor, anchor: anchor);
    expect(
      mar8.millisecondsSinceEpoch - anchor.millisecondsSinceEpoch,
      const Duration(hours: 23).inMilliseconds,
    );
  });

  test('daily recurrence keeps 9:00 local across fall back', () {
    final anchor = DateTime(2026, 10, 31, 9); // day before fall back Nov 1
    final rule = Recurrence.parse('FREQ=DAILY');
    final nov1 = rule.nextAfter(anchor, anchor: anchor);
    expect(nov1.hour, 9);
    // The repeated hour makes the gap 25h.
    expect(
      nov1.millisecondsSinceEpoch - anchor.millisecondsSinceEpoch,
      const Duration(hours: 25).inMilliseconds,
    );
  });

  test('planner fire times follow the local wall clock across the jump', () {
    final anchor = DateTime(2026, 3, 7, 9);
    final plan = planAlarms(
      [todo(anchor.millisecondsSinceEpoch, rrule: 'FREQ=DAILY')],
      now: DateTime(2026, 3, 7, 10),
      horizon: const Duration(days: 3),
    );

    expect(plan, isNotEmpty);
    for (final alarm in plan) {
      expect(
        DateTime.fromMillisecondsSinceEpoch(alarm.fireAtMs).hour,
        9,
        reason: alarm.toString(),
      );
    }
  });

  test('weekly recurrence lands on the right weekday through transitions', () {
    final anchor = DateTime(2026, 3, 2, 9); // Monday before spring forward
    final rule = Recurrence.parse('FREQ=WEEKLY;BYDAY=MO');
    var cursor = anchor;
    for (var i = 0; i < 4; i++) {
      cursor = rule.nextAfter(cursor, anchor: anchor);
      expect(cursor.weekday, DateTime.monday);
      expect(cursor.hour, 9);
    }
  });
}
