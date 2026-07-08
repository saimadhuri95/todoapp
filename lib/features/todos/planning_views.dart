import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';

class TodoCalendarScreen extends ConsumerStatefulWidget {
  const TodoCalendarScreen({super.key});

  @override
  ConsumerState<TodoCalendarScreen> createState() => _TodoCalendarScreenState();
}

class _TodoCalendarScreenState extends ConsumerState<TodoCalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(allActiveTodosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: todos.when(
        data: (items) {
          final counts = _countsByDay(items);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                    }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _formatMonth(_month),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                    }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CalendarGrid(
                month: _month,
                counts: counts,
                onDayTap: (day) {
                  ref.read(activeSmartFilterIdProvider.notifier).state = null;
                  ref.read(listFilterProvider.notifier).state = null;
                  ref.read(dateFilterProvider.notifier).state = day;
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
        error: (error, _) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.counts,
    required this.onDayTap,
  });

  final DateTime month;
  final Map<DateTime, int> counts;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final startOffset = first.weekday - DateTime.monday;
    final firstCell = first.subtract(Duration(days: startOffset));
    final days = [
      for (var i = 0; i < 42; i++) firstCell.add(Duration(days: i)),
    ];
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          children: [
            for (final label in const [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ])
              Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: [
            for (final day in days)
              _CalendarDayTile(
                day: day,
                inMonth: day.month == month.month,
                count: counts[DateTime(day.year, day.month, day.day)] ?? 0,
                colorScheme: colorScheme,
                onTap: () => onDayTap(DateTime(day.year, day.month, day.day)),
              ),
          ],
        ),
      ],
    );
  }
}

