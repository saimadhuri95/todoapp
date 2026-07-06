import '../../data/db/database.dart';
import '../../data/repositories/todo_repository.dart' show TodoTags;

/// Pure view-model helpers for the list screen — separated for unit testing.

class TodoSection {
  const TodoSection(this.title, this.items);

  final String title;
  final List<Todo> items;
}

/// Groups active todos into Overdue / Today / Upcoming / Someday, dropping
/// empty sections. Input order (repository due-date ordering) is preserved.
List<TodoSection> sectionize(List<Todo> todos, DateTime now) {
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
  final overdue = <Todo>[];
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
    if (!due.isAfter(now)) {
      overdue.add(todo);
    } else if (due.isBefore(startOfTomorrow)) {
      today.add(todo);
    } else {
      upcoming.add(todo);
    }
  }
  return [
    if (overdue.isNotEmpty) TodoSection('Overdue', overdue),
    if (today.isNotEmpty) TodoSection('Today', today),
    if (upcoming.isNotEmpty) TodoSection('Upcoming', upcoming),
    if (someday.isNotEmpty) TodoSection('Someday', someday),
  ];
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
