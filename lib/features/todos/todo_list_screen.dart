import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/natural_date.dart';
import '../../data/db/database.dart';
import '../../data/repositories/todo_repository.dart';
import '../settings/settings_screen.dart';
import '../settings/sync_settings_screen.dart';
import 'linkified_text.dart';
import 'planning_views.dart';
import 'todo_editor.dart';
import 'todo_sections.dart';
import 'todo_undo.dart';

/// Wide layouts (>= this width) show a master-detail split; narrower ones
/// push the editor as a route. 840 = Material "expanded" breakpoint.
const kWideLayoutBreakpoint = 840.0;
const _staleReviewWeeks = 4;

enum _ReviewAction { overdueAmnesty, staleReview }

enum _StaleAction { today, tomorrow, someday, delete }

class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final overdue = ref.watch(overdueTodosProvider);
    final stale = ref.watch(staleTodoCandidatesProvider).value ?? const [];
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
              if (overdue.isNotEmpty || stale.isNotEmpty)
                PopupMenuButton<_ReviewAction>(
                  tooltip: 'Review tools',
                  onSelected: (action) {
                    switch (action) {
                      case _ReviewAction.overdueAmnesty:
                        _showOverdueAmnesty(context, overdue);
                        break;
                      case _ReviewAction.staleReview:
                        _showStaleReview(context, stale);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (overdue.isNotEmpty)
                      PopupMenuItem(
                        value: _ReviewAction.overdueAmnesty,
                        child: Text('Overdue amnesty (${overdue.length})'),
                      ),
                    if (stale.isNotEmpty)
                      PopupMenuItem(
                        value: _ReviewAction.staleReview,
                        child: Text('Review stale tasks (${stale.length})'),
                      ),
                  ],
                ),
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

/// Splits quick-add input into candidate todo lines: one per line break,
/// trimmed, with blank lines dropped. Used to detect a multi-line paste
/// (TASKS.md 6.26). A single-line input yields a one-element list.
List<String> splitTodoLines(String input) => input
    .split(RegExp(r'\r\n|\r|\n'))
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
  final input = await showDialog<String>(
    context: context,
    builder: (context) => const _AddTodoDialog(),
  );
  final trimmed = input?.trim() ?? '';
  if (trimmed.isEmpty) return;

  final lines = splitTodoLines(trimmed);
  // A multi-line paste offers to split into one todo per line (6.26).
  // Bail out entirely if the dialog is dismissed without a choice.
  var perLine = false;
  if (lines.length > 1) {
    if (!context.mounted) return;
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => _SplitLinesDialog(count: lines.length),
    );
    if (choice == null) return;
    perLine = choice;
  }

  final now = ref.read(clockProvider).now();
  final filter = ref.read(listFilterProvider);
  final smartFilter = ref.read(activeSmartFilterProvider);
  // All-todos and Inbox views both capture into the Inbox (no list).
  final listId =
      smartFilter?.listId ??
      (filter == kInboxFilter || filter == kSomedayFilter ? null : filter);
  final repo = ref.read(todoRepositoryProvider);

  if (perLine) {
    for (final line in lines) {
      await _createTodoFromText(repo, line, now, listId);
    }
  } else {
    // Single todo: collapse the paste onto one line so the title is sane.
    await _createTodoFromText(repo, lines.join(' '), now, listId);
  }
}

Future<void> _completeTodoWithUndo(
  BuildContext context,
  WidgetRef ref,
  Todo todo,
) async {
  final repo = ref.read(todoRepositoryProvider);
  await repo.complete(todo.id);
  final after = await repo.getById(todo.id);
  if (after == null || !context.mounted) return;
  showTodoUndoSnackBar(
    messenger: ScaffoldMessenger.of(context),
    repo: repo,
    before: todo,
    after: after,
    message: 'Todo completed',
  );
}

Future<void> _deleteTodoWithUndo(
  BuildContext context,
  WidgetRef ref,
  Todo todo,
) async {
  final repo = ref.read(todoRepositoryProvider);
  await repo.softDelete(todo.id);
  final after = await repo.getById(todo.id);
  if (after == null || !context.mounted) return;
  showTodoUndoSnackBar(
    messenger: ScaffoldMessenger.of(context),
    repo: repo,
    before: todo,
    after: after,
    message: 'Todo deleted',
  );
}

Future<void> _createTodoFromText(
  TodoRepository repo,
  String text,
  DateTime now,
  String? listId,
) async {
  final parsed = parseQuickAdd(text, now);
  // "tomorrow at 5" alone strips to nothing; keep the raw text as the title.
  final title = parsed.title.isEmpty ? text : parsed.title;
  await repo.create(
    title: title,
    listId: listId,
    dueAtMs: parsed.dueAt?.millisecondsSinceEpoch,
  );
}

