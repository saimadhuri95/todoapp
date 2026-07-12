import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/focus_timer.dart';
import '../../app/providers.dart';
import '../../app/quick_capture.dart';
import '../../app/voice_input.dart';
import '../../core/natural_date.dart';
import '../../core/snooze_presets.dart';
import '../../data/db/database.dart';
import '../../data/repositories/todo_repository.dart';
import '../settings/settings_screen.dart';
import '../settings/sync_settings_screen.dart';
import 'eisenhower_screen.dart';
import 'kanban_screen.dart';
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
    // Global capture triggers (hotkey / launcher shortcut, TASKS.md 6.14)
    // land here as provider bumps and open the same quick-add dialog.
    ref.listen(quickCaptureRequestsProvider, (_, _) {
      _showAddDialog(context, ref);
    });
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
                tooltip: 'Priority matrix',
                icon: const Icon(Icons.grid_view_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EisenhowerScreen(),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Kanban board',
                icon: const Icon(Icons.view_column_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const KanbanScreen()),
                ),
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
  // Celebration feedback (TASKS.md 6.54): a crisp haptic the instant a todo
  // is checked off. Fire-and-forget with errors swallowed so a missing haptic
  // engine never blocks or breaks the completion itself.
  unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
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

/// Performs a configured swipe action (TASKS.md 6.48). Snooze uses the
/// same 10-minute preset as the old fixed notification snooze — quick,
/// consistent, no picker needed for a gesture-driven action.
Future<void> _performSwipeAction(
  BuildContext context,
  WidgetRef ref,
  Todo todo,
  SwipeAction action,
) async {
  switch (action) {
    case SwipeAction.complete:
      await _completeTodoWithUndo(context, ref, todo);
    case SwipeAction.snooze:
      final until = resolveSnoozeUntil(
        SnoozePreset.tenMinutes,
        ref.read(clockProvider).now(),
      ).millisecondsSinceEpoch;
      await ref.read(todoRepositoryProvider).snoozeAlarm(todo.id, until);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Snoozed 10 min')));
    case SwipeAction.delete:
      await _deleteTodoWithUndo(context, ref, todo);
  }
}

