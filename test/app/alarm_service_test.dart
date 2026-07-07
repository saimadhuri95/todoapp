import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/alarm_service.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/alarm_planner.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';

class FakeScheduler implements AlarmScheduler {
  final plans = <List<AlarmInstance>>[];
  final infos = <({String title, String body})>[];

  @override
  Future<void> replaceAll(List<AlarmInstance> alarms) async =>
      plans.add(alarms);

  @override
  Future<void> showInfo({required String title, required String body}) async {
    infos.add((title: title, body: body));
  }

  List<AlarmInstance> get latest => plans.isEmpty ? const [] : plans.last;
}

/// Short-debounce service for tests.
final _testAlarmServiceProvider = Provider<AlarmService>(
  (ref) => AlarmService(ref, debounce: const Duration(milliseconds: 50)),
);

void main() {
  late AppDatabase db;
  late FakeScheduler scheduler;
  late ProviderContainer container;
  late AlarmService service;

  final now = DateTime.utc(2026, 7, 6, 12);
  int inMin(int m) => now.add(Duration(minutes: m)).millisecondsSinceEpoch;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    scheduler = FakeScheduler();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('test-device'),
        clockProvider.overrideWithValue(FixedClock(now)),
        alarmSchedulerProvider.overrideWithValue(scheduler),
        alarmsEnabledProvider.overrideWith((_) => true),
      ],
    );
    service = container.read(_testAlarmServiceProvider);
    await service.start();
  });

  tearDown(() async {
    service.stop();
    container.dispose();
    await db.close();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  test('mutations trigger a debounced replan with the right alarms', () async {
    expect(scheduler.latest, isEmpty); // initial replan, no todos

    final repo = container.read(todoRepositoryProvider);
    final todo = await repo.create(title: 'ring me', dueAtMs: inMin(30));
    await repo.edit(todo.id, alarmOffsetsMinutes: const Value([0, 10]));
    await settle();

    expect(scheduler.latest, hasLength(2));
    expect(scheduler.latest.first.fireAtMs, inMin(20));
    expect(scheduler.latest.first.title, 'ring me');
  });

  test('completing a todo clears its alarms on the next replan', () async {
    final repo = container.read(todoRepositoryProvider);
    final todo = await repo.create(title: 't', dueAtMs: inMin(30));
    await repo.edit(todo.id, alarmOffsetsMinutes: const Value([0]));
    await settle();
    expect(scheduler.latest, hasLength(1));

    await repo.complete(todo.id);
    await settle();
    expect(scheduler.latest, isEmpty);
  });

  test(
    'dismissal (incl. one applied from sync) removes the occurrence',
    () async {
      final repo = container.read(todoRepositoryProvider);
      final todo = await repo.create(title: 't', dueAtMs: inMin(30));
      await repo.edit(todo.id, alarmOffsetsMinutes: const Value([0]));
      await settle();
      expect(scheduler.latest, hasLength(1));

      // Same code path as a remote dismissal: a field write on todos.
      await repo.dismissAlarm(todo.id, inMin(30));
      await settle();
      expect(scheduler.latest, isEmpty);
    },
  );

  test('disabled toggle empties the schedule', () async {
    final repo = container.read(todoRepositoryProvider);
    final todo = await repo.create(title: 't', dueAtMs: inMin(30));
    await repo.edit(todo.id, alarmOffsetsMinutes: const Value([0]));
    await settle();
    expect(scheduler.latest, hasLength(1));

    container.read(alarmsEnabledProvider.notifier).state = false;
    await service.replan();
    expect(scheduler.latest, isEmpty);
  });
}
