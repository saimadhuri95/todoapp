import 'package:drift/drift.dart' show TableOrViewStatements;
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/db/database.dart' show Todo;
import 'package:todoapp/features/todos/eisenhower.dart';

import '../support/simulated_device.dart';

void main() {
  final now = DateTime.utc(2026, 7, 6, 12);
  late Device device;

  setUp(() => device = Device('aa', now));
  tearDown(() => device.close());

  int at(Duration fromNow) => now.add(fromNow).millisecondsSinceEpoch;

  Future<List<Todo>> active() => device.db.todos.all().get();

  test('sorts todos into the four quadrants by importance × urgency', () async {
    // important (priority>=2) + urgent (due within 24h) → doFirst
    await device.todos.create(
      title: 'ship',
      priority: 3,
      dueAtMs: at(const Duration(hours: 2)),
    );
    // important, not urgent → schedule
    await device.todos.create(
      title: 'plan',
      priority: 2,
      dueAtMs: at(const Duration(days: 5)),
    );
    // urgent, not important → delegate
    await device.todos.create(
      title: 'reply',
      priority: 1,
      dueAtMs: at(const Duration(hours: 3)),
    );
    // neither → eliminate (no due date, low priority)
    await device.todos.create(title: 'someday');

    final b = eisenhowerBuckets(await active(), now);
    expect(b[EisenhowerQuadrant.doFirst].map((t) => t.title), ['ship']);
    expect(b[EisenhowerQuadrant.schedule].map((t) => t.title), ['plan']);
    expect(b[EisenhowerQuadrant.delegate].map((t) => t.title), ['reply']);
    expect(b[EisenhowerQuadrant.eliminate].map((t) => t.title), ['someday']);
    expect(b.isEmpty, isFalse);
  });

  test('an overdue important todo is urgent → doFirst', () async {
    await device.todos.create(
      title: 'overdue important',
      priority: 3,
      dueAtMs: at(const Duration(days: -3)),
    );
    final b = eisenhowerBuckets(await active(), now);
    expect(b[EisenhowerQuadrant.doFirst].map((t) => t.title), [
      'overdue important',
    ]);
  });

  test('an undated high-priority todo is important but not urgent', () async {
    await device.todos.create(title: 'big rock', priority: 3);
    final b = eisenhowerBuckets(await active(), now);
    expect(b[EisenhowerQuadrant.schedule].map((t) => t.title), ['big rock']);
    expect(b[EisenhowerQuadrant.doFirst], isEmpty);
  });

  test('empty input yields four empty quadrants', () {
    final b = eisenhowerBuckets(const [], now);
    expect(b.isEmpty, isTrue);
    for (final q in EisenhowerQuadrant.values) {
      expect(b[q], isEmpty);
    }
  });

  test('the urgent window is configurable', () async {
    await device.todos.create(
      title: 'due in 3 days',
      priority: 3,
      dueAtMs: at(const Duration(days: 3)),
    );
    final wide = eisenhowerBuckets(
      await active(),
      now,
      urgentWindow: const Duration(days: 7),
    );
    expect(wide[EisenhowerQuadrant.doFirst].map((t) => t.title), [
      'due in 3 days',
    ]);
  });
}
