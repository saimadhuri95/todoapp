import 'dart:convert';

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
import 'package:todoapp/features/todos/todo_editor.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late TodoRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime.utc(2026, 7, 8, 12));
    repo = TodoRepository(db, HlcClock(nodeId: 'test-device', clock: clock));
  });

  tearDown(() => db.close());

  Widget screen(Todo todo) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('test-device'),
      clockProvider.overrideWithValue(clock),
    ],
    child: MaterialApp(home: TodoEditorScreen(todo: todo)),
  );

  testWidgets('breaks a task into subtasks and saves a reset template', (
    tester,
  ) async {
    final parent = await repo.create(title: 'Launch prep');

    await tester.pumpWidget(screen(parent));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Break down'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Break down'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Draft outline\nSend invite',
    );
    await tester.tap(find.text('Create checklist'));
    await tester.pumpAndSettle();

    expect(find.text('Draft outline'), findsOneWidget);
    expect(find.text('Send invite'), findsOneWidget);
    expect(find.text('0 of 2 complete'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Draft outline'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 complete'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Save as template'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save as template'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Launch checklist',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save'),
      ),
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ChecklistTemplatesController.storageKey);
    expect(raw, isNotNull);
    final stored = jsonDecode(raw!) as List<dynamic>;
    expect(stored.single, containsPair('name', 'Launch checklist'));
    expect(
      stored.single,
      containsPair('subtasks', ['Send invite', 'Draft outline']),
    );
    expect(raw, isNot(contains('completedAtMs')));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(minutes: 1));
  });
}
