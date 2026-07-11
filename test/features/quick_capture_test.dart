import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/app/quick_capture.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
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
  late ProviderContainer container;
  final clock = FixedClock(DateTime.utc(2026, 7, 6, 12));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('capture-device'),
        clockProvider.overrideWithValue(clock),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget app() =>
      UncontrolledProviderScope(container: container, child: const TodoApp());

  testApp('a capture request opens the quick-add dialog on the list screen', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // What the global hotkey / launcher shortcut does (TASKS.md 6.14).
    container.read(quickCaptureRequestsProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
  });

  test('the service bumps the request provider on capture', () {
    final before = container.read(quickCaptureRequestsProvider);
    // Drive the callback the platform triggers invoke, without platform
    // channels: hotkey and launcher shortcuts both call onCapture.
    container.read(quickCaptureServiceProvider).onCapture();
    expect(container.read(quickCaptureRequestsProvider), before + 1);
  });
}
