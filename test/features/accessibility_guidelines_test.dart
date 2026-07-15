import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/todos/todo_list_screen.dart';

/// Automated accessibility guideline checks (issue #154, TASKS.md 5.5).
///
/// These exercise Flutter's built-in [meetsGuideline] matchers — WCAG AA text
/// contrast and tap-target labelling — plus a large font-scale smoke test on
/// the home screen. They cover the *mechanical* portion of the accessibility
/// pass so the manual, real-device screen-reader pass (#27: VoiceOver /
/// TalkBack / NVDA) can focus on what only a human on a device can judge.
///
/// The tap-target *size* guidelines (androidTapTargetGuideline /
/// iOSTapTargetGuideline) are deliberately not asserted here: an inline text
/// field (the search bar) legitimately produces a sub-48dp semantic node for
/// its text baseline, which the guideline flags as a false positive. Tap-target
/// sizing on the real controls (FAB, icon buttons) uses standard Material sizes
/// and is confirmed in the manual pass.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final clock = FixedClock(DateTime.utc(2026, 7, 6, 12));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('a11y-guidelines-device'),
        clockProvider.overrideWithValue(clock),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seedTodos() async {
    final repo = container.read(todoRepositoryProvider);
    await repo.create(title: 'Buy groceries');
    await repo.create(
      title: 'Call the dentist',
      dueAtMs: clock.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
      priority: 3,
    );
  }

  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness, useMaterial3: true),
          home: child,
        ),
      );

  for (final brightness in Brightness.values) {
    testWidgets('todo list meets a11y guidelines (${brightness.name})', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await seedTodos();

      await tester.pumpWidget(
        host(const TodoListScreen(), brightness: brightness),
      );
      await tester.pumpAndSettle();

      // Every interactive control carries a semantic label...
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      // ...and text clears the WCAG AA contrast bar against its background.
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      handle.dispose();
      await _settleDrift(tester);
    });
  }

  testWidgets('todo list survives 1.5x font scaling without overflow', (
    tester,
  ) async {
    await seedTodos();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: const TodoListScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A RenderFlex overflow reports through the framework as a caught
    // exception; assert none fired while the list was laid out large.
    expect(tester.takeException(), isNull);

    await _settleDrift(tester);
  });
}

/// Advance fake time so drift's stream keep-alive timer fires before the
/// binding asserts there are no pending timers on teardown (mirrors the
/// helper in accessibility_screens_test.dart).
Future<void> _settleDrift(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(minutes: 1));
}
