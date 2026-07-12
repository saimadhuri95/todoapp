import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/alarm_planner.dart';
import '../core/platform_info.dart';
import 'providers.dart';

/// Whether alarms ring on this device: mobile default-on, desktop opt-in
/// (docs/alarms.md policy). Seeded from prefs in main(); the settings
/// toggle writes both.
final alarmsEnabledProvider = StateProvider<bool>((_) => defaultAlarmsEnabled);

/// The platform scheduler; overridden in main() with the real
/// implementation and in tests with fakes. Defaults to no-op.
final alarmSchedulerProvider = Provider<AlarmScheduler>(
  (_) => const NoopAlarmScheduler(),
);

/// Keeps the OS notification schedule in sync with the database
/// (TASKS.md 2.4 refill / 2.9 rescheduling / 3.15 remote dismissals):
/// any todos change — local edit or applied sync — triggers a replan.
class AlarmService {
  AlarmService(this._ref, {this.debounce = const Duration(seconds: 1)});

  final Ref _ref;
  final Duration debounce;

  StreamSubscription<void>? _mutations;
  Timer? _debounceTimer;

  Future<void> start() async {
    _mutations = _ref.read(databaseProvider).tableUpdates().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, replan);
    });
    // The settings toggle calls replan() explicitly after flipping
    // alarmsEnabledProvider (Ref.listen is build-time only).
    await replan();
  }

  /// Recomputes the full plan and hands it to the scheduler.
  Future<void> replan() async {
    final scheduler = _ref.read(alarmSchedulerProvider);
    if (!_ref.read(alarmsEnabledProvider)) {
      await scheduler.replaceAll(const []);
      return;
    }
    final db = _ref.read(databaseProvider);
    final todos =
        await (db.todos.select()..where(
              (t) => t.deleted.equals(false) & t.completedAtMs.isNull(),
            ))
            .get();
    // Attribution (TASKS.md 6.51) only for todos on a shared list — most
    // todos are local-only and this is one query per candidate.
    final lists = await db.todoLists.select().get();
    final sharedListIds = {
      for (final list in lists)
        if (list.groupId != null) list.id,
    };
    final repo = _ref.read(todoRepositoryProvider);
    final changedByTodoId = <String, String>{};
    for (final todo in todos) {
      if (!sharedListIds.contains(todo.listId)) continue;
      final changedBy = await repo.lastChangedBy(todo.id);
      if (changedBy != null) changedByTodoId[todo.id] = changedBy;
    }
    await scheduler.replaceAll(
      planAlarms(
        todos,
        now: _ref.read(clockProvider).now(),
        changedByTodoId: changedByTodoId,
      ),
    );
  }

  void stop() {
    _mutations?.cancel();
    _debounceTimer?.cancel();
  }
}

final alarmServiceProvider = Provider<AlarmService>(AlarmService.new);
