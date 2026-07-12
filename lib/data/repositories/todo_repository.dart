import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/hlc.dart';
import '../../core/order_key.dart';
import '../../core/recurrence.dart';
import '../db/database.dart';
import '../sync/sync_fields.dart';

class StaleTodoCandidate {
  const StaleTodoCandidate({required this.todo, required this.lastTouchedAt});

  final Todo todo;
  final DateTime lastTouchedAt;
}

/// All todo mutations go through here: each one updates the row and stamps
/// the changed fields' HLC clocks in the same transaction, so local edits
/// are sync-ready from day one (TASKS.md 1.5). UI never touches the db
/// directly (CLAUDE.md).
class TodoRepository {
  TodoRepository(this._db, this._hlc);

  static const _uuid = Uuid();

  final AppDatabase _db;
  final HlcClock _hlc;

  Future<Todo> create({
    required String title,
    String? listId,
    String? parentId,
    String notes = '',
    int? dueAtMs,
    String? recurrenceRule,
    int priority = 0,
    List<String> tags = const [],
    String? section,
    String? sortKey,
  }) async {
    final id = _uuid.v7();
    final hlc = _hlc.send();
    final normalizedSection = _normalizeSection(section);
    final resolvedSortKey =
        sortKey ??
        await _nextSortKey(
          listId: listId,
          parentId: parentId,
          section: normalizedSection,
        );
    await _db.transaction(() async {
      await _db.todos.insertOne(
        TodosCompanion.insert(
          id: id,
          title: title,
          listId: Value(listId),
          parentId: Value(parentId),
          notes: Value(notes),
          dueAtMs: Value(dueAtMs),
          recurrenceRule: Value(recurrenceRule),
          priority: Value(priority),
          tagsJson: Value(jsonEncode(tags)),
          section: Value(normalizedSection),
          sortKey: Value(resolvedSortKey),
        ),
      );
      await stampFields(
        db: _db,
        entity: 'todos',
        rowId: id,
        fields: syncColumns['todos']!.keys,
        hlc: hlc,
      );
    });
    return (await getById(id))!;
  }

  /// Partial update; only the provided fields are written and re-stamped.
  Future<void> edit(
    String id, {
    Value<String> title = const Value.absent(),
    Value<String> notes = const Value.absent(),
    Value<String?> listId = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    Value<int?> dueAtMs = const Value.absent(),
    Value<String?> recurrenceRule = const Value.absent(),
    Value<int> priority = const Value.absent(),
    Value<List<String>> tags = const Value.absent(),
    Value<String?> section = const Value.absent(),
    Value<String> sortKey = const Value.absent(),
    Value<List<int>> alarmOffsetsMinutes = const Value.absent(),
    Value<int?> estimateMinutes = const Value.absent(),
    Value<int?> energy = const Value.absent(),
    Value<int?> nagIntervalMinutes = const Value.absent(),
    Value<String?> assigneeDeviceId = const Value.absent(),
  }) {
    final companion = TodosCompanion(
      title: title,
      notes: notes,
      listId: listId,
      parentId: parentId,
      dueAtMs: dueAtMs,
      recurrenceRule: recurrenceRule,
      priority: priority,
      estimateMinutes: estimateMinutes,
      energy: energy,
      nagIntervalMinutes: nagIntervalMinutes,
      assigneeDeviceId: assigneeDeviceId,
      tagsJson: tags.present
          ? Value(jsonEncode(tags.value))
          : const Value.absent(),
      section: section.present
          ? Value(_normalizeSection(section.value))
          : const Value.absent(),
      sortKey: sortKey,
      alarmOffsetsJson: alarmOffsetsMinutes.present
          ? Value(jsonEncode(alarmOffsetsMinutes.value))
          : const Value.absent(),
    );
    final changed = [
      if (title.present) 'title',
      if (notes.present) 'notes',
      if (listId.present) 'listId',
      if (parentId.present) 'parentId',
      if (dueAtMs.present) 'dueAtMs',
      if (recurrenceRule.present) 'recurrenceRule',
      if (priority.present) 'priority',
      if (tags.present) 'tagsJson',
      if (section.present) 'section',
      if (sortKey.present) 'sortKey',
      if (alarmOffsetsMinutes.present) 'alarmOffsetsJson',
      if (estimateMinutes.present) 'estimateMinutes',
      if (energy.present) 'energy',
      if (nagIntervalMinutes.present) 'nagIntervalMinutes',
      if (assigneeDeviceId.present) 'assigneeDeviceId',
    ];
    return _write(id, companion, changed);
  }

