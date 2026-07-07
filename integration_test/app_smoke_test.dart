import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:todoapp/app/alarm_service.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/alarm_planner.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/main.dart';

Future<void> _pumpPastDriftTeardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(minutes: 1));
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

Future<void> _deleteEventually(Directory root) async {
  for (var i = 0; i < 5; i++) {
    if (!root.existsSync()) return;
    try {
      await root.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launch add complete restart persists', (tester) async {
    final root = await Directory.systemTemp.createTemp('knot_smoke_');
    addTearDown(() async {
      await _deleteEventually(root);
    });
    final dbPath = '${root.path}${Platform.pathSeparator}smoke.sqlite';

    Future<({ProviderContainer container, AppDatabase db})> launchApp() async {
      final db = AppDatabase(NativeDatabase(File(dbPath)));
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('integration-device'),
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 7, 6, 12)),
          ),
          alarmSchedulerProvider.overrideWithValue(const NoopAlarmScheduler()),
          alarmsEnabledProvider.overrideWith((_) => false),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const TodoApp()),
      );
      await tester.pumpAndSettle();
      return (container: container, db: db);
    }

    Future<void> shutdownApp(
      ({ProviderContainer container, AppDatabase db}) session,
    ) async {
      await _pumpPastDriftTeardown(tester);
      session.container.dispose();
      await session.db.close();
    }

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    Future<void> addTodo(String title) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(dialogField, title);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
    }

    var session = await launchApp();
    expect(find.text('No todos yet — add one!'), findsOneWidget);

    await addTodo('Smoke test todo');
    await _waitFor(tester, find.text('Smoke test todo'));

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('Completed (1)'), findsOneWidget);

    await shutdownApp(session);

    session = await launchApp();
    expect(find.text('Completed (1)'), findsOneWidget);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Smoke test todo'), findsOneWidget);

    await shutdownApp(session);
  });
}
