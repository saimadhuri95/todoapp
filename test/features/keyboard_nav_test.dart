import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/main.dart';

import '../support/widget_test_support.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('kbd-device'),
      clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 7, 6))),
    ],
    child: const TodoApp(),
  );

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = true,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(key);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  testApp('Ctrl+N opens the quick-add dialog (5.5)', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await press(tester, LogicalKeyboardKey.keyN);

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testApp('Ctrl+, opens Settings (5.5)', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await press(tester, LogicalKeyboardKey.comma);

    // The settings screen's first section heading.
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
  });

  testApp('Ctrl+F focuses the search field (5.5)', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Nothing focused into a text field yet.
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );

    await press(tester, LogicalKeyboardKey.keyF);

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });
}
