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
    this.changedBy,
  });

  final String todoId;
  final String title;

  /// When to ring.
  final int fireAtMs;

  /// The due occurrence this alarm belongs to — what [dismissAlarm]
  /// records, so all offsets (and all devices) silence together.
  final int occurrenceMs;

  /// Device that last touched this todo, for shared-list attribution in the
  /// notification body ("changed by ...", TASKS.md 6.51). Null when the
  /// todo isn't on a shared list or has no clocks yet.
  final String? changedBy;

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
  Map<String, String> changedByTodoId = const {},
}) {
  final nowMs = now.millisecondsSinceEpoch;
  final horizonMs = nowMs + horizon.inMilliseconds;
  final planned = <AlarmInstance>[];

  for (final todo in todos) {
    if (todo.deleted || todo.completedAtMs != null) continue;
    final changedBy = changedByTodoId[todo.id];

    final snooze = todo.snoozeUntilMs;
    if (snooze != null && snooze > nowMs) {
      planned.add(
        AlarmInstance(
          todoId: todo.id,
          title: todo.title,
          fireAtMs: snooze,
          occurrenceMs: snooze,
          changedBy: changedBy,
        ),
      );
    }

    final dueMs = todo.dueAtMs;
    if (dueMs == null) continue;
    final nag = todo.nagIntervalMinutes;
    // Nagging without explicit offsets still rings at the due time itself
    // (TASKS.md 6.44 — "remind every N minutes until done" implies the
    // first reminder).
    final offsets = todo.alarmOffsetsMinutes.isEmpty && nag != null && nag > 0
        ? const [0]
        : todo.alarmOffsetsMinutes;
    if (offsets.isEmpty) continue;
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
              changedBy: changedBy,
            ),
          );
        }
      }
    }

    if (nag != null && nag > 0) {
      _planNags(
        todo,
        dueMs,
        nag,
        planned,
        nowMs: nowMs,
        horizonMs: horizonMs,
        cap: cap,
        changedBy: changedBy,
      );
    }
  }

  planned.sort();
  return planned.length <= cap ? planned : planned.sublist(0, cap);
}

/// Nag repeats (TASKS.md 6.44): once an occurrence is due and neither
/// completed nor dismissed, keep firing every [nagMinutes] until it is.
/// Chains anchor to their occurrence — dismissing the occurrence (or
/// completing the todo) silences the whole chain on every device — but only
/// future fires are planned, so a long-overdue todo nags from now on rather
/// than replaying missed repeats.
void _planNags(
  Todo todo,
  int dueMs,
  int nagMinutes,
  List<AlarmInstance> planned, {
  required int nowMs,
  required int horizonMs,
  required int cap,
  String? changedBy,
}) {
  final stepMs = nagMinutes * 60000;
  final dismissed = todo.lastDismissedMs;
  final occurrences = <int>{
    // The most recent already-due occurrence is what "until done" is about.
    ?_latestOccurrenceAtOrBefore(todo, dueMs, nowMs),
    ..._occurrences(
      todo,
      dueMs,
      afterMs: nowMs,
      horizonMs: horizonMs,
      perTodoCap: cap,
    ),
  };
  for (final occurrenceMs in occurrences) {
    if (dismissed != null && occurrenceMs <= dismissed) continue;
    final firstK = occurrenceMs >= nowMs
        ? 1
        : (nowMs - occurrenceMs) ~/ stepMs + 1;
    for (var k = firstK; k < firstK + cap; k++) {
      final fireAtMs = occurrenceMs + k * stepMs;
      if (fireAtMs > horizonMs) break;
      if (fireAtMs <= nowMs) continue;
      planned.add(
        AlarmInstance(
          todoId: todo.id,
          title: todo.title,
          fireAtMs: fireAtMs,
          occurrenceMs: occurrenceMs,
          changedBy: changedBy,
        ),
      );
    }
  }
}

/// The most recent occurrence at or before [nowMs]; null when the todo
/// isn't due yet. Bounded forward walk — recurrence rules have no
/// "previous occurrence" query.
int? _latestOccurrenceAtOrBefore(Todo todo, int dueMs, int nowMs) {
  if (dueMs > nowMs) return null;
  final recurrence = _tryParseRecurrence(todo.recurrenceRule);
  if (recurrence == null) return dueMs;
  final anchor = DateTime.fromMillisecondsSinceEpoch(dueMs);
  var latest = dueMs;
  var cursor = anchor;
  for (var i = 0; i < 5000; i++) {
    cursor = recurrence.nextAfter(cursor, anchor: anchor);
    final ms = cursor.millisecondsSinceEpoch;
    if (ms > nowMs) break;
    latest = ms;
  }
  return latest;
}

/// Parses [rule], returning null for a null rule *or* one this build can't
/// understand (bad sync input / a newer syntax). Mirrors the guard
/// [TodoRepository.complete] already applies so a malformed synced rule
/// never crashes the reminder pipeline.
Recurrence? _tryParseRecurrence(String? rule) {
  if (rule == null) return null;
  try {
    return Recurrence.parse(rule);
  } on FormatException {
    return null;
  }
}

Iterable<int> _occurrences(
  Todo todo,
  int dueMs, {
  required int afterMs,
  required int horizonMs,
  required int perTodoCap,
}) sync* {
  final recurrence = _tryParseRecurrence(todo.recurrenceRule);
  if (recurrence == null) {
    // No rule, or a rule this build can't parse (a malformed/newer synced
    // value): fall back to the single base occurrence rather than throwing
    // — one bad todo must not take down scheduling for every other todo.
    if (dueMs > afterMs) yield dueMs;
    return;
  }
  final anchor = DateTime.fromMillisecondsSinceEpoch(dueMs);
  var cursor = DateTime.fromMillisecondsSinceEpoch(afterMs);
  for (var i = 0; i < perTodoCap; i++) {
    cursor = recurrence.nextAfter(cursor, anchor: anchor);
    final ms = cursor.millisecondsSinceEpoch;
    if (ms > horizonMs) return;
    yield ms;
  }
}
