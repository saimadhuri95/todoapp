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

  Future<void> openDrawerAnd(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
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
}
