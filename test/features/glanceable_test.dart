import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/repositories/todo_repository.dart';
import 'package:todoapp/main.dart';

/// Same drift-safe teardown as widget_test.dart (see comment there).
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

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('test-device'),
      clockProvider.overrideWithValue(clock),
    ],
    child: const TodoApp(),
  );

  testApp('glanceable mode enlarges list type and persists', (tester) async {
    await TodoRepository(
      db,
      HlcClock(nodeId: 'test-device', clock: clock),
    ).create(title: 'Buy milk');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Standard density: tile title uses the default (unstyled) text.
    expect(tester.widget<Text>(find.text('Buy milk')).style, isNull);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Glanceable mode'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Buy milk'));
    expect(
      tester.widget<Text>(find.text('Buy milk')).style?.fontSize,
      Theme.of(context).textTheme.titleLarge?.fontSize,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('displayDensity'), 'large');
  });
}