class _TodoListPane extends ConsumerWidget {
  const _TodoListPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(activeTodosProvider);
    final completed = ref.watch(completedTodosProvider).value ?? const [];
    final overdue = ref.watch(overdueTodosProvider);
    final dismissedPromptIds = ref.watch(dismissedOverduePromptIdsProvider);
    final query = ref.watch(searchQueryProvider);
    final now = ref.watch(clockProvider).now();
    final somedayView = ref.watch(listFilterProvider) == kSomedayFilter;
    final dateFilter = ref.watch(dateFilterProvider);
    final smartFilter = ref.watch(activeSmartFilterProvider);
    final promptTodos = [
      for (final todo in overdue)
        if (!dismissedPromptIds.contains(todo.id)) todo,
    ];

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
        if (dateFilter != null || smartFilter != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _ActiveFilterBar(
              dateFilter: dateFilter,
              smartFilter: smartFilter,
            ),
          ),
        if (!somedayView && promptTodos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _OverduePromptCard(todos: promptTodos),
          ),
        Expanded(
          child: switch (todos) {
            AsyncData(value: final items) => () {
              final filtered = filterTodos(items, query);
              return _buildList(
                context,
                sectionize(filtered, now),
                completionRecap(
                  somedayView ? const [] : filterTodos(completed, query),
                  now,
                ),
                somedayView: somedayView,
              );
            }(),
            AsyncError(error: final e) => Center(child: Text('Error: $e')),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    List<TodoSection> sections,
    CompletionRecap recap, {
    required bool somedayView,
  }) {
    if (sections.isEmpty && recap.isEmpty) {
      if (somedayView) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.backpack_outlined, size: 56),
              const SizedBox(height: 12),
              const Text('No Someday tasks parked'),
              const SizedBox(height: 4),
              Text(
                'Move something here when it is a possibility, not a commitment.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 56),
            const SizedBox(height: 12),
            const Text('No todos yet — add one!'),
            const SizedBox(height: 4),
            Text(
              'Tap + to add a todo. Ctrl/Cmd+N works too.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    // Flattened row models + builder so huge lists stay lazy (TASKS.md 5.7).
    final rows = <Object>[
      if (somedayView)
        for (final section in sections) ...section.items
      else
        for (final section in sections) ...[section.title, ...section.items],
      if (!somedayView && !recap.isEmpty) _completedMarker,
    ];
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) => switch (rows[i]) {
        final String title when title == _completedMarker =>
          _CompletedRecapTile(recap: recap),
        final String title => _SectionHeader(title),
        final Todo todo => _TodoTile(todo: todo),
        _ => const SizedBox.shrink(),
      },
    );
  }

  static const _completedMarker = ' completed ';
}

class _ActiveFilterBar extends ConsumerWidget {
  const _ActiveFilterBar({required this.dateFilter, required this.smartFilter});

  final DateTime? dateFilter;
  final SavedSmartFilter? smartFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smart = smartFilter;
    final label = smart != null
        ? 'Smart list: ${smart.name}'
        : 'Calendar: ${_formatDay(dateFilter!)}';
    return Align(
      alignment: Alignment.centerLeft,
      child: InputChip(
        avatar: Icon(
          smart != null ? Icons.auto_awesome_motion : Icons.calendar_month,
        ),
        label: Text(label),
        onDeleted: () {
          ref.read(activeSmartFilterIdProvider.notifier).state = null;
          ref.read(dateFilterProvider.notifier).state = null;
        },
      ),
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
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final overdue = todo.dueAtMs == null
        ? null
        : overdueLabel(todo.dueAtMs!, ref.watch(clockProvider).now());
    final large = ref.watch(displayDensityProvider) == DisplayDensity.large;
    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) => _deleteTodoWithUndo(context, ref, todo),
      child: ListTile(
        // Glanceable mode (TASKS.md 6.5): scale grows the checkbox's hit
        // target too, so across-the-room one-tap completes stay easy.
        minVerticalPadding: large ? 14 : null,
        leading: Transform.scale(
          scale: large ? 1.4 : 1,
          child: Checkbox(
            value: false,
            onChanged: (_) => _completeTodoWithUndo(context, ref, todo),
          ),
        ),
        title: LinkifiedText(
          todo.title,
          style: large ? Theme.of(context).textTheme.titleLarge : null,
        ),
        subtitle: switch ((overdue, todo.dueAtMs)) {
          ((final label?, _)) => Text(label),
          ((_, final ms?)) => Text(_formatDue(ms)),
          _ => null,
        },
        trailing: todo.listId == null ? _MoveToListButton(todo: todo) : null,
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

/// One-tap Inbox triage (TASKS.md 6.15): file an unfiled todo into a list
/// straight from the tile. Hidden until at least one list exists.
class _MoveToListButton extends ConsumerWidget {
  const _MoveToListButton({required this.todo});

  final Todo todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider).value ?? const <TodoList>[];
    if (lists.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Move to list',
      icon: const Icon(Icons.drive_file_move_outlined),
      onSelected: (listId) =>
          ref.read(todoRepositoryProvider).edit(todo.id, listId: Value(listId)),
      itemBuilder: (_) => [
        for (final list in lists)
          PopupMenuItem(value: list.id, child: Text(list.name)),
      ],
    );
  }
}

/// Completion recap (TASKS.md 6.33, R13.7): a collapsible "Completed" section
/// whose subtitle summarizes what got done today and this week, with the items
/// grouped by when they were finished.
class _CompletedRecapTile extends StatelessWidget {
  const _CompletedRecapTile({required this.recap});

