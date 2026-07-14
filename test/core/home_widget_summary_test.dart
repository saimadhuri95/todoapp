import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/home_widget_summary.dart';
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
  final now = DateTime(2026, 7, 6, 12);
  int at(int day, int hour) =>
      DateTime(2026, 7, day, hour).millisecondsSinceEpoch;

  test('counts overdue + today, titles ordered soonest-first', () {
    final summary = homeWidgetSummary([
      todo('tonight', dueAtMs: at(6, 20)),
      todo('overdue', dueAtMs: at(5, 9)),
      todo('this-morning', dueAtMs: at(6, 9)),
      todo('tomorrow', dueAtMs: at(7, 9)),
      todo('undated'),
    ], now);

    expect(summary.dueToday, 3);
    expect(summary.titles, ['overdue', 'this-morning', 'tonight']);
  });

  test('caps titles at maxTitles but keeps the full count', () {
    final summary = homeWidgetSummary(
      [for (var i = 0; i < 6; i++) todo('t$i', dueAtMs: at(6, 8 + i))],
      now,
      maxTitles: 3,
    );

    expect(summary.dueToday, 6);
    expect(summary.titles, ['t0', 't1', 't2']);
  });

  test('excludes completed, deleted, and subtasks', () {
    final summary = homeWidgetSummary([
      todo('done', dueAtMs: at(6, 9), completed: true),
      todo('gone', dueAtMs: at(6, 9), deleted: true),
      todo('sub', dueAtMs: at(6, 9), parentId: 'p'),
      todo('real', dueAtMs: at(6, 9)),
    ], now);

    expect(summary.dueToday, 1);
    expect(summary.titles, ['real']);
  });

  test('empty when nothing is due', () {
    final summary = homeWidgetSummary([todo('undated')], now);
    expect(summary.dueToday, 0);
    expect(summary.titles, isEmpty);
    expect(summary.toJson(), {'dueToday': 0, 'titles': <String>[]});
  });

  group('display strings', () {
    test('headline pluralises and handles empty', () {
      expect(
        homeWidgetHeadline(const HomeWidgetSummary(dueToday: 0, titles: [])),
        'Nothing due today',
      );
      expect(
        homeWidgetHeadline(const HomeWidgetSummary(dueToday: 1, titles: ['a'])),
        '1 due today',
      );
      expect(
        homeWidgetHeadline(
          const HomeWidgetSummary(dueToday: 4, titles: ['a', 'b', 'c']),
        ),
        '4 due today',
      );
    });

    test('body lists titles with a +N more tail', () {
      expect(
        homeWidgetBody(
          const HomeWidgetSummary(dueToday: 5, titles: ['a', 'b', 'c']),
        ),
        'a\nb\nc\n+2 more',
      );
    });

    test('body is empty when nothing is due', () {
      expect(
        homeWidgetBody(const HomeWidgetSummary(dueToday: 0, titles: [])),
        '',
      );
    });

    test('body omits the tail when all titles fit', () {
      expect(
        homeWidgetBody(
          const HomeWidgetSummary(dueToday: 2, titles: ['a', 'b']),
        ),
        'a\nb',
      );
    });
  });
}
