import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/tray_service.dart';
import 'package:todoapp/data/db/database.dart';

Todo todo(
  String id, {
  int? dueAtMs,
  bool completed = false,
  bool deleted = false,
  String? parentId,
}) => Todo(
  id: id,
  title: id,
  notes: '',
  priority: 0,
  tagsJson: '[]',
  sortKey: '',
  alarmOffsetsJson: '[]',
  pinned: false,
  currentStreak: 0,
  dueAtMs: dueAtMs,
  completedAtMs: completed ? 1 : null,
  deleted: deleted,
  parentId: parentId,
);

void main() {
  final now = DateTime(2026, 7, 6, 12); // noon
  int at(int day, int hour) =>
      DateTime(2026, 7, day, hour).millisecondsSinceEpoch;

  group('dueTodayCount', () {
    test('counts overdue and today, excludes future/undated', () {
      final count = dueTodayCount([
        todo('overdue', dueAtMs: at(5, 9)),
        todo('this-morning', dueAtMs: at(6, 9)),
        todo('tonight', dueAtMs: at(6, 23)),
        todo('tomorrow', dueAtMs: at(7, 9)),
        todo('undated'),
      ], now);
      expect(count, 3);
    });

    test('excludes completed, deleted, and subtasks', () {
      final count = dueTodayCount([
        todo('done', dueAtMs: at(6, 9), completed: true),
        todo('gone', dueAtMs: at(6, 9), deleted: true),
        todo('subtask', dueAtMs: at(6, 9), parentId: 'p'),
        todo('real', dueAtMs: at(6, 9)),
      ], now);
      expect(count, 1);
    });

    test('is zero for an empty list', () {
      expect(dueTodayCount(const [], now), 0);
    });
  });

  group('trayTooltip', () {
    test('plain brand name when nothing is due', () {
      expect(trayTooltip(0), 'Knot');
    });

    test('shows the count when items are due', () {
      expect(trayTooltip(3), 'Knot — 3 due today');
    });
  });
}