  /// Assigns/unassigns a shared-list task to a group member (TASKS.md 6.51).
  Future<void> setAssignee(String id, String? deviceId) => _write(
    id,
    TodosCompanion(assigneeDeviceId: Value(deviceId)),
    const ['assigneeDeviceId'],
  );

  Future<List<Todo>> createSubtasks(
    String parentId,
    Iterable<String> titles,
  ) async {
    final parent = await getById(parentId);
    if (parent == null) throw StateError('No todo with id $parentId');
    final cleaned = [
      for (final title in titles)
        if (title.trim().isNotEmpty) title.trim(),
    ];
    if (cleaned.isEmpty) return const [];

    final created = <Todo>[];
    var previous = await _lastSortKey(
      listId: parent.listId,
      parentId: parentId,
      section: parent.section,
    );
    for (final title in cleaned) {
      final sortKey = orderKeyBetween(previous, null);
      created.add(
        await create(
          title: title,
          listId: parent.listId,
          parentId: parentId,
          section: parent.section,
          sortKey: sortKey,
        ),
      );
      previous = sortKey;
    }
    return created;
  }

  Future<void> replaceVisibleOrder(
    List<Todo> ordered, {
    Map<String, String?> sectionsById = const {},
  }) async {
    final hlc = _hlc.send();
    await _db.transaction(() async {
      for (var index = 0; index < ordered.length; index++) {
        final todo = ordered[index];
        final section = _normalizeSection(
          sectionsById[todo.id] ?? todo.section,
        );
        final sortKey = spacedOrderKey(index);
        final changed = <String>['sortKey'];
        if (section != todo.section) changed.add('section');
        await (_db.todos.update()..where((t) => t.id.equals(todo.id))).write(
          TodosCompanion(sortKey: Value(sortKey), section: Value(section)),
        );
        await stampFields(
          db: _db,
          entity: 'todos',
          rowId: todo.id,
          fields: changed,
          hlc: hlc,
        );
      }
    });
  }

  /// Dismisses the alarm for [occurrenceMs]. This is a synced field write
  /// (TASKS.md 3.15): peers suppress the same occurrence and cancel any
  /// scheduled notification for it. Also clears a pending snooze.
  Future<void> dismissAlarm(String id, int occurrenceMs) => _write(
    id,
    TodosCompanion(
      lastDismissedMs: Value(occurrenceMs),
      snoozeUntilMs: const Value(null),
    ),
    const ['lastDismissedMs', 'snoozeUntilMs'],
  );

  /// Snoozes the current alarm until [untilMs]; the planner emits one
  /// extra fire at that moment.
  Future<void> snoozeAlarm(String id, int untilMs) => _write(
    id,
    TodosCompanion(snoozeUntilMs: Value(untilMs)),
    const ['snoozeUntilMs'],
  );

