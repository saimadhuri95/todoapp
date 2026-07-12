import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/alarm_service.dart';
import 'package:todoapp/app/focus_timer.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/alarm_planner.dart';
import 'package:todoapp/core/clock.dart';

class FakeScheduler implements AlarmScheduler {
  final infos = <({String title, String body})>[];

  @override
  Future<void> replaceAll(List<AlarmInstance> alarms) async {}

  @override
  Future<void> showInfo({required String title, required String body}) async {
    infos.add((title: title, body: body));
  }
}

void main() {
  late FakeScheduler scheduler;
  late ProviderContainer container;

  final now = DateTime.utc(2026, 7, 6, 12);

  ProviderContainer buildContainer({bool alarmsEnabled = true}) =>
      ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FixedClock(now)),
          alarmSchedulerProvider.overrideWithValue(scheduler),
          alarmsEnabledProvider.overrideWith((_) => alarmsEnabled),
        ],
      );

  setUp(() => scheduler = FakeScheduler());
  tearDown(() => container.dispose());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 100));

  test('start sets a session ending after the given duration', () {
    container = buildContainer();
    final controller = container.read(focusTimerProvider.notifier);

    controller.start(
      todoId: 't1',
      todoTitle: 'Write report',
      duration: const Duration(minutes: 25),
    );

    final session = container.read(focusTimerProvider);
    expect(session, isNotNull);
    expect(session!.todoId, 't1');
    expect(session.endAt, now.add(const Duration(minutes: 25)));
  });

  test('cancel clears the session and the pending timer', () async {
    container = buildContainer();
    final controller = container.read(focusTimerProvider.notifier);
    controller.start(
      todoId: 't1',
      todoTitle: 'x',
      duration: const Duration(milliseconds: 20),
    );

    controller.cancel();
    await settle();

    expect(container.read(focusTimerProvider), isNull);
    expect(scheduler.infos, isEmpty); // cancelled before it could fire
  });

  test(
    'firing the timer shows an info notification and clears state',
    () async {
      container = buildContainer();
      final controller = container.read(focusTimerProvider.notifier);

      controller.start(
        todoId: 't1',
        todoTitle: 'Write report',
        duration: const Duration(milliseconds: 20),
      );
      await settle();

      expect(container.read(focusTimerProvider), isNull);
      expect(scheduler.infos, hasLength(1));
      expect(scheduler.infos.single.body, 'Write report');
    },
  );

  test('starting a new session replaces the running one', () async {
    container = buildContainer();
    final controller = container.read(focusTimerProvider.notifier);

    controller.start(
      todoId: 'first',
      todoTitle: 'first',
      duration: const Duration(milliseconds: 20),
    );
    controller.start(
      todoId: 'second',
      todoTitle: 'second',
      duration: const Duration(minutes: 10),
    );
    await settle();

    // The first timer was cancelled, so it never fired.
    expect(scheduler.infos, isEmpty);
    expect(container.read(focusTimerProvider)!.todoId, 'second');
  });
}
