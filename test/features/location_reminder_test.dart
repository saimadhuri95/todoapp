import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/todos/todo_editor.dart';

/// Drift-safe teardown: settle the stream keep-alive timer before the
/// binding asserts !timersPending.
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

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('loc-device'),
        clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 7, 6))),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testApp('editor saves and clears a location reminder (6.50)', (tester) async {
    // Tall viewport so the whole editor form is laid out without scrolling.
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = container.read(todoRepositoryProvider);
    final todo = await repo.create(title: 'Buy milk');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: TodoEditor(todo: todo))),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Place name'), 'Home');
    await tester.enterText(find.widgetWithText(TextField, 'Latitude'), '40.5');
    await tester.enterText(find.widgetWithText(TextField, 'Longitude'), '-74.2');
    await tester.enterText(find.widgetWithText(TextField, 'Radius m'), '200');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    var row = (await repo.getById(todo.id))!;
    expect(row.geofenceLat, 40.5);
    expect(row.geofenceLng, -74.2);
    expect(row.geofenceRadiusM, 200);
    expect(row.geofenceLabel, 'Home');

    // Clearing the coordinates removes the reminder on the next save.
    await tester.enterText(find.widgetWithText(TextField, 'Latitude'), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    row = (await repo.getById(todo.id))!;
    expect(row.geofenceLat, isNull);
    expect(row.geofenceRadiusM, isNull);
    expect(row.geofenceLabel, isNull);
  });
}