  /// Completing a recurring todo advances it to its next occurrence instead
  /// of completing the row (TASKS.md 6.9). In-place field writes are the
  /// CRDT-safe shape: two devices completing concurrently compute the same
  /// next due and LWW converges, whereas spawning a fresh row per completion
  /// would duplicate on merge. Overdue completions jump past now rather than
  /// landing on another already-past occurrence; early completions skip the
  /// pending one. The stale snooze is cleared; lastDismissedMs stays (it
  /// only silences occurrences ≤ itself).
  Future<void> complete(String id) async {
    final todo = await getById(id);
    final rule = todo?.recurrenceRule;
    final dueMs = todo?.dueAtMs;
    Recurrence? recurrence;
    if (rule != null) {
      try {
        recurrence = Recurrence.parse(rule);
      } on FormatException {
        // A malformed rule (bad sync input) shouldn't block completion.
      }
    }
    if (recurrence == null || dueMs == null) {
      return _write(id, TodosCompanion(completedAtMs: Value(_nowMs())), const [
        'completedAtMs',
      ]);
    }
    final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
    final now = DateTime.fromMillisecondsSinceEpoch(_nowMs());
    // A chore ("every N days after I do it") reschedules from completion time;
    // a normal schedule advances to the next slot after now/due (TASKS.md 6.56).
    final next = recurrence.anchor == RecurrenceAnchor.completion
        ? recurrence.nextFromCompletion(now, anchor: due)
        : recurrence.nextAfter(now.isAfter(due) ? now : due, anchor: due);
    // Habit streaks (TASKS.md 6.11): completing at or before the due moment
    // extends the streak; completing an already-overdue occurrence resets it
    // to 1 (this completion still counts, it just wasn't on time).
    final nextStreak = now.isAfter(due) ? 1 : (todo!.currentStreak + 1);
    return _write(
      id,
      TodosCompanion(
        dueAtMs: Value(next.millisecondsSinceEpoch),
        snoozeUntilMs: const Value(null),
        currentStreak: Value(nextStreak),
      ),
      const ['dueAtMs', 'snoozeUntilMs', 'currentStreak'],
    );
  }

  Future<void> uncomplete(String id) => _write(
    id,
    const TodosCompanion(completedAtMs: Value(null)),
    const ['completedAtMs'],
  );

  /// Pins/unpins a todo for the "Top 3" section (TASKS.md 6.34). A synced
  /// LWW field write; the 3-item cap is enforced in the UI, not here.
  Future<void> setPinned(String id, bool pinned) =>
      _write(id, TodosCompanion(pinned: Value(pinned)), const ['pinned']);

  /// Tombstone, never a row delete (CLAUDE.md invariant 5).
  Future<void> softDelete(String id) =>
      _write(id, const TodosCompanion(deleted: Value(true)), const ['deleted']);

  Future<void> restore(String id) => _write(
    id,
    const TodosCompanion(deleted: Value(false)),
    const ['deleted'],
  );

  /// Re-applies values from an earlier synced [snapshot], typically for
  /// short-lived UI undo flows. Restrict [fields] so the undo only reverts
  /// columns touched by the original action.
  Future<void> restoreSnapshot(
    Todo snapshot, {
    Iterable<String>? fields,
  }) async {
    final requested = {...?fields};
    final allowed = syncColumns['todos']!.keys.toSet();
    if (requested.isEmpty) {
      requested.addAll(allowed);
    }
    final unknown = requested.difference(allowed);
    if (unknown.isNotEmpty) {
      throw ArgumentError('Unknown todo snapshot fields: $unknown');
    }
    return _write(
      snapshot.id,
      TodosCompanion(
        listId: requested.contains('listId')
            ? Value(snapshot.listId)
            : const Value.absent(),
        parentId: requested.contains('parentId')
            ? Value(snapshot.parentId)
            : const Value.absent(),
        title: requested.contains('title')
            ? Value(snapshot.title)
            : const Value.absent(),
        notes: requested.contains('notes')
            ? Value(snapshot.notes)
            : const Value.absent(),
        dueAtMs: requested.contains('dueAtMs')
            ? Value(snapshot.dueAtMs)
            : const Value.absent(),
        recurrenceRule: requested.contains('recurrenceRule')
            ? Value(snapshot.recurrenceRule)
            : const Value.absent(),
        completedAtMs: requested.contains('completedAtMs')
            ? Value(snapshot.completedAtMs)
            : const Value.absent(),
        priority: requested.contains('priority')
            ? Value(snapshot.priority)
            : const Value.absent(),
        tagsJson: requested.contains('tagsJson')
            ? Value(snapshot.tagsJson)
            : const Value.absent(),
        section: requested.contains('section')
            ? Value(snapshot.section)
            : const Value.absent(),
        sortKey: requested.contains('sortKey')
            ? Value(snapshot.sortKey)
            : const Value.absent(),
        alarmOffsetsJson: requested.contains('alarmOffsetsJson')
            ? Value(snapshot.alarmOffsetsJson)
            : const Value.absent(),
        lastDismissedMs: requested.contains('lastDismissedMs')
            ? Value(snapshot.lastDismissedMs)
            : const Value.absent(),
        snoozeUntilMs: requested.contains('snoozeUntilMs')
            ? Value(snapshot.snoozeUntilMs)
            : const Value.absent(),
        deleted: requested.contains('deleted')
            ? Value(snapshot.deleted)
            : const Value.absent(),
      ),
      requested.toList(),
    );
  }

