import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/main.dart';

/// Accessibility pass (TASKS.md 5.5): the todo list must be usable with a
/// screen reader and keyboard, not just touch gestures.
void testApp(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(minutes: 1));
  });
}

void main() {
  late AppDatabase db;
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

  Future<void> addTodo(WidgetTester tester, String text) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  testApp('completion checkbox and drag handle carry semantic labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'buy milk');

    expect(find.bySemanticsLabel('Mark "buy milk" complete'), findsOneWidget);
    expect(find.bySemanticsLabel('Reorder "buy milk"'), findsOneWidget);
    semantics.dispose();
  });

  testApp('delete is reachable from the actions menu, not only swipe', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'buy milk');

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // The row is gone (tombstoned) — no longer in the active list.
    expect(find.text('buy milk'), findsNothing);
  });

  testApp('section headers are exposed as headings', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'buy milk today');

    expect(
      tester
          .getSemantics(find.text('Today'))
          .getSemanticsData()
          .flagsCollection
          .isHeader,
      isTrue,
    );
    semantics.dispose();
  });
}
