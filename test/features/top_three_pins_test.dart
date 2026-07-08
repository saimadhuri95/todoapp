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
  late AppDatabase db;
  final clock = FixedClock(DateTime.utc(2026, 7, 5, 12));

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  HlcClock hlc() => HlcClock(nodeId: 'test-device', clock: clock);
  TodoRepository todos() => TodoRepository(db, hlc());

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('test-device'),
      clockProvider.overrideWithValue(clock),
    ],
    child: const TodoApp(),
  );

  testApp('pinning a todo moves it under a Top 3 header', (tester) async {
    final t = await todos().create(title: 'ship release');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Top 3'), findsNothing);

    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Top 3'), findsOneWidget);
    expect((await todos().getById(t.id))!.pinned, isTrue);

    // Unpin via the now-filled pin icon.
    await tester.tap(find.byIcon(Icons.push_pin));
    await tester.pumpAndSettle();

    expect(find.text('Top 3'), findsNothing);
    expect((await todos().getById(t.id))!.pinned, isFalse);
  });

  testApp('a fourth pin is refused with a hint', (tester) async {
    for (final title in ['a', 'b', 'c', 'd']) {
      await todos().create(title: title);
    }
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Pin the first three.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.push_pin_outlined).first);
      await tester.pumpAndSettle();
    }
    expect(find.byIcon(Icons.push_pin), findsNWidgets(3));

    // The fourth attempt is blocked and hints at the cap.
    await tester.tap(find.byIcon(Icons.push_pin_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('You can pin up to 3 todos'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin), findsNWidgets(3));
    final pinnedCount = (await todos().watchActive().first)
        .where((t) => t.pinned)
        .length;
    expect(pinnedCount, 3);
  });
}