  Future<Todo?> getById(String id) =>
      (_db.todos.select()..where((t) => t.id.equals(id))).getSingleOrNull();

  /// The device that most recently wrote any field of todo [id] — the
  /// "changed by ..." attribution (TASKS.md 6.51). The winning field
  /// clock's HLC carries the writer's node id; this resolves it to that
  /// device's display name, falling back to the raw node id for a peer whose
  /// identity row hasn't synced yet. Null when the row has no clocks.
  Future<String?> lastChangedBy(String id) async {
    final clocks =
        await (_db.fieldClocks.select()
              ..where((c) => c.entity.equals('todos') & c.rowId.equals(id)))
            .get();
    if (clocks.isEmpty) return null;
    final latest = clocks
        .map((c) => Hlc.parse(c.hlc))
        .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final device =
        await (_db.devices.select()..where((d) => d.id.equals(latest.nodeId)))
            .getSingleOrNull();
    return device?.name ?? latest.nodeId;
  }

  Stream<List<Todo>> watchSubtasks(String parentId) =>
      (_db.todos.select()
            ..where(
              (t) => t.deleted.equals(false) & t.parentId.equals(parentId),
            )
            ..orderBy([
              (t) => OrderingTerm(expression: t.completedAtMs.isNotNull()),
              (t) => OrderingTerm(expression: t.sortKey),
              (t) => OrderingTerm(expression: t.id),
            ]))
          .watch();

  /// Not deleted and not completed, soonest due date first (nulls last).
  /// [unfiledOnly] restricts to Inbox todos (no list); [somedayOnly]
  /// restricts to no-due-date todos. Both win over [listId].
  Stream<List<Todo>> watchActive({
    String? listId,
    bool unfiledOnly = false,
    bool somedayOnly = false,
  }) {
    final query = _db.todos.select()
      ..where(
        (t) =>
            t.deleted.equals(false) &
            t.completedAtMs.isNull() &
            t.parentId.isNull(),
      )
      ..orderBy([
        // false (has due date) sorts before true → nulls last.
        (t) => OrderingTerm(expression: t.dueAtMs.isNull()),
        (t) => OrderingTerm(expression: t.dueAtMs),
        (t) => OrderingTerm(expression: t.section.isNull()),
        (t) => OrderingTerm(expression: t.section),
        (t) => OrderingTerm(expression: t.sortKey),
        (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id),
      ]);
    if (somedayOnly) {
      query.where((t) => t.dueAtMs.isNull());
    } else if (unfiledOnly) {
      query.where((t) => t.listId.isNull());
    } else if (listId != null) {
      query.where((t) => t.listId.equals(listId));
    }
    return query.watch();
  }

