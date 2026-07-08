import 'package:drift/drift.dart';

import '../../core/hlc.dart';
import '../db/database.dart';
import 'sync_fields.dart';

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

  /// Rows spring into existence when the first write for them arrives
  /// (LWW-map semantics): required NOT NULL columns get placeholder values
  /// that the accompanying field writes overwrite. Allowlisted SQL only.
  static const _ensureRowSql = {
    'todos': "INSERT OR IGNORE INTO todos (id, title) VALUES (?, '')",
    'todo_lists': "INSERT OR IGNORE INTO todo_lists (id, name) VALUES (?, '')",
    'devices':
        'INSERT OR IGNORE INTO devices (id, name, platform, public_key) '
        "VALUES (?, '', '', '')",
    'sync_groups':
        "INSERT OR IGNORE INTO sync_groups (id, name) VALUES (?, '')",
    'group_members': 'INSERT OR IGNORE INTO group_members (id) VALUES (?)',
  };

  /// Referenced rows spring into existence too, else a reordered FK-value
  /// write would fail before the referenced row's own writes arrive.
  static const _fkSpring = {
    ('todos', 'listId'): 'todo_lists',
    ('todo_lists', 'groupId'): 'sync_groups',
    ('group_members', 'groupId'): 'sync_groups',
    ('group_members', 'deviceId'): 'devices',
  };

  /// Returns true if the write was applied, false if it lost LWW (or was a
  /// duplicate). Ties (identical HLC) are duplicates by definition — HLCs
  /// embed the writer's nodeId, so two devices can never mint the same one.
  Future<bool> apply(FieldWrite w) {
    final column = syncColumns[w.entity]?[w.field];
    final ensureRow = _ensureRowSql[w.entity];
    if (column == null || ensureRow == null) {
      throw ArgumentError('Unknown entity/field: ${w.entity}.${w.field}');
    }
    return _db.transaction(() async {
      await _db.customStatement(ensureRow, [w.rowId]);
      final referenced = _fkSpring[(w.entity, w.field)];
      if (referenced != null && w.value != null) {
        await _db.customStatement(_ensureRowSql[referenced]!, [
          w.value as String,
        ]);
      }
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
