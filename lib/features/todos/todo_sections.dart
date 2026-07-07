import '../../data/db/database.dart';
import '../../data/repositories/todo_repository.dart' show TodoTags;

/// Pure view-model helpers for the list screen — separated for unit testing.

class TodoSection {
  const TodoSection(this.title, this.items);

  final String title;
  final List<Todo> items;
}

/// Groups active todos into Today / Upcoming / Someday, dropping empty
/// sections. Overdue items fold into Today — oldest first via the
/// repository's due-date ordering — and tiles tag them with [overdueLabel]
/// instead of a shaming red "Overdue" section (TASKS.md 6.16, R13.1).
/// Input order is preserved.
List<TodoSection> sectionize(List<Todo> todos, DateTime now) {
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
  final today = <Todo>[];
  final upcoming = <Todo>[];
  final someday = <Todo>[];
  for (final todo in todos) {
    final ms = todo.dueAtMs;
    if (ms == null) {
      someday.add(todo);
      continue;
    }
    final due = DateTime.fromMillisecondsSinceEpoch(ms);
    (due.isBefore(startOfTomorrow) ? today : upcoming).add(todo);
  }
  return [
    if (today.isNotEmpty) TodoSection('Today', today),
    if (upcoming.isNotEmpty) TodoSection('Upcoming', upcoming),
    if (someday.isNotEmpty) TodoSection('Someday', someday),
  ];
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Subtle tag for items due before today: "since Tue" within the last week,
/// "since Jun 12" beyond. Null for anything due today or later — same-day
/// lateness keeps its normal due time, not a tag.
String? overdueLabel(int dueAtMs, DateTime now) {
  final due = DateTime.fromMillisecondsSinceEpoch(dueAtMs);
  final startOfToday = DateTime(now.year, now.month, now.day);
  if (!due.isBefore(startOfToday)) return null;
  // Calendar-day distance via UTC so a DST-shortened day still counts as 1.
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(due.year, due.month, due.day)).inDays;
  return days < 7
      ? 'since ${_weekdays[due.weekday - 1]}'
      : 'since ${_months[due.month - 1]} ${due.day}';
}

/// Case-insensitive match against title, notes, and tags.
List<Todo> filterTodos(List<Todo> todos, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return todos;
  return [
    for (final todo in todos)
      if (todo.title.toLowerCase().contains(q) ||
          todo.notes.toLowerCase().contains(q) ||
          todo.tags.any((t) => t.toLowerCase().contains(q)))
        todo,
  ];
}