  final CompletionRecap recap;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text('Completed (${recap.total})'),
    subtitle: Text(
      '${recap.today.length} done today · ${recap.weekCount} this week',
    ),
    children: [
      ..._group(context, 'Today', recap.today),
      ..._group(context, 'Earlier this week', recap.thisWeek),
      ..._group(context, 'Older', recap.earlier),
    ],
  );

  /// A subheader + its tiles, or nothing when the bucket is empty.
  List<Widget> _group(BuildContext context, String label, List<Todo> items) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      for (final todo in items) _CompletedTile(todo: todo),
    ];
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
    title: LinkifiedText(
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
    final smartFilters = ref.watch(savedSmartFiltersProvider);
    final activeSmartId = ref.watch(activeSmartFilterIdProvider);
    void select(String? id) {
      ref.read(activeSmartFilterIdProvider.notifier).state = null;
      ref.read(dateFilterProvider.notifier).state = null;
      ref.read(listFilterProvider.notifier).state = id;
      Navigator.of(context).pop();
    }

    void openScreen(Widget screen) {
      Navigator.of(context).pop();
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));
    }

    void selectSmartFilter(String id) {
      ref.read(activeSmartFilterIdProvider.notifier).state = id;
      ref.read(dateFilterProvider.notifier).state = null;
      ref.read(listFilterProvider.notifier).state = null;
      Navigator.of(context).pop();
    }

    Future<void> createSmartFilter() async {
      final draft = await showDialog<SavedSmartFilter>(
        context: context,
        builder: (context) => const NewSmartFilterDialog(),
      );
      if (draft == null) return;
      final saved = await ref
          .read(savedSmartFiltersProvider.notifier)
          .add(draft);
      ref.read(activeSmartFilterIdProvider.notifier).state = saved.id;
      ref.read(dateFilterProvider.notifier).state = null;
      ref.read(listFilterProvider.notifier).state = null;
      if (context.mounted) Navigator.of(context).pop();
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
            leading: const Icon(Icons.all_inbox),
            title: const Text('All todos'),
            selected: filter == null && activeSmartId == null,
            onTap: () => select(null),
          ),
          ListTile(
            leading: const Icon(Icons.inbox),
            title: const Text('Inbox'),
            selected: filter == kInboxFilter,
            onTap: () => select(kInboxFilter),
          ),
          ListTile(
            leading: const Icon(Icons.backpack_outlined),
            title: const Text('Someday'),
            selected: filter == kSomedayFilter,
            onTap: () => select(kSomedayFilter),
          ),
          for (final list in lists)
            ListTile(
              leading: const Icon(Icons.list),
              title: Text(list.name),
              selected: filter == list.id,
              onTap: () => select(list.id),
            ),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Calendar'),
            onTap: () => openScreen(const TodoCalendarScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Weekly review'),
            onTap: () => openScreen(const WeeklyReviewScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Completed archive'),
            onTap: () => openScreen(const CompletedArchiveScreen()),
          ),
          if (smartFilters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Smart lists',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          for (final smartFilter in smartFilters)
            ListTile(
              leading: const Icon(Icons.auto_awesome_motion),
              title: Text(smartFilter.name),
              selected: activeSmartId == smartFilter.id,
              onTap: () => selectSmartFilter(smartFilter.id),
              trailing: IconButton(
                tooltip: 'Delete smart list',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => ref
                    .read(savedSmartFiltersProvider.notifier)
                    .remove(smartFilter.id),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.filter_alt_outlined),
            title: const Text('New smart list'),
            onTap: createSmartFilter,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync settings'),
            onTap: () => openScreen(const SyncSettingsScreen()),
          ),
        ],
      ),
    );
  }
}