/// The colored panel revealed behind a swipe (TASKS.md 6.48) — icon only
/// when a direction has no action configured, so an empty swipe still
/// shows *something* moved rather than a jarring blank space.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.action, required this.alignment});

  final SwipeAction? action;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (action) {
      SwipeAction.complete => (scheme.primaryContainer, Icons.check),
      SwipeAction.snooze => (scheme.tertiaryContainer, Icons.snooze),
      SwipeAction.delete => (scheme.errorContainer, Icons.delete),
      null => (scheme.surfaceContainerHighest, null),
    };
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: icon == null ? null : Icon(icon),
    );
  }
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
    final quickWin = ref.watch(quickWinFilterProvider);
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              avatar: const Icon(Icons.bolt, size: 18),
              label: const Text('I have 10 minutes'),
              selected: quickWin,
              onSelected: (v) =>
                  ref.read(quickWinFilterProvider.notifier).state = v,
            ),
          ),
        ),
        const _FocusTimerBanner(),
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
              final searched = filterTodos(items, query);
              final filtered = quickWin ? quickWins(searched) : searched;
              return _buildList(
                context,
                ref,
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
    WidgetRef ref,
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
        for (final section in sections) ...[
          _SectionHeaderRow(section.title, section.userSection, section.items),
          ...section.items,
        ],
      if (!somedayView && !recap.isEmpty) _completedMarker,
    ];
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      onReorderItem: (oldIndex, newIndex) =>
          _reorderRows(ref, rows, oldIndex, newIndex),
      itemCount: rows.length,
      itemBuilder: (context, i) => switch (rows[i]) {
        final String title when title == _completedMarker =>
          _CompletedRecapTile(key: const ValueKey('completed'), recap: recap),
        final _SectionHeaderRow row => _SectionHeader(
          key: ValueKey('section-${row.title}-${row.userSection ?? ''}-$i'),
          title: row.title,
          items: row.items,
        ),
        final Todo todo => _TodoTile(
          key: ValueKey(todo.id),
          todo: todo,
          dragIndex: i,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  static const _completedMarker = ' completed ';
}

class _SectionHeaderRow {
  const _SectionHeaderRow(this.title, this.userSection, this.items);

  final String title;
  final String? userSection;
  final List<Todo> items;
}

Future<void> _reorderRows(
  WidgetRef ref,
  List<Object> rows,
  int oldIndex,
  int newIndex,
) async {
  if (oldIndex < 0 || oldIndex >= rows.length || rows[oldIndex] is! Todo) {
    return;
  }
  if (newIndex > rows.length) newIndex = rows.length;

  final moved = rows.removeAt(oldIndex) as Todo;
  rows.insert(newIndex, moved);

  final ordered = <Todo>[];
  final sectionsById = <String, String?>{};
  String? currentSection;
  for (final row in rows) {
    if (row is _SectionHeaderRow) {
      currentSection = row.userSection;
    } else if (row is Todo) {
      ordered.add(row);
      if (row.id == moved.id) {
        sectionsById[row.id] = currentSection;
      }
    }
  }
  await ref
      .read(todoRepositoryProvider)
      .replaceVisibleOrder(ordered, sectionsById: sectionsById);
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

class _SectionHeader extends ConsumerWidget {
  const _SectionHeader({required this.title, required this.items, super.key});

  final String title;
  final List<Todo> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Realistic-day meter (TASKS.md 6.55): only the Today section carries a
    // "what's actually plannable" reading — Upcoming/Someday aren't today's
    // hours to spend.
    final meter = title == 'Today'
        ? realisticDayMeter(items, ref.watch(dailyAvailableMinutesProvider))
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      // Mark as a heading so screen readers can jump between sections
      // (Today / Upcoming / …) by heading navigation (TASKS.md 5.5).
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (meter != null && meter.plannedMinutes > 0) ...[
              const SizedBox(width: 8),
              Text(
                '${_formatHours(meter.plannedMinutes)} of '
                '${_formatHours(meter.availableMinutes)} planned',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: meter.isOverCommitted
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
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
  const _TodoTile({required this.todo, required this.dragIndex, super.key});

  final Todo todo;
  final int dragIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final overdue = todo.dueAtMs == null
        ? null
        : overdueLabel(todo.dueAtMs!, ref.watch(clockProvider).now());
    final large = ref.watch(displayDensityProvider) == DisplayDensity.large;
    // Simple mode (TASKS.md 6.57): even larger than glanceable, and the
    // tile drops everything but the checkbox and title — no subtitle,
    // pin/move/actions/reorder — for caregiving or low-vision setups.
    final simple = ref.watch(simpleModeProvider);
    // Configurable swipe actions (TASKS.md 6.48): each direction independently
    // does nothing/complete/snooze/delete. confirmDismiss always returns
    // false — the mutation itself (not Dismissible's own removal) is what
    // takes the todo out of view, so complete/snooze don't visually yank an
    // item that a stream update hasn't actually removed yet.
    final startToEnd = ref.watch(swipeStartToEndActionProvider);
    final endToStart = ref.watch(swipeEndToStartActionProvider);
    final direction = switch ((startToEnd != null, endToStart != null)) {
      (true, true) => DismissDirection.horizontal,
      (true, false) => DismissDirection.startToEnd,
      (false, true) => DismissDirection.endToStart,
      (false, false) => DismissDirection.none,
    };
    return Dismissible(
      key: ValueKey(todo.id),
      direction: direction,
      background: _SwipeBackground(
        action: startToEnd,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        action: endToStart,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (swipeDirection) async {
        final action = swipeDirection == DismissDirection.startToEnd
            ? startToEnd
            : endToStart;
        if (action != null) {
          await _performSwipeAction(context, ref, todo, action);
        }
        return false;
      },
      child: ListTile(
        // Glanceable mode (TASKS.md 6.5): scale grows the checkbox's hit
        // target too, so across-the-room one-tap completes stay easy.
        minVerticalPadding: simple ? 20 : (large ? 14 : null),
        leading: Transform.scale(
          scale: simple ? 1.8 : (large ? 1.4 : 1),
          child: Semantics(
            label: 'Mark "${todo.title}" complete',
            child: Checkbox(
              value: false,
              onChanged: (_) => _completeTodoWithUndo(context, ref, todo),
            ),
          ),
        ),
        title: LinkifiedText(
          todo.title,
          style: simple
              ? Theme.of(context).textTheme.headlineSmall
              : (large ? Theme.of(context).textTheme.titleLarge : null),
        ),
        subtitle: simple ? null : _TodoSubtitle(todo: todo, overdue: overdue),
        trailing: simple
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AssigneeChip(todo: todo),
                  _PinButton(todo: todo),
                  if (todo.listId == null) _MoveToListButton(todo: todo),
                  _TodoActionsButton(todo: todo),
                  ReorderableDragStartListener(
                    index: dragIndex,
                    child: Semantics(
                      label: 'Reorder "${todo.title}"',
                      button: true,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                ],
              ),
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

/// Most pinned "Top 3" must-dos allowed at once (TASKS.md 6.34).
const kMaxPins = 3;

/// Pin toggle for the "Top 3" section (TASKS.md 6.34, R14.1). Pinning is
/// capped at [kMaxPins]; attempting a fourth surfaces a hint instead.
class _PinButton extends ConsumerWidget {
  const _PinButton({required this.todo});

  final Todo todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: todo.pinned ? 'Unpin' : 'Pin to Top 3',
    icon: Icon(todo.pinned ? Icons.push_pin : Icons.push_pin_outlined),
    color: todo.pinned ? Theme.of(context).colorScheme.primary : null,
    onPressed: () {
      final repo = ref.read(todoRepositoryProvider);
      if (todo.pinned) {
        repo.setPinned(todo.id, false);
        return;
      }
      final active = ref.read(activeTodosProvider).value ?? const <Todo>[];
      if (active.where((t) => t.pinned).length >= kMaxPins) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can pin up to $kMaxPins todos')),
        );
        return;
      }
      repo.setPinned(todo.id, true);
    },
  );
}

class _TodoSubtitle extends ConsumerWidget {
  const _TodoSubtitle({required this.todo, required this.overdue});

  final Todo todo;
  final String? overdue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionLabel = todo.section == null
        ? null
        : 'Section: ${todo.section}';
    final dueLabel = overdue == null && todo.dueAtMs != null
        ? _TodoTile._formatDue(todo.dueAtMs!)
        : null;
    // Habit streaks (TASKS.md 6.11): only meaningful once it's actually a
    // streak (2+), so a first-ever on-time completion doesn't get a badge.
    final streakLabel = todo.recurrenceRule != null && todo.currentStreak >= 2
        ? '🔥 ${todo.currentStreak}-streak'
        : null;
    final lines = <String>[?sectionLabel, ?overdue, ?dueLabel, ?streakLabel];
    final subtasks =
        ref.watch(subtasksProvider(todo.id)).value ?? const <Todo>[];
    if (subtasks.isNotEmpty) {
      final done = subtasks
          .where((subtask) => subtask.completedAtMs != null)
          .length;
      lines.add('$done/${subtasks.length} checklist items');
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    // Visually the fields are pipe-separated; a screen reader would read that
    // as "vertical bar", so expose a comma-joined label instead (TASKS.md 5.5).
    return Semantics(
      label: lines.join(', '),
      child: ExcludeSemantics(child: Text(lines.join(' | '))),
    );
  }
}

class _TodoActionsButton extends ConsumerWidget {
  const _TodoActionsButton({required this.todo});

  final Todo todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    tooltip: 'Todo actions',
    icon: const Icon(Icons.more_vert),
    onSelected: (action) async {
      switch (action) {
        case 'breakdown':
          final lines = await showDialog<List<String>>(
            context: context,
            builder: (context) => const _TaskBreakdownDialog(),
          );
          if (lines == null || lines.isEmpty) return;
          await ref.read(todoRepositoryProvider).createSubtasks(todo.id, lines);
          break;
        case 'focus':
          final duration = await showDialog<Duration>(
            context: context,
            builder: (context) => const _FocusDurationDialog(),
          );
          if (duration == null) return;
          ref
              .read(focusTimerProvider.notifier)
              .start(
                todoId: todo.id,
                todoTitle: todo.title,
                duration: duration,
              );
          break;
        case 'delete':
          await _deleteTodoWithUndo(context, ref, todo);
          break;
      }
    },
    // Delete lives here too, not only on the swipe gesture, so screen-reader
    // and keyboard users have a reachable path (TASKS.md 5.5).
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'breakdown',
        child: ListTile(
          leading: Icon(Icons.splitscreen_outlined),
          title: Text('Break down'),
        ),
      ),
      PopupMenuItem(
        value: 'focus',
        child: ListTile(
          leading: Icon(Icons.timer_outlined),
          title: Text('Focus timer'),
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: ListTile(
          leading: Icon(Icons.delete_outline),
          title: Text('Delete'),
        ),
      ),
    ],
  );
}

/// Duration picker for starting a focus session (TASKS.md 6.11).
class _FocusDurationDialog extends StatelessWidget {
  const _FocusDurationDialog();

  @override
  Widget build(BuildContext context) => SimpleDialog(
    title: const Text('Focus for how long?'),
    children: [
      for (final duration in kFocusDurationChoices)
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(duration),
          child: Text('${duration.inMinutes} min'),
        ),
    ],
  );
}

/// Banner for the one running focus session (TASKS.md 6.11): shows what's
/// being focused on and when it ends, with a way to stop early.
class _FocusTimerBanner extends ConsumerWidget {
  const _FocusTimerBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(focusTimerProvider);
    if (session == null) return const SizedBox.shrink();
    String two(int n) => n.toString().padLeft(2, '0');
    final end = session.endAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: Text('Focusing on "${session.todoTitle}"'),
          subtitle: Text('Ends at ${two(end.hour)}:${two(end.minute)}'),
          trailing: TextButton(
            onPressed: () => ref.read(focusTimerProvider.notifier).cancel(),
            child: const Text('Stop'),
          ),
        ),
      ),
    );
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

