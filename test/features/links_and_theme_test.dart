import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/todos/linkified_text.dart';
import 'package:todoapp/main.dart';

/// Same drift-safe teardown as widget_test.dart: advance fake time so the
/// stream keep-alive timer fires before the binding asserts !timersPending.
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
  late List<Uri> opened;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    opened = [];
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('test-device'),
      clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 7, 6))),
      urlOpenerProvider.overrideWithValue(opened.add),
    ],
    child: const TodoApp(),
  );

  final dialogField = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  Future<void> addTodo(WidgetTester tester, String title) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(dialogField, title);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  testApp('tapping a URL in a todo tile opens it, not the editor', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'https://example.com/doc');

    await tester.tap(find.byType(LinkifiedText));
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse('https://example.com/doc')]);
    expect(find.text('Edit todo'), findsNothing);
  });

  testApp('plain titles still open the editor on tap', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'walk dog');

    await tester.tap(find.byType(LinkifiedText));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(find.text('Edit todo'), findsOneWidget);
  });

  testApp('editor shows an open-link chip for URLs typed into notes', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'read spec');
    await tester.tap(find.text('read spec'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Notes'),
      'draft at https://example.org/spec',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ActionChip));
    expect(opened, [Uri.parse('https://example.org/spec')]);
  });

  testApp('theme setting switches themeMode and persists', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    ThemeMode? mode() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;
    expect(mode(), ThemeMode.system);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    expect(mode(), ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('themeMode'), 'dark');
  });
}
