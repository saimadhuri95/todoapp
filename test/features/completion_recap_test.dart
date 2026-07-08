import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/todos/todo_sections.dart';
import 'package:todoapp/main.dart';

Todo todo(String id, {int? completedAtMs}) => Todo(
  id: id,
  title: id,
  notes: '',
  priority: 0,
  tagsJson: '[]',
  sortKey: '',
  alarmOffsetsJson: '[]',
  completedAtMs: completedAtMs,
  deleted: false,
);

/// Same drift-safe teardown as the other widget tests: advance fake time so
/// the stream keep-alive timer fires before the binding asserts !timersPending.
void testApp(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(minutes: 1));
  });
}

void main() {
  group('completionRecap', () {
    // 2026-07-08 is a Wednesday; the week (Mon-first) starts 2026-07-06.
    final now = DateTime(2026, 7, 8, 12);
    int at(int day, int hour) =>
        DateTime(2026, 7, day, hour).millisecondsSinceEpoch;

    test('buckets by today / earlier this week / older', () {
      final recap = completionRecap([
        todo('this-morning', completedAtMs: at(8, 9)),
        todo('midnight-today', completedAtMs: at(8, 0)),
        todo('monday', completedAtMs: at(6, 15)), // start of this week
        todo('last-friday', completedAtMs: at(3, 15)), // before this week
      ], now);

      expect(recap.today.map((t) => t.id), ['this-morning', 'midnight-today']);
      expect(recap.thisWeek.map((t) => t.id), ['monday']);
      expect(recap.earlier.map((t) => t.id), ['last-friday']);
    });

    test('counts fold today into the week total', () {
      final recap = completionRecap([
        todo('a', completedAtMs: at(8, 9)),
        todo('b', completedAtMs: at(8, 10)),
        todo('c', completedAtMs: at(6, 10)),
        todo('d', completedAtMs: at(1, 10)),
      ], now);

      expect(recap.total, 4);
      expect(recap.today.length, 2);
      expect(recap.weekCount, 3); // two today + one earlier this week
      expect(recap.isEmpty, isFalse);
    });

    test('empty input is empty', () {
      final recap = completionRecap(const [], now);
      expect(recap.isEmpty, isTrue);
      expect(recap.total, 0);
      expect(recap.weekCount, 0);
    });

    test('rows without a completion stamp fall into older', () {
      final recap = completionRecap([todo('no-stamp')], now);
      expect(recap.earlier.map((t) => t.id), ['no-stamp']);
      expect(recap.today, isEmpty);
      expect(recap.thisWeek, isEmpty);
    });

    test('preserves input order within a bucket', () {
      final recap = completionRecap([
        todo('newest', completedAtMs: at(8, 11)),
        todo('older', completedAtMs: at(8, 9)),
      ], now);
      expect(recap.today.map((t) => t.id), ['newest', 'older']);
    });
  });

  group('completion recap UI', () {
    late AppDatabase db;
    // 2026-07-08 is a Wednesday.
    final clock = FixedClock(DateTime.utc(2026, 7, 8, 12));

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Widget app() => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('test-device'),
        clockProvider.overrideWithValue(clock),
      ],
      child: const TodoApp(),
    );

    testApp('completing a todo shows it under the recap summary', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // Add a todo, then complete it via its checkbox.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'ship the feature',
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Recap header + summary, with the item finished "today".
      expect(find.text('Completed (1)'), findsOneWidget);
      expect(find.text('1 done today · 1 this week'), findsOneWidget);

      await tester.tap(find.text('Completed (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('ship the feature'), findsOneWidget);
    });
  });
}
