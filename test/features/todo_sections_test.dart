import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/todos/todo_sections.dart';

Todo todo(
  String id, {
  int? dueAtMs,
  String title = 't',
  String notes = '',
  String tagsJson = '[]',
  bool pinned = false,
  String? section,
  int? estimateMinutes,
}) => Todo(
  id: id,
  title: title,
  notes: notes,
  dueAtMs: dueAtMs,
  priority: 0,
  tagsJson: tagsJson,
  section: section,
  sortKey: '',
  alarmOffsetsJson: '[]',
  pinned: pinned,
  estimateMinutes: estimateMinutes,
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

    test('pinned todos lead in a Top 3 section, not their due bucket', () {
      final sections = sectionize([
        todo('pin-due', dueAtMs: at(5, 18), pinned: true), // would be Today
        todo('pin-someday', pinned: true), // would be Someday
        todo('plain-today', dueAtMs: at(5, 9)),
        todo('plain-someday'),
      ], now);

      expect(sections.first.title, 'Top 3');
      // Input order preserved; pinned items excluded from Today/Someday.
      expect(sections.first.items.map((t) => t.id), ['pin-due', 'pin-someday']);
      expect(sections.map((s) => s.title), ['Top 3', 'Today', 'Someday']);
      expect(sections[1].items.map((t) => t.id), ['plain-today']);
      expect(sections[2].items.map((t) => t.id), ['plain-someday']);
    });

    test('a pinned todo wins over its user-defined section', () {
      final sections = sectionize([
        todo('pinned', section: 'Waiting', pinned: true),
        todo('waiting', section: 'Waiting'),
      ], now);

      expect(sections.map((s) => s.title), ['Top 3', 'Waiting']);
      expect(sections.first.items.map((t) => t.id), ['pinned']);
    });

    test('user-defined sections are their own buckets', () {
      final sections = sectionize([
        todo('today', dueAtMs: at(5, 18)),
        todo('waiting-a', section: 'Waiting'),
        todo('waiting-b', section: 'Waiting'),
      ], now);

      expect(sections.map((s) => s.title), ['Today', 'Waiting']);
      expect(sections.last.userSection, 'Waiting');
      expect(sections.last.items.map((todo) => todo.id), [
        'waiting-a',
        'waiting-b',
      ]);
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

  group('quickWins', () {
    test('keeps only todos estimated at or under the ceiling', () {
      final items = [
        todo('quick', estimateMinutes: 5),
        todo('exactly', estimateMinutes: 10),
        todo('long', estimateMinutes: 30),
        todo('unestimated'),
      ];
      expect(quickWins(items).map((t) => t.id), ['quick', 'exactly']);
    });

    test('respects a custom ceiling', () {
      final items = [
        todo('a', estimateMinutes: 15),
        todo('b', estimateMinutes: 45),
      ];
      expect(quickWins(items, maxMinutes: 20).map((t) => t.id), ['a']);
    });
  });
}