/// Assignee chip on shared-list tasks (TASKS.md 6.51): tapping opens a
/// picker over the list's group members. Hidden for local-only lists (no
/// group to assign within) and for unassigned todos with no members yet.
class _AssigneeChip extends ConsumerWidget {
  const _AssigneeChip({required this.todo});

  final Todo todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider).value ?? const <TodoList>[];
    TodoList? list;
    for (final candidate in lists) {
      if (candidate.id == todo.listId) {
        list = candidate;
        break;
      }
    }
    final groupId = list?.groupId;
    if (groupId == null) return const SizedBox.shrink();
    final members = ref.watch(groupMembersProvider(groupId)).value ?? const [];
    if (members.isEmpty) return const SizedBox.shrink();

    Device? assignee;
    for (final member in members) {
      if (member.id == todo.assigneeDeviceId) {
        assignee = member;
        break;
      }
    }

    return PopupMenuButton<String?>(
      tooltip: assignee == null ? 'Assign' : 'Assigned to ${assignee.name}',
      onSelected: (deviceId) =>
          ref.read(todoRepositoryProvider).setAssignee(todo.id, deviceId),
      itemBuilder: (_) => [
        const PopupMenuItem(value: null, child: Text('Unassigned')),
        for (final member in members)
          PopupMenuItem(value: member.id, child: Text(member.name)),
      ],
      child: Semantics(
        label: assignee == null ? 'Unassigned' : 'Assigned to ${assignee.name}',
        child: CircleAvatar(
          radius: 12,
          child: Text(
            _initials(assignee?.name),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return (first + last).toUpperCase();
  }
}

/// Completion recap (TASKS.md 6.33, R13.7): a collapsible "Completed" section
/// whose subtitle summarizes what got done today and this week, with the items
/// grouped by when they were finished.
class _CompletedRecapTile extends StatelessWidget {
  const _CompletedRecapTile({required this.recap, super.key});

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
    final groups = ref.watch(syncGroupsProvider).value ?? const <SyncGroup>[];
    final groupsById = {for (final group in groups) group.id: group};
    final localLists = [
      for (final list in lists)
        if (list.groupId == null || !groupsById.containsKey(list.groupId)) list,
    ];
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

    Future<void> editList(TodoList list) async {
      final draft = await showDialog<_ListDraft>(
        context: context,
        builder: (context) => _ListDialog(
          title: 'Edit list',
          confirm: 'Save',
          initialName: list.name,
          initialGroupId: list.groupId,
          groups: groups,
        ),
      );
      if (draft == null) return;
      if (!context.mounted) return;
      final name = draft.name.trim();
      if (name.isNotEmpty && name != list.name) {
        await ref.read(listRepositoryProvider).rename(list.id, name);
        if (!context.mounted) return;
      }
      if (draft.groupId != list.groupId &&
          await _confirmListScopeMove(context, list, draft.groupId, groups)) {
        await ref.read(listRepositoryProvider).setGroup(list.id, draft.groupId);
      }
    }

    Widget listTile(TodoList list, {SyncGroup? group}) => ListTile(
      leading: group == null
          ? const Icon(Icons.list)
          : Semantics(
              label: 'Shared list',
              child: const Badge(
                label: Text('Shared'),
                child: Icon(Icons.list_alt_outlined),
              ),
            ),
      title: Text(list.name),
      subtitle: group == null ? null : Text(group.backendKindLabel),
      selected: filter == list.id,
      onTap: () => select(list.id),
      trailing: IconButton(
        tooltip: 'Edit list',
        icon: const Icon(Icons.more_vert),
        onPressed: () => editList(list),
      ),
    );

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
          const _DrawerSectionHeader('On this device'),
          for (final list in localLists) listTile(list),
          for (final group in groups) ...[
            _DrawerSectionHeader(group.name, icon: Icons.group_outlined),
            for (final list in lists)
              if (list.groupId == group.id) listTile(list, group: group),
          ],
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('New list'),
            onTap: () async {
              final draft = await showDialog<_ListDraft>(
                context: context,
                builder: (context) => _ListDialog(
                  title: 'New list',
                  confirm: 'Create',
                  groups: groups,
                ),
              );
              final trimmed = draft?.name.trim() ?? '';
              if (trimmed.isNotEmpty) {
                final list = await ref
                    .read(listRepositoryProvider)
                    .create(name: trimmed);
                if (draft?.groupId != null) {
                  await ref
                      .read(listRepositoryProvider)
                      .setGroup(list.id, draft!.groupId);
                }
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
          ListTile(
            leading: const Icon(Icons.bookmarks_outlined),
            title: const Text('Checklist templates'),
            onTap: () => openScreen(const ChecklistTemplatesScreen()),
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

extension on SyncGroup {
  String get backendKindLabel => switch (backendKind) {
    'icloud' => 'iCloud shared folder',
    'dropbox' => 'Dropbox shared folder',
    'googleDrive' => 'Google Drive',
    'oneDrive' => 'OneDrive',
    'webdav' => 'WebDAV',
    'folder' => 'Synced folder',
    _ => backendKind.isEmpty ? 'Shared group' : backendKind,
  };
}

class _DrawerSectionHeader extends StatelessWidget {
  const _DrawerSectionHeader(this.title, {this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    ),
  );
}

Future<bool> _confirmListScopeMove(
  BuildContext context,
  TodoList list,
  String? nextGroupId,
  List<SyncGroup> groups,
) async {
  final next = groups.where((g) => g.id == nextGroupId).firstOrNull;
  final target = next == null ? 'Local only' : next.name;
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Move "${list.name}" to $target?'),
      content: const Text(
        'Future updates follow the new Sync setting. People who already '
        'received this list keep the history they have; moving it out of a '
        'group stops new changes from reaching that group.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Move list'),
        ),
      ],
    ),
  );
  return answer ?? false;
}

class ChecklistTemplatesScreen extends ConsumerWidget {
  const ChecklistTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(checklistTemplatesProvider);
    final activeFilter = ref.watch(listFilterProvider);
    final listId =
        activeFilter == null ||
            activeFilter == kInboxFilter ||
            activeFilter == kSomedayFilter
        ? null
        : activeFilter;
    return Scaffold(
      appBar: AppBar(title: const Text('Checklist templates')),
      body: templates.isEmpty
          ? const Center(
              child: Text('Save a task checklist as a template first.'),
            )
          : ListView.separated(
              itemCount: templates.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final template = templates[index];
                return ListTile(
                  leading: const Icon(Icons.task_alt_outlined),
                  title: Text(template.name),
                  subtitle: Text(
                    '${template.title} | ${template.subtasks.length} items',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Use template',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _instantiateTemplate(
                          context,
                          ref,
                          template,
                          listId,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete template',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(checklistTemplatesProvider.notifier)
                            .remove(template.id),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _instantiateTemplate(
    BuildContext context,
    WidgetRef ref,
    ChecklistTemplate template,
    String? listId,
  ) async {
    final repo = ref.read(todoRepositoryProvider);
    final parent = await repo.create(
      title: template.title,
      notes: template.notes,
      listId: listId,
    );
    await repo.createSubtasks(parent.id, template.subtasks);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created "${template.name}" checklist')),
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
  var _listening = false;
  VoiceInput? _activeVoice; // captured at start; ref is unusable in dispose()

  /// The field's contents when dictation started; the recognizer's running
  /// transcript is appended after it, so speaking never clobbers typed text.
  var _voiceBase = '';

  @override
  void dispose() {
    if (_listening) _activeVoice?.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    final voice = ref.read(voiceInputProvider);
    _activeVoice = voice;
    if (_listening) {
      await voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (!await voice.ensureAvailable()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Voice input is not available here')),
      );
      return;
    }
    if (!mounted) return;
    _voiceBase = _controller.text.isEmpty ? '' : '${_controller.text} ';
    setState(() => _listening = true);
    await voice.start((text, isFinal) {
      if (!mounted) return;
      _controller.text = '$_voiceBase$text';
      _reparse(_controller.text);
      if (isFinal) setState(() => _listening = false);
    });
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
        // Dictation (TASKS.md 6.46, on-device only); hidden where no
        // platform speech API exists (Linux).
        suffixIcon: !ref.watch(voiceInputProvider).supported
            ? null
            : IconButton(
                tooltip: _listening ? 'Stop dictation' : 'Dictate',
                icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                color: _listening
                    ? Theme.of(context).colorScheme.primary
                    : null,
                onPressed: _toggleVoice,
              ),
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

class _TaskBreakdownDialog extends StatefulWidget {
  const _TaskBreakdownDialog();

  @override
  State<_TaskBreakdownDialog> createState() => _TaskBreakdownDialogState();
}

class _TaskBreakdownDialogState extends State<_TaskBreakdownDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Break task into checklist items'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      minLines: 5,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(hintText: 'One step per line'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.of(context).pop(splitTodoLines(_controller.text)),
        child: const Text('Create checklist'),
      ),
    ],
  );
}

class _ListDraft {
  const _ListDraft({required this.name, this.groupId});

  final String name;
  final String? groupId;
}

class _ListDialog extends StatefulWidget {
  const _ListDialog({
    required this.title,
    required this.confirm,
    required this.groups,
    this.initialName = '',
    this.initialGroupId,
  });

  final String title;
  final String confirm;
  final List<SyncGroup> groups;
  final String initialName;
  final String? initialGroupId;

  @override
  State<_ListDialog> createState() => _ListDialogState();
}

class _ListDialogState extends State<_ListDialog> {
  final _controller = TextEditingController();
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialName;
    _groupId = widget.initialGroupId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(
      context,
    ).pop(_ListDraft(name: _controller.text, groupId: _groupId));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'List name'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _groupId,
          decoration: const InputDecoration(labelText: 'Sync'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Local only')),
            for (final group in widget.groups)
              DropdownMenuItem(value: group.id, child: Text(group.name)),
          ],
          onChanged: (value) => setState(() => _groupId = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.confirm)),
    ],
  );
}