  Future<List<StaleTodoCandidate>> staleCandidates({
    required DateTime now,
    Duration untouchedFor = const Duration(days: 28),
  }) async {
    final todos =
        await (_db.todos.select()..where(
              (t) =>
                  t.deleted.equals(false) &
                  t.completedAtMs.isNull() &
                  t.parentId.isNull() &
                  t.dueAtMs.isNotNull(),
            ))
            .get();
    if (todos.isEmpty) return const [];

    final todoIds = todos.map((todo) => todo.id).toList();
    final clocks =
        await (_db.fieldClocks.select()
              ..where((c) => c.entity.equals('todos') & c.rowId.isIn(todoIds)))
            .get();
    final latestTouchedMs = <String, int>{};
    for (final clock in clocks) {
      final millis = Hlc.parse(clock.hlc).millis;
      final previous = latestTouchedMs[clock.rowId];
      if (previous == null || millis > previous) {
        latestTouchedMs[clock.rowId] = millis;
      }
    }

    final cutoffMs = now.subtract(untouchedFor).millisecondsSinceEpoch;
    final candidates = [
      for (final todo in todos)
        if ((latestTouchedMs[todo.id] ?? now.millisecondsSinceEpoch) < cutoffMs)
          StaleTodoCandidate(
            todo: todo,
            lastTouchedAt: DateTime.fromMillisecondsSinceEpoch(
              latestTouchedMs[todo.id]!,
            ),
          ),
    ];
    candidates.sort((a, b) => a.lastTouchedAt.compareTo(b.lastTouchedAt));
    return candidates;
  }

  Stream<List<Todo>> watchCompleted() =>
      (_db.todos.select()
            ..where(
              (t) =>
                  t.deleted.equals(false) &
                  t.parentId.isNull() &
                  t.completedAtMs.isNotNull(),
            )
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.completedAtMs,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Future<void> _write(
    String id,
    TodosCompanion companion,
    List<String> changedFields,
  ) async {
    if (changedFields.isEmpty) return;
    final hlc = _hlc.send();
    await _db.transaction(() async {
      final updated = await (_db.todos.update()..where((t) => t.id.equals(id)))
          .write(companion);
      if (updated == 0) {
        throw StateError('No todo with id $id');
      }
      await stampFields(
        db: _db,
        entity: 'todos',
        rowId: id,
        fields: changedFields,
        hlc: hlc,
      );
    });
  }

  int _nowMs() => _hlc.clock.now().millisecondsSinceEpoch;

  Future<String> _nextSortKey({
    required String? listId,
    required String? parentId,
    required String? section,
  }) async {
    final last = await _lastSortKey(
      listId: listId,
      parentId: parentId,
      section: section,
    );
    return orderKeyBetween(last, null);
  }

  Future<String?> _lastSortKey({
    required String? listId,
    required String? parentId,
    required String? section,
  }) async {
    final query = _db.todos.select()
      ..where((t) => t.deleted.equals(false))
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortKey, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ])
      ..limit(1);
    query.where(
      (t) => listId == null ? t.listId.isNull() : t.listId.equals(listId),
    );
    query.where(
      (t) =>
          parentId == null ? t.parentId.isNull() : t.parentId.equals(parentId),
    );
    query.where(
      (t) => section == null ? t.section.isNull() : t.section.equals(section),
    );
    return (await query.getSingleOrNull())?.sortKey;
  }
}

extension TodoTags on Todo {
  List<String> get tags =>
      (jsonDecode(tagsJson) as List<dynamic>).cast<String>();

  /// Minutes before [Todo.dueAtMs] to ring (0 = at due time).
  List<int> get alarmOffsetsMinutes =>
      (jsonDecode(alarmOffsetsJson) as List<dynamic>).cast<int>();
}

String? _normalizeSection(String? section) {
  final value = section?.trim();
  return value == null || value.isEmpty ? null : value;
}
