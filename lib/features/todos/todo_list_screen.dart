import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../settings/settings_screen.dart';
import 'todo_editor.dart';
import 'todo_sections.dart';

/// Wide layouts (>= this width) show a master-detail split; narrower ones
/// push the editor as a route. 840 = Material "expanded" breakpoint.
const kWideLayoutBreakpoint = 840.0;

class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            _showAddDialog(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            _showAddDialog(context, ref),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Todos'),
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          drawer: const _ListsDrawer(),
          body: wide
              ? Row(
                  children: [
                    const Expanded(flex: 2, child: _TodoListPane()),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 3, child: _DetailPane()),
                  ],
                )
              : const _TodoListPane(),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Add todo',
            onPressed: () => _showAddDialog(context, ref),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}

Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
  final title = await showDialog<String>(
    context: context,
    builder: (context) => const _AddTodoDialog(),
  );
  final trimmed = title?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    await ref
        .read(todoRepositoryProvider)
        .create(title: trimmed, listId: ref.read(listFilterProvider));
  }
}

class _TodoListPane extends ConsumerWidget {
  const _TodoListPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(activeTodosProvider);
    final completed = ref.watch(completedTodosProvider).value ?? const [];
    final query = ref.watch(searchQueryProvider);
    final now = ref.watch(clockProvider).now();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SearchBar(
            hintText: 'Search',
            leading: const Icon(Icons.search),
            onChanged: (q) => ref.read(searchQueryProvider.notifier).state = q,
          ),
        ),
        Expanded(
          child: switch (todos) {
            AsyncData(value: final items) => _buildList(
              context,
              ref,
              sectionize(filterTodos(items, query), now),
              filterTodos(completed, query),
            ),
            AsyncError(error: final e) => Center(child: Text('Error: $e')),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<TodoSection> sections,
    List<Todo> completed,
  ) {
    if (sections.isEmpty && completed.isEmpty) {
      return const Center(child: Text('No todos yet — add one!'));
    }
    return ListView(
      children: [
        for (final section in sections) ...[
          _SectionHeader(section.title),
          for (final todo in section.items) _TodoTile(todo: todo),
        ],
        if (completed.isNotEmpty)
          ExpansionTile(
            title: Text('Completed (${completed.length})'),
            children: [
              for (final todo in completed) _CompletedTile(todo: todo),
            ],
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _DetailPane extends ConsumerWidget {
  const _DetailPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedTodoIdProvider);
    final todos = ref.watch(activeTodosProvider).value ?? const <Todo>[];
    final selected = todos.where((t) => t.id == selectedId).firstOrNull;
    if (selected == null) {
      return const Center(child: Text('Select a todo'));
    }
    // Key by id so switching selection rebuilds the editor state.
    return TodoEditor(key: ValueKey(selected.id), todo: selected);
  }
}

class _TodoTile extends ConsumerWidget {
  const _TodoTile({required this.todo});

  final Todo todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(todoRepositoryProvider);
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) => repo.softDelete(todo.id),
      child: ListTile(
        leading: Checkbox(
          value: false,
          onChanged: (_) => repo.complete(todo.id),
        ),
        title: Text(todo.title),
        subtitle: todo.dueAtMs == null ? null : Text(_formatDue(todo.dueAtMs!)),
        onTap: () {
          if (wide) {
            ref.read(selectedTodoIdProvider.notifier).state = todo.id;
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TodoEditorScreen(todo: todo),
              ),
            );
          }
        },
      ),
    );
  }

  static String _formatDue(int ms) {
    final due = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Due ${due.year}-${two(due.month)}-${two(due.day)} '
        '${two(due.hour)}:${two(due.minute)}';
  }
}

class _CompletedTile extends ConsumerWidget {
  const _CompletedTile({required this.todo});

  final Todo todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: Checkbox(
      value: true,
      onChanged: (_) => ref.read(todoRepositoryProvider).uncomplete(todo.id),
    ),
    title: Text(
      todo.title,
      style: const TextStyle(decoration: TextDecoration.lineThrough),
    ),
  );
}

class _ListsDrawer extends ConsumerWidget {
  const _ListsDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider).value ?? const <TodoList>[];
    final filter = ref.watch(listFilterProvider);
    void select(String? id) {
      ref.read(listFilterProvider.notifier).state = id;
      Navigator.of(context).pop();
    }

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Text(
              'Lists',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inbox),
            title: const Text('All todos'),
            selected: filter == null,
            onTap: () => select(null),
          ),
          for (final list in lists)
            ListTile(
              leading: const Icon(Icons.list),
              title: Text(list.name),
              selected: filter == list.id,
              onTap: () => select(list.id),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('New list'),
            onTap: () async {
              final name = await showDialog<String>(
                context: context,
                builder: (context) => const _NewListDialog(),
              );
              final trimmed = name?.trim() ?? '';
              if (trimmed.isNotEmpty) {
                await ref.read(listRepositoryProvider).create(name: trimmed);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _AddTodoDialog extends StatefulWidget {
  const _AddTodoDialog();

  @override
  State<_AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends State<_AddTodoDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New todo'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'What needs doing?'),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Add'),
      ),
    ],
  );
}

class _NewListDialog extends StatefulWidget {
  const _NewListDialog();

  @override
  State<_NewListDialog> createState() => _NewListDialogState();
}

class _NewListDialogState extends State<_NewListDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New list'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(hintText: 'List name'),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Create'),
      ),
    ],
  );
}
