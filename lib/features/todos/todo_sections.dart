import '../../data/db/database.dart';
import '../../data/repositories/todo_repository.dart' show TodoTags;

/// Pure view-model helpers for the list screen — separated for unit testing.

class TodoSection {
  const TodoSection(this.title, this.items, {this.userSection});

  final String title;
  final List<Todo> items;

  /// Non-null when this is a user-defined section rather than a date bucket.
  final String? userSection;
}

/// Groups active todos into Top 3 / Today / Upcoming / Someday, dropping empty
/// sections. Pinned todos (TASKS.md 6.34) are pulled into a "Top 3" section
/// above everything and are not repeated in their due-date section. Overdue
/// items fold into Today — oldest first via the repository's due-date ordering
/// — and tiles tag them with [overdueLabel] instead of a shaming red "Overdue"
/// section (TASKS.md 6.16, R13.1). Input order is preserved.
List<TodoSection> sectionize(List<Todo> todos, DateTime now) {
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
  final pinned = <Todo>[];
  final today = <Todo>[];
  final upcoming = <Todo>[];
  final someday = <Todo>[];
  final userSections = <String, List<Todo>>{};
  for (final todo in todos) {
    // Pins win over everything, including user-defined sections (6.34).
    if (todo.pinned) {
      pinned.add(todo);
      continue;
    }
    final manual = todo.section?.trim();
    if (manual != null && manual.isNotEmpty) {
      userSections.putIfAbsent(manual, () => []).add(todo);
      continue;
    }
    final ms = todo.dueAtMs;
    if (ms == null) {
      someday.add(todo);
      continue;
    }
    final due = DateTime.fromMillisecondsSinceEpoch(ms);
    (due.isBefore(startOfTomorrow) ? today : upcoming).add(todo);
  }
  return [
    if (pinned.isNotEmpty) TodoSection('Top 3', pinned),
    if (today.isNotEmpty) TodoSection('Today', today),
    if (upcoming.isNotEmpty) TodoSection('Upcoming', upcoming),
    if (someday.isNotEmpty) TodoSection('Someday', someday),
    for (final entry in userSections.entries)
      TodoSection(entry.key, entry.value, userSection: entry.key),
  ];
}

/// Completed todos bucketed for the recap view (TASKS.md 6.33, R13.7): what
/// got done [today], earlier [thisWeek], and everything [earlier]. Counts come
/// straight off the list lengths; [weekCount] folds today into the week total
/// so the summary reads the way people mean "done this week".
class CompletionRecap {
  const CompletionRecap(this.today, this.thisWeek, this.earlier);

  final List<Todo> today;
  final List<Todo> thisWeek;
  final List<Todo> earlier;

  int get total => today.length + thisWeek.length + earlier.length;
  int get weekCount => today.length + thisWeek.length;
  bool get isEmpty => total == 0;
}

/// Buckets completed todos by completion time for the recap (TASKS.md 6.33).
/// The week starts Monday, to match the weekday labels. Input order
/// (completed-newest-first from the repository) is preserved within each
/// bucket. Rows without a completion stamp fall into [CompletionRecap.earlier]
/// so nothing silently disappears from the recap.
CompletionRecap completionRecap(List<Todo> completed, DateTime now) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  // Monday = weekday 1; DateTime normalizes the day arithmetic so a week
  // spanning a DST change still lands on the right calendar day.
  final startOfWeek = DateTime(
    now.year,
    now.month,
    now.day - (now.weekday - 1),
  );
  final today = <Todo>[];
  final thisWeek = <Todo>[];
  final earlier = <Todo>[];
  for (final todo in completed) {
    final ms = todo.completedAtMs;
    if (ms == null) {
      earlier.add(todo);
      continue;
    }
    final at = DateTime.fromMillisecondsSinceEpoch(ms);
    if (!at.isBefore(startOfToday)) {
      today.add(todo);
    } else if (!at.isBefore(startOfWeek)) {
      thisWeek.add(todo);
    } else {
      earlier.add(todo);
    }
  }
  return CompletionRecap(today, thisWeek, earlier);
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
