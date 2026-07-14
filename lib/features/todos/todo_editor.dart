import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/linkify.dart';
import '../../data/db/database.dart';
import '../../data/repositories/todo_repository.dart'
    show TodoRepository, TodoTags;
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
  late final _section = TextEditingController(text: widget.todo.section ?? '');
  late DateTime? _dueAt = widget.todo.dueAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(widget.todo.dueAtMs!);
  // The dropdown holds the base FREQ rule; the completion-anchor extension
  // (TASKS.md 6.56) is a separate switch, recombined on save.
  late String? _recurrence = _stripAnchor(widget.todo.recurrenceRule);
  late bool _repeatFromCompletion =
      widget.todo.recurrenceRule?.contains('ANCHOR=COMPLETION') ?? false;
  late int _priority = widget.todo.priority;
  late int? _estimateMinutes = widget.todo.estimateMinutes;
  late int? _energy = widget.todo.energy;
  late String? _listId = widget.todo.listId;
  late final Set<int> _alarmOffsets = widget.todo.alarmOffsetsMinutes.toSet();
  late int? _nagInterval = widget.todo.nagIntervalMinutes;
  // Location reminder (TASKS.md 6.50): manual lat/lng entry (no map plugin);
  // clearing either coordinate removes the geofence on save.
  late final _geofenceLabel = TextEditingController(
    text: widget.todo.geofenceLabel ?? '',
  );
  late final _geofenceLat = TextEditingController(
    text: widget.todo.geofenceLat?.toString() ?? '',
  );
  late final _geofenceLng = TextEditingController(
    text: widget.todo.geofenceLng?.toString() ?? '',
  );
  late final _geofenceRadius = TextEditingController(
    text: widget.todo.geofenceRadiusM?.toString() ?? '',
  );

  /// Default geofence radius in metres when the user leaves it blank.
  static const _defaultGeofenceRadiusM = 150;

  static const _alarmOptions = {
    0: 'At due time',
    10: '10 min before',
    60: '1 hour before',
    1440: '1 day before',
  };

  /// Nag presets (TASKS.md 6.44): repeat the reminder every N minutes after
  /// the due time until the todo is completed or dismissed.
  static const _nagOptions = {
    null: 'No nagging',
    5: 'Every 5 min until done',
    10: 'Every 10 min until done',
    15: 'Every 15 min until done',
    30: 'Every 30 min until done',
    60: 'Every hour until done',
  };

  static const _recurrenceOptions = {
    null: 'Does not repeat',
    'FREQ=DAILY': 'Daily',
    'FREQ=WEEKLY': 'Weekly',
    'FREQ=MONTHLY': 'Monthly',
    'FREQ=YEARLY': 'Yearly',
  };

  /// The stored rule minus the `ANCHOR=` extension, so it matches a dropdown
  /// option; null if nothing is left.
  static String? _stripAnchor(String? rule) {
    if (rule == null) return null;
    final base = rule
        .split(';')
        .where((p) => !p.startsWith('ANCHOR='))
        .join(';');
    return base.isEmpty ? null : base;
  }

  /// The dropdown rule plus the completion-anchor extension when the switch
  /// is on (TASKS.md 6.56).
  String? _composedRule() {
    if (_recurrence == null) return null;
    return _repeatFromCompletion
        ? '${_recurrence!};ANCHOR=COMPLETION'
        : _recurrence;
  }

  static const _priorityLabels = ['None', 'Low', 'Medium', 'High'];

  /// Quick estimate presets in minutes (TASKS.md 6.35).
  static const _estimatePresets = [5, 10, 15, 30, 60];

  /// Energy levels; index maps to the stored `energy` value (0/1/2). Labels
  /// stay distinct from the priority segments so neither the UI nor tests
  /// confuse the two.
  static const _energyLabels = ['Low energy', 'Medium energy', 'High energy'];

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _tags.dispose();
    _section.dispose();
    _geofenceLabel.dispose();
    _geofenceLat.dispose();
    _geofenceLng.dispose();
    _geofenceRadius.dispose();
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
      recurrenceRule: Value(_composedRule()),
      priority: Value(_priority),
      estimateMinutes: Value(_estimateMinutes),
      energy: Value(_energy),
      tags: Value(tags),
      section: Value(_section.text),
      alarmOffsetsMinutes: Value(
        _dueAt == null ? const [] : (_alarmOffsets.toList()..sort()),
      ),
      nagIntervalMinutes: Value(_dueAt == null ? null : _nagInterval),
    );
    await _saveGeofence(repo);
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

  /// Parses the location fields and writes the geofence only when it actually
  /// changed, so a normal save doesn't bump the geofence clocks (which would
  /// let a stale value win a later merge). Blank or invalid coordinates clear
  /// the reminder.
  Future<void> _saveGeofence(TodoRepository repo) async {
    final lat = double.tryParse(_geofenceLat.text.trim());
    final lng = double.tryParse(_geofenceLng.text.trim());
    final valid =
        lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180;
    final newLat = valid ? lat : null;
    final newLng = valid ? lng : null;
    final newRadius = valid
        ? (int.tryParse(_geofenceRadius.text.trim()) ?? _defaultGeofenceRadiusM)
        : null;
    final label = _geofenceLabel.text.trim();
    final newLabel = valid && label.isNotEmpty ? label : null;
    // Compare against the *current* stored row, not the (possibly stale)
    // widget.todo snapshot: the editor can save more than once in a session
    // (wide-layout detail pane), and only writing on a real change keeps a
    // no-op save from bumping the geofence clocks and clobbering a peer's
    // concurrent edit on merge.
    final current = await repo.getById(widget.todo.id);
    if (current != null &&
        newLat == current.geofenceLat &&
        newLng == current.geofenceLng &&
        newRadius == current.geofenceRadiusM &&
        newLabel == current.geofenceLabel) {
      return;
    }
    await repo.setGeofence(
      widget.todo.id,
      lat: newLat,
      lng: newLng,
      radiusM: newRadius,
      label: newLabel,
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
          // Group label for screen readers, no visual heading (keeps the
          // form height unchanged): announces these chips as "Reminders".
          Semantics(
            container: true,
            label: 'Reminders',
            child: Padding(
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
          ),
          DropdownButtonFormField<int?>(
            initialValue: _nagInterval,
            decoration: const InputDecoration(labelText: 'Nag'),
            items: [
              for (final e in _nagOptions.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _nagInterval = v),
          ),
          const SizedBox(height: 12),
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
        if (_recurrence != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reschedule from completion'),
            subtitle: const Text(
              'Count the next due date from when you finish',
            ),
            value: _repeatFromCompletion,
            onChanged: (v) => setState(() => _repeatFromCompletion = v),
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
        const SizedBox(height: 12),
        TextField(
          controller: _section,
          decoration: const InputDecoration(
            labelText: 'Section',
            hintText: 'Optional, e.g. Errands or Waiting',
          ),
        ),
        const SizedBox(height: 16),
        // Group label for screen readers (no visual heading, so the form's
        // height is unchanged): announces these segments as "Priority".
        Semantics(
          container: true,
          label: 'Priority',
          child: SegmentedButton<int>(
            segments: [
              for (var p = 0; p < _priorityLabels.length; p++)
                ButtonSegment(value: p, label: Text(_priorityLabels[p])),
            ],
            selected: {_priority},
            onSelectionChanged: (s) => setState(() => _priority = s.first),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Save')),
        const SizedBox(height: 12),
        TextField(
          controller: _tags,
          decoration: const InputDecoration(
            labelText: 'Tags',
            hintText: 'comma, separated',
          ),
        ),
        if (widget.todo.parentId == null) ...[
          const SizedBox(height: 16),
          _SubtaskChecklist(parent: widget.todo),
        ],
        const SizedBox(height: 16),
        const Text('Estimate'),
        Wrap(
          spacing: 8,
          children: [
            for (final minutes in _estimatePresets)
              ChoiceChip(
                label: Text('$minutes min'),
                selected: _estimateMinutes == minutes,
                onSelected: (selected) => setState(
                  () => _estimateMinutes = selected ? minutes : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Energy'),
        Wrap(
          spacing: 8,
          children: [
            for (var level = 0; level < _energyLabels.length; level++)
              ChoiceChip(
                label: Text(_energyLabels[level]),
                selected: _energy == level,
                onSelected: (selected) =>
                    setState(() => _energy = selected ? level : null),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Location reminder (TASKS.md 6.50): on-device geofence, fires on
        // arrival. Manual coordinates keep it dependency-free; clearing them
        // removes the reminder on save.
        Semantics(
          container: true,
          label: 'Location reminder',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Location reminder'),
              TextField(
                controller: _geofenceLabel,
                decoration: const InputDecoration(
                  labelText: 'Place name',
                  hintText: 'Optional, e.g. Home or Office',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _geofenceLat,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _geofenceLng,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _geofenceRadius,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Radius m',
                        hintText: '150',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDue(DateTime due) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${due.year}-${two(due.month)}-${two(due.day)} '
        '${two(due.hour)}:${two(due.minute)}';
  }
}

class _SubtaskChecklist extends ConsumerStatefulWidget {
  const _SubtaskChecklist({required this.parent});

  final Todo parent;

  @override
  ConsumerState<_SubtaskChecklist> createState() => _SubtaskChecklistState();
}

class _SubtaskChecklistState extends ConsumerState<_SubtaskChecklist> {
  final _newSubtask = TextEditingController();

  @override
  void dispose() {
    _newSubtask.dispose();
    super.dispose();
  }

  Future<void> _addSubtask() async {
    final title = _newSubtask.text.trim();
    if (title.isEmpty) return;
    await ref.read(todoRepositoryProvider).createSubtasks(widget.parent.id, [
      title,
    ]);
    _newSubtask.clear();
  }

  Future<void> _breakDown() async {
    final lines = await showDialog<List<String>>(
      context: context,
      builder: (context) => const _BreakdownDialog(),
    );
    if (lines == null || lines.isEmpty) return;
    await ref
        .read(todoRepositoryProvider)
        .createSubtasks(widget.parent.id, lines);
  }

  Future<void> _saveTemplate(List<Todo> subtasks) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _TemplateNameDialog(initialName: widget.parent.title),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    await ref
        .read(checklistTemplatesProvider.notifier)
        .add(
          ChecklistTemplate(
            id: '',
            name: trimmed,
            title: widget.parent.title,
            notes: widget.parent.notes,
            subtasks: [for (final subtask in subtasks) subtask.title],
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "$trimmed" as a checklist template')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtasks = ref.watch(subtasksProvider(widget.parent.id));
    final templates = ref.watch(checklistTemplatesProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Checklist',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _breakDown,
                  icon: const Icon(Icons.splitscreen_outlined),
                  label: const Text('Break down'),
                ),
                PopupMenuButton<ChecklistTemplate>(
                  tooltip: 'Apply template',
                  enabled: templates.isNotEmpty,
                  icon: const Icon(Icons.bookmarks_outlined),
                  onSelected: (template) => ref
                      .read(todoRepositoryProvider)
                      .createSubtasks(widget.parent.id, template.subtasks),
                  itemBuilder: (_) => [
                    for (final template in templates)
                      PopupMenuItem(
                        value: template,
                        child: Text(template.name),
                      ),
                  ],
                ),
              ],
            ),
            switch (subtasks) {
              AsyncData(value: final items) => _SubtaskList(
                subtasks: items,
                onSaveTemplate: () => _saveTemplate(items),
              ),
              AsyncError(error: final e) => Text('Checklist error: $e'),
              _ => const LinearProgressIndicator(),
            },
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSubtask,
                    decoration: const InputDecoration(
                      labelText: 'New checklist item',
                    ),
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Add checklist item',
                  onPressed: _addSubtask,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtaskList extends ConsumerWidget {
  const _SubtaskList({required this.subtasks, required this.onSaveTemplate});

  final List<Todo> subtasks;
  final VoidCallback onSaveTemplate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = subtasks.where((todo) => todo.completedAtMs != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subtasks.isEmpty
              ? 'Add steps manually, paste a breakdown, or apply a template.'
              : '$done of ${subtasks.length} complete',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final subtask in subtasks)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: subtask.completedAtMs != null,
            title: Text(
              subtask.title,
              style: subtask.completedAtMs == null
                  ? null
                  : const TextStyle(decoration: TextDecoration.lineThrough),
            ),
            onChanged: (_) {
              final repo = ref.read(todoRepositoryProvider);
              subtask.completedAtMs == null
                  ? repo.complete(subtask.id)
                  : repo.uncomplete(subtask.id);
            },
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onSaveTemplate,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save as template'),
          ),
        ),
      ],
    );
  }
}

class _BreakdownDialog extends StatefulWidget {
  const _BreakdownDialog();

  @override
  State<_BreakdownDialog> createState() => _BreakdownDialogState();
}

class _BreakdownDialogState extends State<_BreakdownDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Break into checklist items'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      minLines: 5,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        hintText: 'One step per line\nDraft outline\nBook room\nSend invite',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.of(context).pop(_splitLines(_controller.text)),
        child: const Text('Create checklist'),
      ),
    ],
  );
}

class _TemplateNameDialog extends StatefulWidget {
  const _TemplateNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save checklist template'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Template name'),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

List<String> _splitLines(String input) => input
    .split(RegExp(r'\r\n|\r|\n'))
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();
