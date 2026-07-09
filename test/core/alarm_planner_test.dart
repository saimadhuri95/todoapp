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
