import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/todos/todo_list_screen.dart';
import 'package:todoapp/main.dart';

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
  group('splitTodoLines', () {
    test('single line yields one element', () {
      expect(splitTodoLines('buy milk'), ['buy milk']);
    });

    test('splits on \\n, \\r\\n and \\r and trims each line', () {
      expect(splitTodoLines('buy milk\nwalk dog\r\ncall alice\rpay rent'), [
        'buy milk',
        'walk dog',
        'call alice',
        'pay rent',
      ]);
    });

    test('drops blank and whitespace-only lines', () {
      expect(splitTodoLines('  buy milk  \n\n   \n walk dog '), [
        'buy milk',
        'walk dog',
      ]);
    });
  });

  group('multi-line quick add', () {
    late AppDatabase db;
    // 2026-07-05 is a Sunday.
    final clock = FixedClock(DateTime.utc(2026, 7, 5, 12));

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

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    Future<void> openAndEnter(WidgetTester tester, String text) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(dialogField, text);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
    }

    testApp('single line adds one todo with no split prompt', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await openAndEnter(tester, 'buy milk');

      expect(find.text('Multiple lines'), findsNothing);
      expect(find.text('buy milk'), findsOneWidget);
    });

    testApp('choosing "N todos" creates one todo per line', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await openAndEnter(tester, 'buy milk\nwalk dog\ncall alice');

      // The split prompt offers to fan out to three todos.
      expect(find.text('3 todos'), findsOneWidget);
      await tester.tap(find.text('3 todos'));
      await tester.pumpAndSettle();

      expect(find.text('buy milk'), findsOneWidget);
      expect(find.text('walk dog'), findsOneWidget);
      expect(find.text('call alice'), findsOneWidget);
    });

    testApp('choosing "Single todo" collapses the paste onto one line', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await openAndEnter(tester, 'buy milk\nwalk dog');

      await tester.tap(find.text('Single todo'));
      await tester.pumpAndSettle();

      expect(find.text('buy milk walk dog'), findsOneWidget);
      expect(find.text('walk dog'), findsNothing);
    });

    testApp('dismissing the split prompt adds nothing', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await openAndEnter(tester, 'buy milk\nwalk dog');

      // Tap the barrier to dismiss without choosing.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('buy milk'), findsNothing);
      expect(find.text('walk dog'), findsNothing);
    });
  });
}
