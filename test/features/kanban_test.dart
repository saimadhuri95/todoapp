import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/todos/kanban.dart';

Todo todo(String id, {String? section}) => Todo(
  id: id,
  title: id,
  notes: '',
  priority: 0,
  tagsJson: '[]',
  section: section,
  sortKey: '',
  alarmOffsetsJson: '[]',
  pinned: false,
  currentStreak: 0,
  deleted: false,
);

void main() {
  group('kanbanColumns (TASKS.md 6.49)', () {
    test('groups by section, unsectioned column leads', () {
      final columns = kanbanColumns([
        todo('a', section: 'Doing'),
        todo('b'),
        todo('c', section: 'Done'),
        todo('d', section: 'Doing'),
      ]);

      expect(columns.map((c) => c.title), ['No section', 'Doing', 'Done']);
      expect(columns[0].items.map((t) => t.id), ['b']);
      expect(columns[1].items.map((t) => t.id), ['a', 'd']);
      expect(columns[2].items.map((t) => t.id), ['c']);
    });

    test('named columns sort alphabetically', () {
      final columns = kanbanColumns([
        todo('a', section: 'Zeta'),
        todo('b', section: 'Alpha'),
      ]);

      expect(columns.map((c) => c.title), ['No section', 'Alpha', 'Zeta']);
    });

    test('unsectioned column is present even when empty', () {
      final columns = kanbanColumns([todo('a', section: 'Doing')]);

      expect(columns.first.section, isNull);
      expect(columns.first.items, isEmpty);
    });

    test('blank/whitespace section counts as unsectioned', () {
      final columns = kanbanColumns([todo('a', section: '   ')]);

      expect(columns, hasLength(1));
      expect(columns.single.section, isNull);
    });

    test('empty input yields just the empty unsectioned column', () {
      final columns = kanbanColumns(const []);

      expect(columns, hasLength(1));
      expect(columns.single.items, isEmpty);
    });
  });
}