class _CalendarDayTile extends StatelessWidget {
  const _CalendarDayTile({
    required this.day,
    required this.inMonth,
    required this.count,
    required this.colorScheme,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final int count;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: count > 0 ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: inMonth ? null : colorScheme.outline,
                fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count == 0 ? '' : '$count',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class CompletedArchiveScreen extends ConsumerStatefulWidget {
  const CompletedArchiveScreen({super.key});

  @override
  ConsumerState<CompletedArchiveScreen> createState() =>
      _CompletedArchiveScreenState();
}

class _CompletedArchiveScreenState
    extends ConsumerState<CompletedArchiveScreen> {
  String? _listId;

  @override
  Widget build(BuildContext context) {
    final completed = ref.watch(completedTodosProvider);
    final lists = ref.watch(listsProvider).value ?? const <TodoList>[];
    final listNames = {for (final list in lists) list.id: list.name};
    return Scaffold(
      appBar: AppBar(title: const Text('Completed archive')),
      body: completed.when(
        data: (items) {
          final filtered = [
            for (final todo in items)
              if (_listId == null || todo.listId == _listId) todo,
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String?>(
                initialValue: _listId,
                decoration: const InputDecoration(labelText: 'List'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All lists')),
                  for (final list in lists)
                    DropdownMenuItem(value: list.id, child: Text(list.name)),
                ],
                onChanged: (value) => setState(() => _listId = value),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const _QuietEmptyState(
                  icon: Icons.history_toggle_off,
                  title: 'No completed tasks here yet',
                )
              else
                ..._completedArchiveRows(
                  context: context,
                  ref: ref,
                  todos: filtered,
                  listNames: listNames,
                ),
            ],
          );
        },
        error: (error, _) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  ConsumerState<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  final _checked = <String>{};

  void _toggle(String id, bool? value) {
    setState(() {
      if (value ?? false) {
        _checked.add(id);
      } else {
        _checked.remove(id);
      }
    });
  }

  void _openFilter(String? filter) {
    ref.read(activeSmartFilterIdProvider.notifier).state = null;
    ref.read(dateFilterProvider.notifier).state = null;
    ref.read(listFilterProvider.notifier).state = filter;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(allActiveTodosProvider);
    final lists = ref.watch(listsProvider).value ?? const <TodoList>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly review')),
      body: todos.when(
        data: (items) {
          final inboxCount = items.where((todo) => todo.listId == null).length;
          final somedayCount = items
              .where((todo) => todo.dueAtMs == null)
              .length;
          final listCounts = {
            for (final list in lists)
              list.id: items.where((todo) => todo.listId == list.id).length,
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ReviewStepTile(
                id: 'inbox',
                checked: _checked.contains('inbox'),
                title: 'Process Inbox',
                subtitle: '$inboxCount unfiled ${_taskWord(inboxCount)}',
                icon: Icons.inbox_outlined,
                onChanged: _toggle,
                onOpen: () => _openFilter(kInboxFilter),
              ),
              const SizedBox(height: 8),
              _ReviewStepTile(
                id: 'lists',
                checked: _checked.contains('lists'),
                title: 'Scan lists',
                subtitle:
                    '${lists.length} ${lists.length == 1 ? 'list' : 'lists'} available',
                icon: Icons.list_alt,
                onChanged: _toggle,
                onOpen: null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final list in lists)
                    ActionChip(
                      avatar: const Icon(Icons.list, size: 18),
                      label: Text('${list.name} (${listCounts[list.id] ?? 0})'),
                      onPressed: () => _openFilter(list.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _ReviewStepTile(
                id: 'someday',
                checked: _checked.contains('someday'),
                title: 'Review Someday',
                subtitle: '$somedayCount parked ${_taskWord(somedayCount)}',
                icon: Icons.backpack_outlined,
                onChanged: _toggle,
                onOpen: () => _openFilter(kSomedayFilter),
              ),
            ],
          );
        },
        error: (error, _) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ReviewStepTile extends StatelessWidget {
  const _ReviewStepTile({
    required this.id,
    required this.checked,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
    required this.onOpen,
  });

  final String id;
  final bool checked;
  final String title;
  final String subtitle;
  final IconData icon;
  final void Function(String id, bool? value) onChanged;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: checked, onChanged: (value) => onChanged(id, value)),
          if (onOpen != null)
            IconButton(
              tooltip: 'Open',
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
    );
  }
}

class NewSmartFilterDialog extends ConsumerStatefulWidget {
  const NewSmartFilterDialog({super.key});

  @override
  ConsumerState<NewSmartFilterDialog> createState() =>
      _NewSmartFilterDialogState();
}

class _NewSmartFilterDialogState extends ConsumerState<NewSmartFilterDialog> {
  final _name = TextEditingController();
  final _tag = TextEditingController();
  String? _listId;
  int _minPriority = 0;
  SmartDateFilter _dateFilter = SmartDateFilter.any;

  @override
  void dispose() {
    _name.dispose();
    _tag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider).value ?? const <TodoList>[];
    return AlertDialog(
      title: const Text('New smart list'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _listId,
              decoration: const InputDecoration(labelText: 'List'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Any list')),
                for (final list in lists)
                  DropdownMenuItem(value: list.id, child: Text(list.name)),
              ],
              onChanged: (value) => setState(() => _listId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tag,
              decoration: const InputDecoration(labelText: 'Tag'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _minPriority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Any priority')),
                DropdownMenuItem(value: 1, child: Text('Low and higher')),
                DropdownMenuItem(value: 2, child: Text('Medium and higher')),
                DropdownMenuItem(value: 3, child: Text('High only')),
              ],
              onChanged: (value) => setState(() => _minPriority = value ?? 0),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SmartDateFilter>(
              initialValue: _dateFilter,
              decoration: const InputDecoration(labelText: 'Date'),
              items: [
                for (final value in SmartDateFilter.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) =>
                  setState(() => _dateFilter = value ?? SmartDateFilter.any),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            final tag = _tag.text.trim();
            Navigator.of(context).pop(
              SavedSmartFilter(
                id: 'draft',
                name: name,
                listId: _listId,
                tag: tag.isEmpty ? null : tag,
                minPriority: _minPriority,
                dateFilter: _dateFilter,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _QuietEmptyState extends StatelessWidget {
  const _QuietEmptyState({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 12),
          Text(title),
        ],
      ),
    );
  }
}

List<Widget> _completedArchiveRows({
  required BuildContext context,
  required WidgetRef ref,
  required List<Todo> todos,
  required Map<String, String> listNames,
}) {
  final rows = <Widget>[];
  String? lastLabel;
  for (final todo in todos) {
    final completed = todo.completedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(todo.completedAtMs!);
    final label = completed == null ? 'Unknown date' : _formatDate(completed);
    if (label != lastLabel) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
      );
      lastLabel = label;
    }
    rows.add(
      ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(todo.title),
        subtitle: Text(listNames[todo.listId] ?? 'Inbox'),
        trailing: IconButton(
          tooltip: 'Restore',
          icon: const Icon(Icons.undo),
          onPressed: () => ref.read(todoRepositoryProvider).uncomplete(todo.id),
        ),
      ),
    );
  }
  return rows;
}

Map<DateTime, int> _countsByDay(List<Todo> todos) {
  final counts = <DateTime, int>{};
  for (final todo in todos) {
    final ms = todo.dueAtMs;
    if (ms == null) continue;
    final due = DateTime.fromMillisecondsSinceEpoch(ms);
    final day = DateTime(due.year, due.month, due.day);
    counts[day] = (counts[day] ?? 0) + 1;
  }
  return counts;
}

String _taskWord(int count) => count == 1 ? 'task' : 'tasks';

String _formatMonth(DateTime value) =>
    '${_monthName(value.month)} ${value.year}';

String _formatDate(DateTime value) =>
    '${value.year}-${_two(value.month)}-${_two(value.day)}';

String _monthName(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

String _two(int value) => value.toString().padLeft(2, '0');

extension on SmartDateFilter {
  String get label => switch (this) {
    SmartDateFilter.any => 'Any date',
    SmartDateFilter.today => 'Today',
    SmartDateFilter.upcoming => 'Upcoming',
    SmartDateFilter.someday => 'Someday',
  };
}
