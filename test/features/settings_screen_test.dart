import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todoapp/app/alarm_service.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/alarm_planner.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/settings/settings_screen.dart';

import '../support/widget_test_support.dart';

class RecordingScheduler implements AlarmScheduler {
  final plans = <List<AlarmInstance>>[];

  @override
  Future<void> replaceAll(List<AlarmInstance> alarms) async =>
      plans.add(alarms);

  @override
  Future<void> showInfo({required String title, required String body}) async {}

  List<AlarmInstance> get latest => plans.isEmpty ? const [] : plans.last;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late RecordingScheduler scheduler;
  final now = DateTime.utc(2026, 7, 6, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    scheduler = RecordingScheduler();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('settings-device'),
        clockProvider.overrideWithValue(FixedClock(now)),
        alarmSchedulerProvider.overrideWithValue(scheduler),
        alarmsEnabledProvider.overrideWith((_) => true),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget screen() => UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: SettingsScreen()),
  );

  testApp('renders settings sections and opens sync settings', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    // The sectioned list is longer than the fold; scroll to reach the data
    // controls near the bottom, then back up to the Sync tile.
    final settingsList = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Import todos'),
      120,
      scrollable: settingsList,
    );
    expect(find.text('Import todos'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sync & devices'),
      -120,
      scrollable: settingsList,
    );
    await tester.tap(find.text('Sync & devices'));
    await tester.pumpAndSettle();

    expect(find.text('Show pairing invitation'), findsOneWidget);
    // The macOS-only iCloud + scan tiles push the button below the fold.
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('Sync now'), findsOneWidget);
  });

  testApp('settings are grouped under section headings (5.5)', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;
    for (final section in const [
      'Appearance',
      'Reminders',
      'Sync & sharing',
      'Data & backup',
    ]) {
      await tester.scrollUntilVisible(
        find.text(section),
        100,
        scrollable: list,
      );
      expect(
        tester
            .getSemantics(find.text(section))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
        reason: '"$section" should be a heading',
      );
    }
    semantics.dispose();
  });

  testApp('accent color picker updates the theme seed and persists', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Accent color'), findsOneWidget);
    expect(container.read(accentColorProvider), accentColorChoices.first);

    // Pick the second swatch.
    final target = accentColorChoices[1];
    await tester.tap(find.byKey(ValueKey(target)));
    await tester.pumpAndSettle();

    expect(container.read(accentColorProvider), target);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('accentColor'), 1);
  });

  testApp('disabling alarms persists the toggle and clears the schedule', (
    tester,
  ) async {
    final repo = container.read(todoRepositoryProvider);
    final todo = await repo.create(
      title: 'Ring soon',
      dueAtMs: now.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
    );
    await repo.edit(todo.id, alarmOffsetsMinutes: const Value([0]));
    await container.read(alarmServiceProvider).replan();
    expect(scheduler.latest, hasLength(1));

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    final alarmsTile = find.ancestor(
      of: find.text('Enable alarms on this device'),
      matching: find.byType(SwitchListTile),
    );
    await tester.tap(
      find.descendant(of: alarmsTile, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(container.read(alarmsEnabledProvider), isFalse);
    expect(scheduler.latest, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('alarmsEnabled'), isFalse);
  });
}
