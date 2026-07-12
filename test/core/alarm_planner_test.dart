import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/alarm_planner.dart';
import 'package:todoapp/data/db/database.dart';

Todo todo(
  String id, {
  int? dueAtMs,
  String alarms = '[]',
  String? rrule,
  int? dismissed,
  int? snooze,
  int? completedAtMs,
  int? nag,
  bool deleted = false,
}) => Todo(
  id: id,
  title: 'todo $id',
  notes: '',
  dueAtMs: dueAtMs,
  recurrenceRule: rrule,
  completedAtMs: completedAtMs,
  priority: 0,
  tagsJson: '[]',
  sortKey: '',
  alarmOffsetsJson: alarms,
  lastDismissedMs: dismissed,
  snoozeUntilMs: snooze,
  pinned: false,
  nagIntervalMinutes: nag,
  currentStreak: 0,
  deleted: deleted,
);

void main() {
  final now = DateTime.utc(2026, 7, 6, 12);
  final nowMs = now.millisecondsSinceEpoch;
  int inMin(int m) => nowMs + m * 60000;

  test('offsets produce one instance each, sharing the occurrence', () {
    final plan = planAlarms([
      todo('a', dueAtMs: inMin(60), alarms: '[0, 30]'),
    ], now: now);

    expect(plan, hasLength(2));
    expect(plan[0].fireAtMs, inMin(30)); // 30-min-before rings first
    expect(plan[1].fireAtMs, inMin(60));
    expect(plan[0].occurrenceMs, plan[1].occurrenceMs);
  });

  test('past fires, completed, deleted, and no-due todos are excluded', () {
    final plan = planAlarms([
      todo('past', dueAtMs: inMin(-5), alarms: '[0]'),
      todo('done', dueAtMs: inMin(60), alarms: '[0]', completedAtMs: 1),
      todo('gone', dueAtMs: inMin(60), alarms: '[0]', deleted: true),
      todo('nodate', alarms: '[0]'),
    ], now: now);

    expect(plan, isEmpty);
  });

  test('past occurrence with a future offset is included only if the fire '
      'time is future', () {
    // Due in 10 min with a 30-min-before offset: fire time already passed.
    // The at-time offset still fires.
    final plan = planAlarms([
      todo('a', dueAtMs: inMin(10), alarms: '[30, 0]'),
    ], now: now);

    expect(plan, hasLength(1));
    expect(plan.single.fireAtMs, inMin(10));
  });

  test('dismissed occurrence is suppressed; later ones are not', () {
    final due = inMin(60);
    final plan = planAlarms(
      [
        todo('a', dueAtMs: due, alarms: '[0]', dismissed: due),
        todo(
          'b',
          dueAtMs: due,
          alarms: '[0]',
          rrule: 'FREQ=DAILY',
          dismissed: due,
        ),
      ],
      now: now,
      horizon: const Duration(days: 2),
    );

    // a: fully silenced. b: tomorrow's occurrence still rings.
    expect(plan, hasLength(1));
    expect(plan.single.todoId, 'b');
    expect(plan.single.fireAtMs, due + const Duration(days: 1).inMilliseconds);
  });

  test('recurrence expands multiple occurrences within the horizon', () {
    final plan = planAlarms(
      [todo('a', dueAtMs: inMin(60), alarms: '[0]', rrule: 'FREQ=DAILY')],
      now: now,
      horizon: const Duration(days: 3),
    );

    expect(plan, hasLength(3)); // today + 2 more days within horizon
  });

  test('cap keeps the plan under the platform pending limit', () {
    final plan = planAlarms(
      [
        for (var i = 0; i < 5; i++)
          todo(
            't$i',
            dueAtMs: inMin(60 + i),
            alarms: '[0]',
            rrule: 'FREQ=DAILY',
          ),
      ],
      now: now,
      cap: 10,
    );

    expect(plan, hasLength(10));
    // Soonest-first: the cap keeps the *nearest* alarms.
    expect(plan.first.fireAtMs, inMin(60));
    final sorted = [...plan]..sort();
    expect(plan, sorted);
  });

  group('nag reminders (6.44)', () {
    test('future due: rings at due, then every N minutes after', () {
      final due = inMin(30);
      final plan = planAlarms(
        [todo('a', dueAtMs: due, alarms: '[0]', nag: 10)],
        now: now,
        cap: 4,
      );

      expect(plan.map((a) => a.fireAtMs).toList(), [
        due,
        inMin(40),
        inMin(50),
        inMin(60),
      ]);
      // The whole chain shares the occurrence, so one dismiss silences it.
      expect(plan.map((a) => a.occurrenceMs).toSet(), {due});
    });

    test('long-overdue todo nags from now, not from the missed repeats', () {
      // Due 3 days ago with a 15-min nag: the next fire is within 15 min
      // of now, not thousands of replayed repeats.
      final due = nowMs - const Duration(days: 3).inMilliseconds;
      final plan = planAlarms(
        [todo('a', dueAtMs: due, alarms: '[0]', nag: 15)],
        now: now,
        cap: 2,
      );

      expect(plan, hasLength(2));
      expect(plan.first.fireAtMs, greaterThan(nowMs));
      expect(plan.first.fireAtMs, lessThanOrEqualTo(inMin(15)));
      expect(plan[1].fireAtMs - plan[0].fireAtMs, 15 * 60000);
      expect(plan.first.occurrenceMs, due);
    });

    test('nag without explicit offsets still rings at the due time', () {
      final due = inMin(30);
      final plan = planAlarms(
        [todo('a', dueAtMs: due, nag: 10)],
        now: now,
        cap: 2,
      );

      expect(plan.map((a) => a.fireAtMs).toList(), [due, inMin(40)]);
    });

    test('dismissing the occurrence silences the whole chain', () {
      final due = inMin(-20);
      final plan = planAlarms([
        todo('a', dueAtMs: due, alarms: '[0]', nag: 10, dismissed: due),
      ], now: now);

      expect(plan, isEmpty);
    });

    test('recurring nag anchors to the latest already-due occurrence', () {
      // Daily todo anchored 10 days ago, due at 09:00; now is 12:00. The
      // nag chain hangs off *today's* occurrence.
      final anchor = DateTime.utc(2026, 6, 26, 9).millisecondsSinceEpoch;
      final todayOcc = DateTime.utc(2026, 7, 6, 9).millisecondsSinceEpoch;
      final plan = planAlarms(
        [
          todo(
            'a',
            dueAtMs: anchor,
            alarms: '[0]',
            nag: 60,
            rrule: 'FREQ=DAILY',
          ),
        ],
        now: now,
        cap: 3,
        horizon: const Duration(hours: 20),
      );

      expect(plan, isNotEmpty);
      expect(plan.first.occurrenceMs, todayOcc);
      expect(plan.first.fireAtMs, inMin(60)); // 13:00, next hourly nag
    });
  });

  test('snooze adds one extra fire and dismissal clears it', () {
    final plan = planAlarms([
      todo('a', dueAtMs: inMin(-10), alarms: '[0]', snooze: inMin(5)),
    ], now: now);

    expect(plan, hasLength(1));
    expect(plan.single.fireAtMs, inMin(5));

    // After dismissal (snooze cleared by dismissAlarm) nothing remains.
    final after = planAlarms([
      todo('a', dueAtMs: inMin(-10), alarms: '[0]', dismissed: inMin(5)),
    ], now: now);
    expect(after, isEmpty);
  });
}
