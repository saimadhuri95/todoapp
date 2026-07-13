import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/todos/kanban.dart';
import 'package:todoapp/features/todos/kanban_screen.dart';

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

  group('KanbanScreen move menu', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('kanban-device'),
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 7, 6, 12)),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    testWidgets('"No section" really clears the section (regression: a '
        'null menu value never reaches onSelected)', (tester) async {
      final repo = container.read(todoRepositoryProvider);
      final todo = await repo.create(title: 'ship it', section: 'Doing');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: KanbanScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Doing (1)'), findsOneWidget);

      await tester.tap(find.byTooltip('Move to column'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No section'));
      await tester.pumpAndSettle();

      expect((await repo.getById(todo.id))!.section, isNull);
      expect(find.text('No section (1)'), findsOneWidget);

      // Drift stream keep-alive: settle timers before the binding asserts.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });
  });
}
