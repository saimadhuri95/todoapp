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
    'parentId': 'parent_id',
    'title': 'title',
    'notes': 'notes',
    'dueAtMs': 'due_at_ms',
    'recurrenceRule': 'recurrence_rule',
    'completedAtMs': 'completed_at_ms',
    'priority': 'priority',
    'tagsJson': 'tags_json',
    'section': 'section',
    'sortKey': 'sort_key',
    'alarmOffsetsJson': 'alarm_offsets_json',
    'lastDismissedMs': 'last_dismissed_ms',
    'snoozeUntilMs': 'snooze_until_ms',
    'pinned': 'pinned',
    'estimateMinutes': 'estimate_minutes',
    'energy': 'energy',
    'nagIntervalMinutes': 'nag_interval_minutes',
    'deleted': 'deleted',
  },
  'todo_lists': {
    'name': 'name',
    'color': 'color',
    'sortOrder': 'sort_order',
    // Sharing group assignment (ADR 0004); null = local-only. Which
    // *changesets* carry a list is decided by scoping (8.3), this field
    // is just data like any other.
    'groupId': 'group_id',
    'deleted': 'deleted',
  },
  // Sharing groups replicate within their own scope (ADR 0004).
  // `local_account_ref` is deliberately absent: each member points their
  // own account at the backend, so that column never syncs.
  'sync_groups': {
    'name': 'name',
    'backendKind': 'backend_kind',
    'deleted': 'deleted',
  },
  'group_members': {
    'groupId': 'group_id',
    'deviceId': 'device_id',
    'deleted': 'deleted',
  },
  // Devices announce themselves through sync: accepting a pairing writes
  // your own device row, which replicates to every peer.
  'devices': {
    'name': 'name',
    'platform': 'platform',
    'publicKey': 'public_key',
    'lastSeenAtMs': 'last_seen_at_ms',
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
