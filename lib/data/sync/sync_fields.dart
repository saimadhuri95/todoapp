import 'package:drift/drift.dart';

import '../../core/hlc.dart';
import '../db/database.dart';

/// (entity, field) → SQL column for every sync-replicated field. Single
/// source of truth shared by local mutation stamping (repositories) and
/// remote apply (LwwApplier); also serves as the allowlist guarding any
/// dynamic SQL built from entity/field names.
const Map<String, Map<String, String>> syncColumns = {
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

/// Records [hlc] as the current clock for each field of a row. Callers must
/// run this inside the same transaction as the mutation it stamps.
Future<void> stampFields({
  required AppDatabase db,
  required String entity,
  required String rowId,
  required Iterable<String> fields,
  required Hlc hlc,
}) async {
  final known = syncColumns[entity];
  final encoded = hlc.encode();
  await db.batch((batch) {
    for (final field in fields) {
      if (known == null || !known.containsKey(field)) {
        throw ArgumentError('Unknown sync field: $entity.$field');
      }
      batch.insert(
        db.fieldClocks,
        FieldClocksCompanion.insert(
          entity: entity,
          rowId: rowId,
          fieldName: field,
          hlc: encoded,
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
  });
}
