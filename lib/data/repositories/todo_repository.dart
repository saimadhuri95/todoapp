import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/hlc.dart';
import '../db/database.dart';
import '../sync/sync_fields.dart';

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
    String notes = '',
    int? dueAtMs,
    String? recurrenceRule,
    int priority = 0,
    List<String> tags = const [],
  }) async {
    final id = _uuid.v7();
    final hlc = _hlc.send();
    await _db.transaction(() async {
      await _db.todos.insertOne(
        TodosCompanion.insert(
          id: id,
          title: title,
          listId: Value(listId),
          notes: Value(notes),
          dueAtMs: Value(dueAtMs),
          recurrenceRule: Value(recurrenceRule),
          priority: Value(priority),
          tagsJson: Value(jsonEncode(tags)),
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
    Value<int?> dueAtMs = const Value.absent(),
    Value<String?> recurrenceRule = const Value.absent(),
    Value<int> priority = const Value.absent(),
    Value<List<String>> tags = const Value.absent(),
    Value<List<int>> alarmOffsetsMinutes = const Value.absent(),
  }) {
    final companion = TodosCompanion(
      title: title,
      notes: notes,
      listId: listId,
      dueAtMs: dueAtMs,
      recurrenceRule: recurrenceRule,
      priority: priority,
      tagsJson: tags.present
          ? Value(jsonEncode(tags.value))
          : const Value.absent(),
      alarmOffsetsJson: alarmOffsetsMinutes.present
          ? Value(jsonEncode(alarmOffsetsMinutes.value))
          : const Value.absent(),
    );
    final changed = [
      if (title.present) 'title',
      if (notes.present) 'notes',
      if (listId.present) 'listId',
      if (dueAtMs.present) 'dueAtMs',
      if (recurrenceRule.present) 'recurrenceRule',
      if (priority.present) 'priority',
      if (tags.present) 'tagsJson',
      if (alarmOffsetsMinutes.present) 'alarmOffsetsJson',
    ];
    return _write(id, companion, changed);
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

  Future<void> complete(String id) => _write(
    id,
    TodosCompanion(completedAtMs: Value(_nowMs())),
    const ['completedAtMs'],
  );

  Future<void> uncomplete(String id) => _write(
    id,
    const TodosCompanion(completedAtMs: Value(null)),
    const ['completedAtMs'],
  );

  /// Tombstone, never a row delete (CLAUDE.md invariant 5).
  Future<void> softDelete(String id) =>
      _write(id, const TodosCompanion(deleted: Value(true)), const ['deleted']);

  Future<void> restore(String id) => _write(
    id,
    const TodosCompanion(deleted: Value(false)),
    const ['deleted'],
  );

  Future<Todo?> getById(String id) =>
      (_db.todos.select()..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Not deleted and not completed, soonest due date first (nulls last).
  Stream<List<Todo>> watchActive({String? listId}) {
    final query = _db.todos.select()
      ..where((t) => t.deleted.equals(false) & t.completedAtMs.isNull())
      ..orderBy([
        // false (has due date) sorts before true → nulls last.
        (t) => OrderingTerm(expression: t.dueAtMs.isNull()),
        (t) => OrderingTerm(expression: t.dueAtMs),
        (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
      ]);
    if (listId != null) {
      query.where((t) => t.listId.equals(listId));
    }
    return query.watch();
  }

  Stream<List<Todo>> watchCompleted() =>
      (_db.todos.select()
            ..where(
              (t) => t.deleted.equals(false) & t.completedAtMs.isNotNull(),
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
}

extension TodoTags on Todo {
  List<String> get tags =>
      (jsonDecode(tagsJson) as List<dynamic>).cast<String>();

  /// Minutes before [Todo.dueAtMs] to ring (0 = at due time).
  List<int> get alarmOffsetsMinutes =>
      (jsonDecode(alarmOffsetsJson) as List<dynamic>).cast<int>();
}
