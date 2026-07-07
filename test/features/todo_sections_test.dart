import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/todos/todo_sections.dart';

Todo todo(
  String id, {
  int? dueAtMs,
  String title = 't',
  String notes = '',
  String tagsJson = '[]',
}) => Todo(
  id: id,
  title: title,
  notes: notes,
  dueAtMs: dueAtMs,
  priority: 0,
  tagsJson: tagsJson,
  alarmOffsetsJson: '[]',
  deleted: false,
);

void main() {
  final now = DateTime(2026, 7, 5, 12); // noon

  int at(int day, int hour) =>
      DateTime(2026, 7, day, hour).millisecondsSinceEpoch;

  group('sectionize', () {
    test('splits today/upcoming/someday, folding overdue into Today', () {
      final sections = sectionize([
        todo('yesterday', dueAtMs: at(4, 9)), // repository orders by due date
        todo('overdue', dueAtMs: at(5, 9)), // this morning, past noon
        todo('today', dueAtMs: at(5, 18)), // tonight
        todo('tomorrow', dueAtMs: at(6, 9)),
        todo('someday'),
      ], now);

      // No shaming "Overdue" section (TASKS.md 6.16): overdue leads Today.
      expect(sections.map((s) => s.title), ['Today', 'Upcoming', 'Someday']);
      expect(sections[0].items.map((t) => t.id), [
        'yesterday',
        'overdue',
        'today',
      ]);
      expect(sections[1].items.map((t) => t.id), ['tomorrow']);
      expect(sections[2].items.map((t) => t.id), ['someday']);
    });

    test('empty input yields no sections', () {
      expect(sectionize([], now), isEmpty);
    });

    test('due exactly now counts as today', () {
      final sections = sectionize([
        todo('x', dueAtMs: now.millisecondsSinceEpoch),
      ], now);
      expect(sections.single.title, 'Today');
    });
  });

  group('overdueLabel', () {
    // 2026-07-05 is a Sunday.
    test('null for due today or later, even if past now', () {
      expect(overdueLabel(at(5, 9), now), isNull); // late but same day
      expect(overdueLabel(at(5, 18), now), isNull);
      expect(overdueLabel(at(6, 9), now), isNull);
    });

    test('weekday within the last week', () {
      expect(overdueLabel(at(4, 9), now), 'since Sat');
      expect(overdueLabel(at(3, 23), now), 'since Fri');
      // 6 days back = Monday Jun 29, still a weekday label.
      final jun29 = DateTime(2026, 6, 29, 8).millisecondsSinceEpoch;
      expect(overdueLabel(jun29, now), 'since Mon');
    });

    test('month + day from a week back', () {
      final jun28 = DateTime(2026, 6, 28, 8).millisecondsSinceEpoch;
      expect(overdueLabel(jun28, now), 'since Jun 28');
      final feb10 = DateTime(2026, 2, 10).millisecondsSinceEpoch;
      expect(overdueLabel(feb10, now), 'since Feb 10');
    });
  });

  group('filterTodos', () {
    final items = [
      todo('1', title: 'Buy milk'),
      todo('2', title: 'Email Bob', notes: 'about the milk budget'),
      todo('3', title: 'Gym', tagsJson: '["health","Milky-Way"]'),
      todo('4', title: 'Nothing'),
    ];

    test('matches title, notes, and tags case-insensitively', () {
      expect(filterTodos(items, 'MILK').map((t) => t.id), ['1', '2', '3']);
    });

    test('blank query returns everything', () {
      expect(filterTodos(items, '  '), items);
    });
  });
}
