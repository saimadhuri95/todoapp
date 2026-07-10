import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/repositories/todo_repository.dart';
import 'package:todoapp/main.dart';

/// Same drift-safe teardown as the other widget tests.
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

  TodoRepository todos() =>
      TodoRepository(db, HlcClock(nodeId: 'test-device', clock: clock));

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('test-device'),
      clockProvider.overrideWithValue(clock),
    ],
    child: const TodoApp(),
  );

  testApp('"I have 10 minutes" narrows to short estimated todos', (
    tester,
  ) async {
    final repo = todos();
    await repo.edit(
      (await repo.create(title: 'quick call')).id,
      estimateMinutes: const Value(5),
    );
    await repo.create(title: 'deep work'); // unestimated
    await repo.edit(
      (await repo.create(title: 'long errand')).id,
      estimateMinutes: const Value(45),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // All three visible before filtering.
    expect(find.text('quick call'), findsOneWidget);
    expect(find.text('deep work'), findsOneWidget);
    expect(find.text('long errand'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'I have 10 minutes'));
    await tester.pumpAndSettle();

    expect(find.text('quick call'), findsOneWidget);
    expect(find.text('deep work'), findsNothing);
    expect(find.text('long errand'), findsNothing);
  });
}
