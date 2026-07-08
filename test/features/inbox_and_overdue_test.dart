import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/repositories/list_repository.dart';
import 'package:todoapp/data/repositories/todo_repository.dart';
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
  // 2026-07-05 is a Sunday.
  final clock = FixedClock(DateTime.utc(2026, 7, 5, 12));

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  HlcClock hlc() => HlcClock(nodeId: 'test-device', clock: clock);
  TodoRepository todos() => TodoRepository(db, hlc());
  ListRepository lists() => ListRepository(db, hlc());

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('test-device'),
      clockProvider.overrideWithValue(clock),
    ],
    child: const TodoApp(),
  );

  Future<void> backdateTodo(String id, DateTime when) async {
    await db.customStatement(
      'UPDATE field_clocks SET hlc = ? WHERE entity = ? AND row_id = ?',
      [
        Hlc(when.millisecondsSinceEpoch, 0, 'test-device').encode(),
        'todos',
        id,
      ],
    );
  }

  Future<void> openDrawerAnd(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, item).last);
    await tester.pumpAndSettle();
  }

  testApp('Inbox drawer entry shows only unfiled todos', (tester) async {
    final errands = await lists().create(name: 'Errands');
    await todos().create(title: 'buy nails', listId: errands.id);
    await todos().create(title: 'loose thought');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // All-todos view shows both.
    expect(find.text('buy nails'), findsOneWidget);
    expect(find.text('loose thought'), findsOneWidget);

    await openDrawerAnd(tester, 'Inbox');

    expect(find.text('loose thought'), findsOneWidget);
    expect(find.text('buy nails'), findsNothing);
  });

  testApp('move-to-list button files an Inbox todo', (tester) async {
    final errands = await lists().create(name: 'Errands');
    final loose = await todos().create(title: 'loose thought');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.drive_file_move_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Errands'));
    await tester.pumpAndSettle();

    final row = await todos().getById(loose.id);
    expect(row!.listId, errands.id);
    // Filed → the triage affordance goes away.
    expect(find.byIcon(Icons.drive_file_move_outlined), findsNothing);
  });

  testApp('no triage button on filed todos or without lists', (tester) async {
    await todos().create(title: 'loose thought');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Unfiled todo but no lists yet → nothing to move to.
    expect(find.byIcon(Icons.drive_file_move_outlined), findsNothing);
  });

  testApp('overdue todos sit in Today with a subtle since-tag', (tester) async {
    await todos().create(
      title: 'pay rent',
      dueAtMs: DateTime(2026, 7, 4, 9).millisecondsSinceEpoch, // Saturday
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Overdue'), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('since Sat'), findsOneWidget);
  });

  testApp('Someday drawer view shows only no-date tasks', (tester) async {
    await todos().create(title: 'maybe later');
    await todos().create(
      title: 'today first',
      dueAtMs: DateTime(2026, 7, 5, 18).millisecondsSinceEpoch,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await openDrawerAnd(tester, 'Someday');

    expect(find.text('maybe later'), findsOneWidget);
    expect(find.text('today first'), findsNothing);
  });

  testApp('overdue amnesty sweeps overdue tasks to tomorrow', (tester) async {
    final overdue = await todos().create(
      title: 'pay rent',
      dueAtMs: DateTime(2026, 7, 4, 9).millisecondsSinceEpoch,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('1 overdue task could use a reset'), findsOneWidget);

    await tester.tap(find.text('Sweep'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to tomorrow'));
    await tester.pumpAndSettle();

    final row = await todos().getById(overdue.id);
    final due = DateTime.fromMillisecondsSinceEpoch(row!.dueAtMs!);
    expect(DateTime(due.year, due.month, due.day), DateTime(2026, 7, 6));
    expect(find.text('since Sat'), findsNothing);
  });

  testApp('stale review can park untouched tasks in Someday', (tester) async {
    final stale = await todos().create(
      title: 'old maybe',
      dueAtMs: DateTime(2026, 6, 1, 9).millisecondsSinceEpoch,
    );
    await backdateTodo(stale.id, DateTime.utc(2026, 5, 1, 8));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Review tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review stale tasks (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Someday'));
    await tester.pumpAndSettle();

    expect((await todos().getById(stale.id))!.dueAtMs, isNull);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    await openDrawerAnd(tester, 'Someday');

    expect(find.text('old maybe'), findsOneWidget);
  });
}
