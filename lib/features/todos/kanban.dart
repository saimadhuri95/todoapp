import '../../data/db/database.dart';

/// One kanban column: a user-defined [section] (null = "No section") and
/// the active todos currently in it.
class KanbanColumn {
  const KanbanColumn(this.section, this.items);

  /// Null for the unsectioned column.
  final String? section;
  final List<Todo> items;

  String get title => section ?? 'No section';
}

/// Groups active todos into kanban columns, one per distinct [Todo.section]
/// value (TASKS.md 6.49). The unsectioned column always leads (even when
/// empty, so there's somewhere to drop a todo out of every other column);
/// named columns follow in alphabetical order. Input order is preserved
/// within each column.
List<KanbanColumn> kanbanColumns(List<Todo> todos) {
  final unsectioned = <Todo>[];
  final bySection = <String, List<Todo>>{};
  for (final todo in todos) {
    final section = todo.section?.trim();
    if (section == null || section.isEmpty) {
      unsectioned.add(todo);
    } else {
      bySection.putIfAbsent(section, () => []).add(todo);
    }
  }
  final sortedSections = bySection.keys.toList()..sort();
  return [
    KanbanColumn(null, unsectioned),
    for (final section in sortedSections)
      KanbanColumn(section, bySection[section]!),
  ];
}
