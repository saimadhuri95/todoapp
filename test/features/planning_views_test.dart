import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/repositories/group_repository.dart';
import 'package:todoapp/data/repositories/list_repository.dart';
import 'package:todoapp/data/repositories/todo_repository.dart';
import 'package:todoapp/main.dart';

import '../support/widget_test_support.dart';

void main() {
  late AppDatabase db;
  final clock = FixedClock(DateTime.utc(2026, 7, 5, 12));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  HlcClock hlc() => HlcClock(nodeId: 'test-device', clock: clock);
  TodoRepository todos() => TodoRepository(db, hlc());
  ListRepository lists() => ListRepository(db, hlc());
  GroupRepository groups() => GroupRepository(db, hlc());

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('test-device'),
      clockProvider.overrideWithValue(clock),
    ],
    child: const TodoApp(),
  );

  Future<void> openDrawerAnd(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    final target = find.widgetWithText(ListTile, item);
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(target.last);
    await tester.pumpAndSettle();
    await tester.tap(target.last);
    await tester.pumpAndSettle();
  }

  testApp('calendar day tap filters the main list to that date', (
    tester,
  ) async {
    await todos().create(
      title: 'today call',
      dueAtMs: DateTime(2026, 7, 5, 18).millisecondsSinceEpoch,
    );
    await todos().create(
      title: 'tomorrow call',
      dueAtMs: DateTime(2026, 7, 6, 18).millisecondsSinceEpoch,
    );
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await openDrawerAnd(tester, 'Calendar');
    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('Calendar: 2026-07-05'), findsOneWidget);
    expect(find.text('today call'), findsOneWidget);
    expect(find.text('tomorrow call'), findsNothing);
  });

  testApp('saved smart list persists and filters by tag priority and date', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SavedSmartFiltersController.storageKey: jsonEncode([
        {
          'id': 'urgent-today',
          'name': 'Urgent today',
          'tag': 'urgent',
          'minPriority': 3,
          'dateFilter': 'today',
        },
      ]),
    });
    await todos().create(
      title: 'ship fix',
      dueAtMs: DateTime(2026, 7, 5, 18).millisecondsSinceEpoch,
      priority: 3,
      tags: ['urgent'],
    );
    await todos().create(
      title: 'urgent but later',
      dueAtMs: DateTime(2026, 7, 6, 18).millisecondsSinceEpoch,
      priority: 3,
      tags: ['urgent'],
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await openDrawerAnd(tester, 'Urgent today');

    expect(find.text('Smart list: Urgent today'), findsOneWidget);
    expect(find.text('ship fix'), findsOneWidget);
    expect(find.text('urgent but later'), findsNothing);
  });

  testApp('completed archive shows completed tasks beyond the recap tile', (
    tester,
  ) async {
    final work = await lists().create(name: 'Work');
    final inboxDone = await todos().create(title: 'inbox done');
    final workDone = await todos().create(title: 'work done', listId: work.id);
    await todos().complete(inboxDone.id);
    await todos().complete(workDone.id);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await openDrawerAnd(tester, 'Completed archive');

    expect(find.text('Completed archive'), findsOneWidget);
    expect(find.text('inbox done'), findsOneWidget);
    expect(find.text('work done'), findsOneWidget);
  });

  testApp('weekly review opens the Inbox step without nagging by default', (
    tester,
  ) async {
    await todos().create(title: 'loose idea');
    final work = await lists().create(name: 'Work');
    await todos().create(title: 'work task', listId: work.id);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Weekly review'), findsNothing);

    await openDrawerAnd(tester, 'Weekly review');
    expect(find.text('Process Inbox'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.open_in_new).first);
    await tester.pumpAndSettle();

    expect(find.text('loose idea'), findsOneWidget);
    expect(find.text('work task'), findsNothing);
  });

  testApp('sync affordance lives behind the drawer on the empty main list', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Pair another device'), findsNothing);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Sync settings'),
      120,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Sync settings'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Sync settings'), findsOneWidget);
  });

  testApp('drawer groups local and shared lists with badges', (tester) async {
    final family = await groups().create(name: 'Family', backendKind: 'icloud');
    await lists().create(name: 'Local errands');
    final shared = await lists().create(name: 'Groceries');
    await lists().setGroup(shared.id, family.id);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('On this device'), findsOneWidget);
    expect(find.text('Local errands'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Shared'), findsOneWidget);
    expect(find.text('iCloud shared folder'), findsOneWidget);
  });

  testApp('new list Sync selector defaults to local only', (tester) async {
    await groups().create(name: 'Family', backendKind: 'icloud');

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'New list'));
    await tester.pumpAndSettle();

    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Local only'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'List name'),
      'Inbox 2',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final row =
        await (db.todoLists.select()..where((l) => l.name.equals('Inbox 2')))
            .getSingle();
    expect(row.groupId, isNull);
  });

  testApp('editing a list confirms moving it into a sharing group', (
    tester,
  ) async {
    final family = await groups().create(name: 'Family', backendKind: 'icloud');
    await lists().create(name: 'Groceries');

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Groceries'),
        matching: find.byTooltip('Edit list'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local only').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Family').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('People who already received'), findsOneWidget);
    await tester.tap(find.text('Move list'));
    await tester.pumpAndSettle();

    final row =
        await (db.todoLists.select()..where((l) => l.name.equals('Groceries')))
            .getSingle();
    expect(row.groupId, family.id);
  });
}
