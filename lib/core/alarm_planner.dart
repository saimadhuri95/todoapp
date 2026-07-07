import '../data/db/database.dart';
import '../data/repositories/todo_repository.dart';
import 'recurrence.dart';

/// One concrete moment a notification should fire.
class AlarmInstance implements Comparable<AlarmInstance> {
  const AlarmInstance({
    required this.todoId,
    required this.title,
    required this.fireAtMs,
    required this.occurrenceMs,
  });

  final String todoId;
  final String title;

  /// When to ring.
  final int fireAtMs;

  /// The due occurrence this alarm belongs to — what [dismissAlarm]
  /// records, so all offsets (and all devices) silence together.
  final int occurrenceMs;

  @override
  int compareTo(AlarmInstance other) => fireAtMs.compareTo(other.fireAtMs);

  @override
  String toString() => '$todoId@$fireAtMs(occ $occurrenceMs)';
}

/// Where platform scheduling plugs in (TASKS.md 2.1). Implementations:
/// local-notifications (mobile/desktop), in-app timers (Linux fallback),
/// [NoopAlarmScheduler] for tests and the disabled state.
abstract interface class AlarmScheduler {
  /// Replace everything previously scheduled with [alarms] (already
  /// sorted, already capped). Idempotent by construction.
  Future<void> replaceAll(List<AlarmInstance> alarms);

  /// Show one immediate informational notification.
  Future<void> showInfo({required String title, required String body});
}

class NoopAlarmScheduler implements AlarmScheduler {
  const NoopAlarmScheduler();

  @override
  Future<void> replaceAll(List<AlarmInstance> alarms) async {}

  @override
  Future<void> showInfo({required String title, required String body}) async {}
}

/// Pure planning (TASKS.md 2.4/2.9/2.10 logic): given the todos, compute
/// the next [cap] alarm instances. Re-running this after any change *is*
/// the iOS refill strategy — the cap keeps us under the 64-pending limit.
List<AlarmInstance> planAlarms(
  List<Todo> todos, {
  required DateTime now,
  int cap = 50,
  Duration horizon = const Duration(days: 365),
}) {
  final nowMs = now.millisecondsSinceEpoch;
  final horizonMs = nowMs + horizon.inMilliseconds;
  final planned = <AlarmInstance>[];

  for (final todo in todos) {
    if (todo.deleted || todo.completedAtMs != null) continue;

    final snooze = todo.snoozeUntilMs;
    if (snooze != null && snooze > nowMs) {
      planned.add(
        AlarmInstance(
          todoId: todo.id,
          title: todo.title,
          fireAtMs: snooze,
          occurrenceMs: snooze,
        ),
      );
    }

    final offsets = todo.alarmOffsetsMinutes;
    final dueMs = todo.dueAtMs;
    if (offsets.isEmpty || dueMs == null) continue;
    final maxOffsetMs = offsets.reduce((a, b) => a > b ? a : b) * 60000;

    for (final occurrenceMs in _occurrences(
      todo,
      dueMs,
      // An occurrence still matters if any of its offsets is in the future.
      afterMs: nowMs - maxOffsetMs,
      horizonMs: horizonMs,
      perTodoCap: cap,
    )) {
      final dismissed = todo.lastDismissedMs;
      if (dismissed != null && occurrenceMs <= dismissed) continue;
      for (final offsetMinutes in offsets) {
        final fireAtMs = occurrenceMs - offsetMinutes * 60000;
        if (fireAtMs > nowMs) {
          planned.add(
            AlarmInstance(
              todoId: todo.id,
              title: todo.title,
              fireAtMs: fireAtMs,
              occurrenceMs: occurrenceMs,
            ),
          );
        }
      }
    }
  }

  planned.sort();
  return planned.length <= cap ? planned : planned.sublist(0, cap);
}

Iterable<int> _occurrences(
  Todo todo,
  int dueMs, {
  required int afterMs,
  required int horizonMs,
  required int perTodoCap,
}) sync* {
  final rule = todo.recurrenceRule;
  if (rule == null) {
    if (dueMs > afterMs) yield dueMs;
    return;
  }
  final recurrence = Recurrence.parse(rule);
  final anchor = DateTime.fromMillisecondsSinceEpoch(dueMs);
  var cursor = DateTime.fromMillisecondsSinceEpoch(afterMs);
  for (var i = 0; i < perTodoCap; i++) {
    cursor = recurrence.nextAfter(cursor, anchor: anchor);
    final ms = cursor.millisecondsSinceEpoch;
    if (ms > horizonMs) return;
    yield ms;
  }
}
