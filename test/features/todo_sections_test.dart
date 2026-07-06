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
    test('splits overdue/today/upcoming/someday and drops empty sections', () {
      final sections = sectionize([
        todo('overdue', dueAtMs: at(5, 9)), // this morning, past noon
        todo('yesterday', dueAtMs: at(4, 9)),
        todo('today', dueAtMs: at(5, 18)), // tonight
        todo('tomorrow', dueAtMs: at(6, 9)),
        todo('someday'),
      ], now);

      expect(sections.map((s) => s.title), [
        'Overdue',
        'Today',
        'Upcoming',
        'Someday',
      ]);
      expect(sections[0].items.map((t) => t.id), ['overdue', 'yesterday']);
      expect(sections[1].items.map((t) => t.id), ['today']);
      expect(sections[2].items.map((t) => t.id), ['tomorrow']);
      expect(sections[3].items.map((t) => t.id), ['someday']);
    });

    test('empty input yields no sections', () {
      expect(sectionize([], now), isEmpty);
    });

    test('due exactly now counts as overdue, not today', () {
      final sections = sectionize([
        todo('x', dueAtMs: now.millisecondsSinceEpoch),
      ], now);
      expect(sections.single.title, 'Overdue');
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
