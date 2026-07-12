import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import 'kanban.dart';
import 'todo_editor.dart';

/// Kanban board (TASKS.md 6.49): the current list's sections laid out as
/// columns side by side, so moving a todo between stages of a workflow
/// (e.g. "To do" / "Doing" / "Done") is one tap instead of scrolling a
/// grouped list. A read-only lens over the same data as the list screen —
/// completing/editing a todo still goes through the normal editor.
class KanbanScreen extends ConsumerWidget {
  const KanbanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(activeTodosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kanban board')),
      body: switch (todos) {
        AsyncData(:final value) => _Board(columns: kanbanColumns(value)),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.columns});

  final List<KanbanColumn> columns;

  @override
  Widget build(BuildContext context) {
    final otherSections = [
      for (final column in columns)
        if (column.section != null) column.section!,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final column in columns)
            SizedBox(
              width: 280,
              child: _ColumnCard(column: column, otherSections: otherSections),
            ),
        ],
      ),
    );
  }
}

class _ColumnCard extends ConsumerWidget {
  const _ColumnCard({required this.column, required this.otherSections});

  final KanbanColumn column;
  final List<String> otherSections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Semantics(
              header: true,
              child: Text(
                '${column.title} (${column.items.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: scheme.primary),
              ),
            ),
          ),
          if (column.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nothing here',
                style: TextStyle(color: scheme.outline),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 600),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final todo in column.items)
                    ListTile(
                      dense: true,
                      title: Text(
                        todo.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _MoveColumnButton(
                        todo: todo,
                        currentSection: column.section,
                        otherSections: otherSections,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TodoEditorScreen(todo: todo),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Moves a todo to a different column, i.e. a different section value
/// (TASKS.md 6.49). Offers every other existing section plus "No section"
/// and "New column...".
class _MoveColumnButton extends ConsumerWidget {
  const _MoveColumnButton({
    required this.todo,
    required this.currentSection,
    required this.otherSections,
  });

  final Todo todo;
  final String? currentSection;
  final List<String> otherSections;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String?>(
    tooltip: 'Move to column',
    icon: const Icon(Icons.arrow_forward, size: 18),
    onSelected: (target) async {
      if (target == _newColumnSentinel) {
        final name = await showDialog<String>(
          context: context,
          builder: (context) => const _NewColumnDialog(),
        );
        if (name == null || name.trim().isEmpty) return;
        await ref
            .read(todoRepositoryProvider)
            .edit(todo.id, section: Value(name.trim()));
        return;
      }
      await ref
          .read(todoRepositoryProvider)
          .edit(todo.id, section: Value(target));
    },
    itemBuilder: (_) => [
      if (currentSection != null)
        const PopupMenuItem(value: null, child: Text('No section')),
      for (final section in otherSections)
        if (section != currentSection)
          PopupMenuItem(value: section, child: Text(section)),
      const PopupMenuItem(
        value: _newColumnSentinel,
        child: Text('New column…'),
      ),
    ],
  );
}

const _newColumnSentinel = '__new_column__';

class _NewColumnDialog extends StatefulWidget {
  const _NewColumnDialog();

  @override
  State<_NewColumnDialog> createState() => _NewColumnDialogState();
}

class _NewColumnDialogState extends State<_NewColumnDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New column'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'e.g. Doing'),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Move'),
      ),
    ],
  );
}