class _OverduePromptCard extends ConsumerWidget {
  const _OverduePromptCard({required this.todos});

  final List<Todo> todos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = todos.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count overdue ${count == 1 ? 'task could' : 'tasks could'} use a reset',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Sweep them to today, tomorrow, or Someday without a wall of red.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    ref
                        .read(dismissedOverduePromptIdsProvider.notifier)
                        .state = {
                      ...ref.read(dismissedOverduePromptIdsProvider),
                      for (final todo in todos) todo.id,
                    };
                  },
                  child: const Text('Later'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _showOverdueAmnesty(context, todos),
                  child: const Text('Sweep'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showOverdueAmnesty(BuildContext context, List<Todo> todos) {
  if (todos.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _OverdueAmnestySheet(todos: todos),
  );
}

class _OverdueAmnestySheet extends ConsumerWidget {
  const _OverdueAmnestySheet({required this.todos});

  final List<Todo> todos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> apply({
      required String label,
      required int? dayOffset,
      required bool clearDueDate,
    }) async {
      final repo = ref.read(todoRepositoryProvider);
      final now = ref.read(clockProvider).now();
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      for (final todo in todos) {
        await repo.edit(
          todo.id,
          dueAtMs: clearDueDate
              ? const Value(null)
              : Value(
                  _rescheduledDueAt(
                    todo: todo,
                    now: now,
                    dayOffset: dayOffset!,
                  ).millisecondsSinceEpoch,
                ),
        );
      }
      final dismissed = ref.read(dismissedOverduePromptIdsProvider);
      ref.read(dismissedOverduePromptIdsProvider.notifier).state = dismissed
          .difference({for (final todo in todos) todo.id});
      if (navigator.mounted) navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Moved ${todos.length} overdue ${todos.length == 1 ? 'task' : 'tasks'} to $label',
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overdue amnesty',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Give ${todos.length == 1 ? 'this task' : 'these tasks'} a fresh landing spot.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.today_outlined),
              title: const Text('Move to today'),
              subtitle: const Text(
                'Keep momentum without pretending the past did not happen.',
              ),
              onTap: () =>
                  apply(label: 'today', dayOffset: 0, clearDueDate: false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Move to tomorrow'),
              subtitle: const Text(
                'Start fresh with the same rough time of day.',
              ),
              onTap: () =>
                  apply(label: 'tomorrow', dayOffset: 1, clearDueDate: false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.backpack_outlined),
              title: const Text('Park in Someday'),
              subtitle: const Text(
                'Keep it possible without keeping it in the daily flow.',
              ),
              onTap: () =>
                  apply(label: 'Someday', dayOffset: null, clearDueDate: true),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showStaleReview(
  BuildContext context,
  List<StaleTodoCandidate> candidates,
) {
  if (candidates.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _StaleReviewSheet(candidates: candidates),
    ),
  );
}

class _StaleReviewSheet extends ConsumerStatefulWidget {
  const _StaleReviewSheet({required this.candidates});

  final List<StaleTodoCandidate> candidates;

  @override
  ConsumerState<_StaleReviewSheet> createState() => _StaleReviewSheetState();
}

class _StaleReviewSheetState extends ConsumerState<_StaleReviewSheet> {
  late List<StaleTodoCandidate> _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = [...widget.candidates];
  }

  Future<void> _apply(StaleTodoCandidate candidate, _StaleAction action) async {
    final repo = ref.read(todoRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final now = ref.read(clockProvider).now();
    switch (action) {
      case _StaleAction.today:
        await repo.edit(
          candidate.todo.id,
          dueAtMs: Value(
            _rescheduledDueAt(
              todo: candidate.todo,
              now: now,
              dayOffset: 0,
            ).millisecondsSinceEpoch,
          ),
        );
        break;
      case _StaleAction.tomorrow:
        await repo.edit(
          candidate.todo.id,
          dueAtMs: Value(
            _rescheduledDueAt(
              todo: candidate.todo,
              now: now,
              dayOffset: 1,
            ).millisecondsSinceEpoch,
          ),
        );
        break;
      case _StaleAction.someday:
        await repo.edit(candidate.todo.id, dueAtMs: const Value(null));
        break;
      case _StaleAction.delete:
        await repo.softDelete(candidate.todo.id);
        break;
    }
    if (!mounted) return;
    setState(() {
      _remaining = [
        for (final entry in _remaining)
          if (entry.todo.id != candidate.todo.id) entry,
      ];
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(_staleSnackBarMessage(candidate.todo.title, action)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).now();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stale task review',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Untouched for $_staleReviewWeeks+ weeks. Give each one a fresh date, park it in Someday, or let it go.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _remaining.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing stale is waiting on you now.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      itemCount: _remaining.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final candidate = _remaining[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                candidate.todo.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  _formatStaleLabel(
                                    candidate.lastTouchedAt,
                                    now,
                                  ),
                                  if (candidate.todo.dueAtMs != null)
                                    _TodoTile._formatDue(
                                      candidate.todo.dueAtMs!,
                                    ),
                                ].join(' • '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ActionChip(
                                    label: const Text('Today'),
                                    onPressed: () =>
                                        _apply(candidate, _StaleAction.today),
                                  ),
                                  ActionChip(
                                    label: const Text('Tomorrow'),
                                    onPressed: () => _apply(
                                      candidate,
                                      _StaleAction.tomorrow,
                                    ),
                                  ),
                                  ActionChip(
                                    label: const Text('Someday'),
                                    onPressed: () =>
                                        _apply(candidate, _StaleAction.someday),
                                  ),
                                  ActionChip(
                                    label: const Text('Delete'),
                                    onPressed: () =>
                                        _apply(candidate, _StaleAction.delete),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _rescheduledDueAt({
  required Todo todo,
  required DateTime now,
  required int dayOffset,
}) {
  final existing = todo.dueAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(todo.dueAtMs!);
  final base = DateTime(
    now.year,
    now.month,
    now.day + dayOffset,
    existing?.hour ?? 9,
    existing?.minute ?? 0,
  );
  if (dayOffset != 0 || !base.isBefore(now)) return base;
  return DateTime(now.year, now.month, now.day, now.hour + 1, now.minute);
}

String _formatStaleLabel(DateTime lastTouchedAt, DateTime now) {
  final days = DateTime.utc(now.year, now.month, now.day)
      .difference(
        DateTime.utc(
          lastTouchedAt.year,
          lastTouchedAt.month,
          lastTouchedAt.day,
        ),
      )
      .inDays;
  if (days <= 0) return 'Touched today';
  if (days < 7) return 'Touched $days day${days == 1 ? '' : 's'} ago';
  final weeks = days ~/ 7;
  if (weeks < 6) {
    return 'Touched $weeks week${weeks == 1 ? '' : 's'} ago';
  }
  return 'Touched ${lastTouchedAt.year}-${_two(lastTouchedAt.month)}-${_two(lastTouchedAt.day)}';
}

String _staleSnackBarMessage(String title, _StaleAction action) {
  final subject = title.isEmpty ? 'Task' : '"$title"';
  return switch (action) {
    _StaleAction.today => '$subject moved to today',
    _StaleAction.tomorrow => '$subject moved to tomorrow',
    _StaleAction.someday => '$subject moved to Someday',
    _StaleAction.delete => '$subject deleted',
  };
}

String _formatDay(DateTime day) =>
    '${day.year}-${_two(day.month)}-${_two(day.day)}';

String _two(int value) => value.toString().padLeft(2, '0');

class _AddTodoDialog extends ConsumerStatefulWidget {
  const _AddTodoDialog();

  @override
  ConsumerState<_AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends ConsumerState<_AddTodoDialog> {
  final _controller = TextEditingController();
  DateTime? _preview;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reparse(String value) {
    final due = parseQuickAdd(value, ref.read(clockProvider).now()).dueAt;
    if (due != _preview) setState(() => _preview = due);
  }

  static String _formatPreview(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Due ${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New todo'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      onChanged: _reparse,
      // Multi-line so a pasted list keeps its line breaks (6.26); capped so
      // the dialog stays compact. Enter still submits (textInputAction.done).
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.done,
      minLines: 1,
      maxLines: 5,
      decoration: InputDecoration(
        hintText: 'What needs doing? Try "pay rent friday 5pm"',
        helperText: _preview == null ? ' ' : _formatPreview(_preview!),
      ),
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

/// Offered when a multi-line paste lands in quick add (TASKS.md 6.26):
/// keep it as one todo or split into one per line.
class _SplitLinesDialog extends StatelessWidget {
  const _SplitLinesDialog({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Multiple lines'),
    content: Text('Create $count separate todos, one per line?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Single todo'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text('$count todos'),
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
