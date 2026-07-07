import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/linkify.dart';
import '../../data/db/database.dart';
import '../../data/repositories/todo_repository.dart' show TodoTags;
import 'linkified_text.dart';
import 'todo_undo.dart';

/// Full-screen editor route (narrow layouts). Wide layouts embed
/// [TodoEditor] directly in the detail pane.
class TodoEditorScreen extends StatelessWidget {
  const TodoEditorScreen({required this.todo, super.key});

  final Todo todo;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit todo')),
    body: TodoEditor(todo: todo, popOnSave: true),
  );
}

class TodoEditor extends ConsumerStatefulWidget {
  const TodoEditor({required this.todo, this.popOnSave = false, super.key});

  final Todo todo;
  final bool popOnSave;

  @override
  ConsumerState<TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends ConsumerState<TodoEditor> {
  late final _title = TextEditingController(text: widget.todo.title);
  late final _notes = TextEditingController(text: widget.todo.notes);
  late final _tags = TextEditingController(text: widget.todo.tags.join(', '));
  late DateTime? _dueAt = widget.todo.dueAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(widget.todo.dueAtMs!);
  late String? _recurrence = widget.todo.recurrenceRule;
  late int _priority = widget.todo.priority;
  late String? _listId = widget.todo.listId;
  late final Set<int> _alarmOffsets = widget.todo.alarmOffsetsMinutes.toSet();

  static const _alarmOptions = {
    0: 'At due time',
    10: '10 min before',
    60: '1 hour before',
    1440: '1 day before',
  };

  static const _recurrenceOptions = {
    null: 'Does not repeat',
    'FREQ=DAILY': 'Daily',
    'FREQ=WEEKLY': 'Weekly',
    'FREQ=MONTHLY': 'Monthly',
    'FREQ=YEARLY': 'Yearly',
  };

  static const _priorityLabels = ['None', 'Low', 'Medium', 'High'];

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = ref.read(clockProvider).now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt ?? now),
    );
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(todoRepositoryProvider);
    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    await repo.edit(
      widget.todo.id,
      title: Value(_title.text.trim()),
      notes: Value(_notes.text),
      listId: Value(_listId),
      dueAtMs: Value(_dueAt?.millisecondsSinceEpoch),
      recurrenceRule: Value(_recurrence),
      priority: Value(_priority),
      tags: Value(tags),
      alarmOffsetsMinutes: Value(
        _dueAt == null ? const [] : (_alarmOffsets.toList()..sort()),
      ),
    );
    final after = await repo.getById(widget.todo.id);
    if (!mounted) return;
    if (widget.popOnSave) Navigator.of(context).pop();
    if (after == null) return;
    showTodoUndoSnackBar(
      messenger: messenger,
      repo: repo,
      before: widget.todo,
      after: after,
      message: 'Todo updated',
    );
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider).value ?? const <TodoList>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(labelText: 'Notes'),
          maxLines: 4,
          minLines: 2,
        ),
        // The editor has no read mode, so URLs typed into title/notes get
        // open buttons here; list tiles linkify inline (TASKS.md 6.4).
        ListenableBuilder(
          listenable: Listenable.merge([_title, _notes]),
          builder: (context, _) {
            final links = extractLinks('${_title.text}\n${_notes.text}');
            if (links.isEmpty) return const SizedBox.shrink();
            final open = ref.read(urlOpenerProvider);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final link in links)
                    ActionChip(
                      avatar: const Icon(Icons.open_in_new, size: 16),
                      label: Text(
                        link.toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => open(link),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(
            _dueAt == null ? 'No due date' : 'Due ${_formatDue(_dueAt!)}',
          ),
          onTap: _pickDue,
          trailing: _dueAt == null
              ? null
              : IconButton(
                  tooltip: 'Clear due date',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _dueAt = null),
                ),
        ),
        if (_dueAt != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final option in _alarmOptions.entries)
                  FilterChip(
                    label: Text(option.value),
                    avatar: const Icon(Icons.alarm, size: 16),
                    selected: _alarmOffsets.contains(option.key),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _alarmOffsets.add(option.key)
                          : _alarmOffsets.remove(option.key);
                    }),
                  ),
              ],
            ),
          ),
        ],
        DropdownButtonFormField<String?>(
          initialValue: _recurrence,
          decoration: const InputDecoration(labelText: 'Repeat'),
          items: [
            for (final e in _recurrenceOptions.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _recurrence = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _listId,
          decoration: const InputDecoration(labelText: 'List'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Inbox')),
            for (final list in lists)
              DropdownMenuItem(value: list.id, child: Text(list.name)),
          ],
          onChanged: (v) => setState(() => _listId = v),
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: [
            for (var p = 0; p < _priorityLabels.length; p++)
              ButtonSegment(value: p, label: Text(_priorityLabels[p])),
          ],
          selected: {_priority},
          onSelectionChanged: (s) => setState(() => _priority = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tags,
          decoration: const InputDecoration(
            labelText: 'Tags',
            hintText: 'comma, separated',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  static String _formatDue(DateTime due) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${due.year}-${two(due.month)}-${two(due.day)} '
        '${two(due.hour)}:${two(due.minute)}';
  }
}
