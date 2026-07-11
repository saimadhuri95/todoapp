import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/todos/eisenhower_screen.dart';
import 'package:todoapp/features/todos/todo_editor.dart';

/// Accessibility pass beyond the list (TASKS.md 5.5): the editor and the
/// priority matrix expose group headings so screen-reader users get context.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final clock = FixedClock(DateTime.utc(2026, 7, 6, 12));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('a11y-device'),
        clockProvider.overrideWithValue(clock),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget host(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: Scaffold(body: child)),
  );

  bool isHeading(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).getSemanticsData().flagsCollection.isHeader;

  testWidgets('editor groups priority and reminders with semantic labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final todo = await container
        .read(todoRepositoryProvider)
        .create(
          title: 'plan trip',
          dueAtMs: clock.now().millisecondsSinceEpoch,
        );

    await tester.pumpWidget(host(TodoEditor(todo: todo)));
    await tester.pumpAndSettle();

    // Screen-reader group labels, added without visible headings so the
    // form's layout is unchanged. Reminders shows only with a due date.
    expect(find.bySemanticsLabel('Priority'), findsOneWidget);
    expect(find.bySemanticsLabel('Reminders'), findsOneWidget);

    semantics.dispose();
    await _settleDrift(tester);
  });

  testWidgets('the priority matrix exposes quadrant titles as headings', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await container
        .read(todoRepositoryProvider)
        .create(
          title: 'urgent important',
          priority: 3,
          dueAtMs: clock
              .now()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        );

    await tester.pumpWidget(host(const EisenhowerScreen()));
    await tester.pumpAndSettle();

    expect(isHeading(tester, find.text('Do first (1)')), isTrue);

    semantics.dispose();
    await _settleDrift(tester);
  });
}

/// Advance fake time so drift's stream keep-alive timer fires before the
/// binding asserts there are no pending timers on teardown.
Future<void> _settleDrift(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(minutes: 1));
}
