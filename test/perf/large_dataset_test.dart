import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/db/database.dart' show TodosCompanion;
import 'package:todoapp/features/todos/todo_sections.dart';

import '../support/simulated_device.dart';

/// Scale guard for the perf budgets (TASKS.md 6.42, docs/testing.md §8).
///
/// Builds a 5k-todo database and exercises the read/query path the list
/// screen depends on. Timings are printed for visibility; the only
/// assertions are correctness plus a deliberately loose ceiling that catches
/// an accidental O(n²) or a hang without flaking on slow CI runners. The
/// human-facing budgets (cold start < 2 s, quick-add < 500 ms) are verified
/// by profiling and the integration smoke, not here.
void main() {
  test('data layer stays correct and responsive with 5k todos', () async {
    final now = DateTime.utc(2026, 7, 6, 12);
    final device = Device('perf', now);
    addTearDown(device.close);

    const count = 5000;
    final rows = <TodosCompanion>[
      for (var i = 0; i < count; i++)
        TodosCompanion.insert(
          id: 'perf-$i',
          title: 'Task number $i${i % 7 == 0 ? ' urgent' : ''}',
          // Spread across overdue / today / upcoming / someday.
          dueAtMs: Value(
            switch (i % 4) {
              0 => now.subtract(Duration(days: 1 + i % 30)),
              1 => now,
              2 => now.add(Duration(days: 1 + i % 30)),
              _ => null,
            }?.millisecondsSinceEpoch,
          ),
          // ~10% already completed → excluded from the active set.
          completedAtMs: Value(i % 10 == 0 ? now.millisecondsSinceEpoch : null),
        ),
    ];
    await device.db.batch((b) => b.insertAll(device.db.todos, rows));

    final sw = Stopwatch()..start();
    final active = await device.todos.watchActive().first;
    final queryMs = sw.elapsedMilliseconds;

    sw.reset();
    final sections = sectionize(active, now);
    final sectionizeMs = sw.elapsedMilliseconds;

    sw.reset();
    final filtered = filterTodos(active, 'urgent');
    final filterMs = sw.elapsedMilliseconds;

    // ignore: avoid_print
    print(
      '5k todos — query ${queryMs}ms, sectionize ${sectionizeMs}ms, '
      'filter ${filterMs}ms',
    );

    // Correctness at scale.
    expect(active, hasLength(count - count ~/ 10)); // 10% completed excluded
    expect(sections, isNotEmpty);
    expect(sections.map((s) => s.title), contains('Today'));
    expect(filtered, isNotEmpty);
    expect(filtered.every((t) => t.title.contains('urgent')), isTrue);

    // Loose regression ceiling — not a real-time budget.
    expect(queryMs, lessThan(2000));
    expect(sectionizeMs, lessThan(2000));
    expect(filterMs, lessThan(2000));
  });
}
