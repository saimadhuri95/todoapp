import '../../data/db/database.dart';

/// The four Eisenhower-matrix quadrants (TASKS.md 6.49): importance ×
/// urgency. [doFirst] = important + urgent, [schedule] = important but not
/// urgent, [delegate] = urgent but not important, [eliminate] = neither.
enum EisenhowerQuadrant { doFirst, schedule, delegate, eliminate }

extension EisenhowerQuadrantLabel on EisenhowerQuadrant {
  /// Short heading shown on the quadrant card.
  String get title => switch (this) {
    EisenhowerQuadrant.doFirst => 'Do first',
    EisenhowerQuadrant.schedule => 'Schedule',
    EisenhowerQuadrant.delegate => 'Delegate',
    EisenhowerQuadrant.eliminate => 'Later',
  };

  /// Plain-language importance/urgency of the quadrant.
  String get subtitle => switch (this) {
    EisenhowerQuadrant.doFirst => 'Important & urgent',
    EisenhowerQuadrant.schedule => 'Important, not urgent',
    EisenhowerQuadrant.delegate => 'Urgent, not important',
    EisenhowerQuadrant.eliminate => 'Not important or urgent',
  };
}

/// Active todos grouped into the four quadrants. Every quadrant key is
/// present (possibly empty) and input order is preserved within each bucket.
class EisenhowerBuckets {
  const EisenhowerBuckets(this._byQuadrant);

  final Map<EisenhowerQuadrant, List<Todo>> _byQuadrant;

  List<Todo> operator [](EisenhowerQuadrant q) =>
      _byQuadrant[q] ?? const <Todo>[];

  bool get isEmpty => _byQuadrant.values.every((list) => list.isEmpty);
}

/// Buckets [todos] by importance (priority) × urgency (due date), relative to
/// [now]. A todo is *important* when its priority is medium or high
/// (`priority >= 2`), and *urgent* when it has a due date that is overdue or
/// within [urgentWindow] (default 24h). Undated todos are never urgent.
EisenhowerBuckets eisenhowerBuckets(
  List<Todo> todos,
  DateTime now, {
  Duration urgentWindow = const Duration(hours: 24),
}) {
  final buckets = {for (final q in EisenhowerQuadrant.values) q: <Todo>[]};
  final urgentBefore = now.add(urgentWindow);
  for (final todo in todos) {
    final important = todo.priority >= 2;
    final dueMs = todo.dueAtMs;
    final urgent =
        dueMs != null &&
        DateTime.fromMillisecondsSinceEpoch(dueMs).isBefore(urgentBefore);
    final quadrant = important
        ? (urgent ? EisenhowerQuadrant.doFirst : EisenhowerQuadrant.schedule)
        : (urgent ? EisenhowerQuadrant.delegate : EisenhowerQuadrant.eliminate);
    buckets[quadrant]!.add(todo);
  }
  return EisenhowerBuckets(buckets);
}
