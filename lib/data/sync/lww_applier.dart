import 'package:drift/drift.dart';

import '../../core/hlc.dart';
import '../db/database.dart';

/// A single field-level write, the unit of sync in the hand-rolled CRDT
/// (see docs/decisions/0001-crdt-choice.md). Row creation/deletion ops are
/// added with the changeset format in Phase 3.
class FieldWrite {
  const FieldWrite({
    required this.entity,
    required this.rowId,
    required this.field,
    required this.value,
    required this.hlc,
  });

  final String entity;
  final String rowId;
  final String field;
  final Object? value;
  final Hlc hlc;
}

/// Applies remote field writes with last-writer-wins semantics: a write
/// lands only if its HLC is strictly newer than the stored field clock.
/// Idempotent and commutative — apply order and duplicates don't matter.
class LwwApplier {
  LwwApplier(this._db);

  final AppDatabase _db;

  /// Allowlisted (entity, field) → SQL column. Guards the dynamic SQL in
  /// [apply]; never interpolate unvalidated names.
  static const Map<String, Map<String, String>> _columns = {
    'todos': {
      'listId': 'list_id',
      'title': 'title',
      'notes': 'notes',
      'dueAtMs': 'due_at_ms',
      'recurrenceRule': 'recurrence_rule',
      'completedAtMs': 'completed_at_ms',
      'priority': 'priority',
      'tagsJson': 'tags_json',
      'deleted': 'deleted',
    },
    'todo_lists': {
      'name': 'name',
      'color': 'color',
      'sortOrder': 'sort_order',
      'deleted': 'deleted',
    },
  };

  /// Returns true if the write was applied, false if it lost LWW (or was a
  /// duplicate). Ties (identical HLC) are duplicates by definition — HLCs
  /// embed the writer's nodeId, so two devices can never mint the same one.
  Future<bool> apply(FieldWrite w) {
    final column = _columns[w.entity]?[w.field];
    if (column == null) {
      throw ArgumentError('Unknown entity/field: ${w.entity}.${w.field}');
    }
    return _db.transaction(() async {
      final existing =
          await (_db.fieldClocks.select()..where(
                (c) =>
                    c.entity.equals(w.entity) &
                    c.rowId.equals(w.rowId) &
                    c.fieldName.equals(w.field),
              ))
              .getSingleOrNull();
      if (existing != null && !(w.hlc > Hlc.parse(existing.hlc))) {
        return false;
      }
      await _db.customStatement(
        'UPDATE ${w.entity} SET $column = ? WHERE id = ?',
        [w.value, w.rowId],
      );
      await _db.fieldClocks.insertOne(
        FieldClocksCompanion.insert(
          entity: w.entity,
          rowId: w.rowId,
          fieldName: w.field,
          hlc: w.hlc.encode(),
        ),
        mode: InsertMode.insertOrReplace,
      );
      return true;
    });
  }
}
