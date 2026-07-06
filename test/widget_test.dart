import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/main.dart';

/// testWidgets + drift-safe teardown. Drift schedules a stream keep-alive
/// Timer in the fake-async zone once the tree unmounts and riverpod cancels
/// its stream subscriptions; without advancing fake time that timer never
/// fires, the binding asserts `!timersPending`, and tearDown's db.close()
/// deadlocks waiting on the stream store.
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

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('test-device'),
      clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 7, 5))),
    ],
    child: const TodoApp(),
  );

  // The SearchBar contains its own TextField, so dialog fields must be
  // scoped to the dialog.
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

  testApp('shows empty state, adds a todo via FAB dialog', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('No todos yet — add one!'), findsOneWidget);

    await addTodo(tester, 'Buy milk');

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('No todos yet — add one!'), findsNothing);
  });

  testApp('completing a todo removes it from the active list', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Walk dog');

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('Walk dog'), findsNothing);
    // Not the empty state: the collapsed Completed section holds it now.
    expect(find.text('Completed (1)'), findsOneWidget);
  });

  testApp('swipe-to-dismiss soft-deletes', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Old task');

    await tester.drag(find.text('Old task'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Old task'), findsNothing);
    // Tombstoned, not hard-deleted.
    final rows = await db.todos.all().get();
    expect(rows.single.deleted, isTrue);
  });

  testApp('settings screen opens from the app bar', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Enable alarms on this device'), findsOneWidget);
    expect(find.text('Sync & devices'), findsOneWidget);
  });

  testApp('cancel and empty title do not create todos', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await addTodo(tester, '   ');

    expect(find.text('No todos yet — add one!'), findsOneWidget);
  });

  testApp('todos group under section headers', (tester) async {
    // FixedClock pins "now" to 2026-07-05 00:00 UTC.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'floaty'); // no due date → Someday

    expect(find.text('Someday'), findsOneWidget);
    expect(find.text('Overdue'), findsNothing);
  });

  testApp('editor edits title, notes, and priority', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Draft');

    await tester.tap(find.text('Draft'));
    await tester.pumpAndSettle();
    expect(find.text('Edit todo'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Draft'),
      'Final title',
    );
    await tester.tap(find.text('High'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Back on the list with the new title.
    expect(find.text('Final title'), findsOneWidget);
    final row = await db.todos.all().getSingle();
    expect(row.title, 'Final title');
    expect(row.priority, 3);
  });

  testApp('search filters the list', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Buy milk');
    await addTodo(tester, 'Walk dog');

    await tester.enterText(find.byType(SearchBar), 'milk');
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Walk dog'), findsNothing);
  });

  testApp('completed section shows and can uncomplete', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Done deal');

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('Completed (1)'), findsOneWidget);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    expect(find.text('Completed (1)'), findsNothing);
    expect(find.text('Done deal'), findsOneWidget);
  });

  testApp('wide layout shows detail pane on tap instead of a route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Select a todo'), findsOneWidget);

    await addTodo(tester, 'Split view');
    await tester.tap(find.text('Split view'));
    await tester.pumpAndSettle();

    // Editor embedded, not pushed: list screen elements still visible.
    expect(find.text('Edit todo'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testApp('drawer creates a list and filters by it', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await addTodo(tester, 'Unfiled todo');

    final scaffold = find.byType(Scaffold).first;
    tester.state<ScaffoldState>(scaffold).openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogField, 'Work');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    // Filtered to the empty Work list.
    expect(find.text('Unfiled todo'), findsNothing);
  });
}
