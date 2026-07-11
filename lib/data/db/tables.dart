import 'package:drift/drift.dart';

/// Schema v1. Conventions (see docs/architecture.md):
/// - ids are UUIDv7 strings
/// - deletes are tombstones (`deleted` flag), never row removal
/// - instants stored as UTC epoch millis (`*Ms`); alarm wall times stored as
///   local ISO-8601 + IANA zone id so they survive timezone changes
/// - per-field HLC stamps live in [FieldClocks]

class TodoLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Sharing group this list syncs through (schema v4, ADR 0004);
  /// **null = local-only, the default** — the list never leaves the
  /// device until the user assigns a group.
  TextColumn get groupId => text().nullable().references(SyncGroups, #id)();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Sharing groups (schema v4, ADR 0004): a group binds a mailbox backend,
/// a per-group key (kept in the keychain, never in the database), member
/// devices ([GroupMembers]) and the lists assigned to it. The row itself
/// replicates *within its own group's scope* like any other synced row.
class SyncGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Where the group's mailbox lives — a CloudProviderId name ('icloud',
  /// 'webdav', 'dropbox', …) or 'folder' for a plain synced directory.
  /// Group-global: every member uses the same backend kind.
  TextColumn get backendKind => text().withDefault(const Constant(''))();

  /// Device-local pointer to *this device's* way into the backend (its
  /// own account id / folder path). Deliberately **not** a synced field:
  /// each member brings their own account (ADR 0004).
  TextColumn get localAccountRef => text().nullable()();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Group membership (schema v4, ADR 0004): one row per (group, device).
/// The primary key is the deterministic string `<groupId>:<deviceId>` so
/// two devices learning of the same membership concurrently converge on
/// one row (LWW-map semantics need a single-string row id). [groupId] and
/// [deviceId] are nullable so a row can spring into existence from any
/// field write and be filled in as the rest arrive; the FKs hold once set.
class GroupMembers extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().nullable().references(SyncGroups, #id)();
  TextColumn get deviceId => text().nullable().references(Devices, #id)();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text().nullable().references(TodoLists, #id)();

  /// Subtasks/checklist items are ordinary synced todo rows (schema v5).
  /// A null parent is a top-level task; child rows keep their own LWW clocks.
  TextColumn get parentId => text().nullable().references(Todos, #id)();

  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get dueAtMs => integer().nullable()();
  TextColumn get recurrenceRule => text().nullable()();
  IntColumn get completedAtMs => integer().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();

  /// User-defined section within a list, null for date-driven grouping.
  TextColumn get section => text().nullable()();

  /// Fractional, lexicographically sortable order key for manual ordering.
  TextColumn get sortKey => text().withDefault(const Constant(''))();

  /// Alarms (schema v3): JSON array of minute-offsets before [dueAtMs]
  /// (0 = at due time). LWW fields on the todo so they sync like
  /// everything else — the todo_alarms table is unused (see docs/alarms.md).
  TextColumn get alarmOffsetsJson => text().withDefault(const Constant('[]'))();

  /// Last dismissed occurrence (epoch ms). Dismissal *is* a synced field
  /// write: every device suppresses alarms for occurrences ≤ this.
  IntColumn get lastDismissedMs => integer().nullable()();

  /// Snoozed-until moment (epoch ms); one extra fire at this time.
  IntColumn get snoozeUntilMs => integer().nullable()();

  /// "Top 3" must-dos (schema v4, TASKS.md 6.34): pinned todos surface in a
  /// section above Today. A synced LWW field like the rest; the 3-item cap is
  /// a UI guardrail, not a storage constraint.
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  /// Rough time estimate in minutes (schema v7, TASKS.md 6.35): drives the
  /// "I have 10 minutes" quick-win filter. Null = unestimated.
  IntColumn get estimateMinutes => integer().nullable()();

  /// Energy required (schema v7, TASKS.md 6.35): 0 low / 1 medium / 2 high.
  /// Null = unset. Metadata only for now; feeds future energy-aware views.
  IntColumn get energy => integer().nullable()();

  /// Nag interval in minutes (schema v8, TASKS.md 6.44): once an occurrence
  /// is due, keep re-firing every N minutes until it is completed or
  /// dismissed. Null = no nagging. Scheduling itself stays local; the
  /// setting syncs like any other LWW field.
  IntColumn get nagIntervalMinutes => integer().nullable()();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TodoAlarms extends Table {
  TextColumn get id => text()();
  TextColumn get todoId => text().references(Todos, #id)();

  /// Local wall time, ISO-8601 without offset (e.g. `2026-07-05T09:00`).
  TextColumn get atLocal => text()();

  /// IANA zone id the wall time is anchored to (e.g. `Asia/Kolkata`).
  TextColumn get tz => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Paired peer devices (this device included).
class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get platform => text()();
  TextColumn get publicKey => text()();
  IntColumn get lastSeenAtMs => integer().nullable()();

  /// Tombstone (schema v2): revoked devices stay as rows so the revocation
  /// itself replicates.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Sync cursor per peer: everything up to and including [lastAppliedHlc]
/// from that peer has been applied locally.
class SyncLog extends Table {
  TextColumn get peerId => text()();
  TextColumn get lastAppliedHlc => text().withDefault(const Constant(''))();

  /// Wall-clock time of the last exchange (schema v2) — for the
  /// "last synced" display only, never for merge decisions.
  IntColumn get lastSyncedAtMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {peerId};
}

/// Synced record that an alarm occurrence was dismissed/snoozed somewhere,
/// so every device cancels its matching scheduled notification.
class AlarmDismissals extends Table {
  TextColumn get alarmId => text().references(TodoAlarms, #id)();

  /// Which occurrence (UTC epoch millis) — recurring alarms fire many times.
  IntColumn get occurrenceMs => integer()();
  TextColumn get dismissedBy => text()();
  TextColumn get hlc => text()();

  /// 'dismiss' | 'snooze'
  TextColumn get action => text()();
  IntColumn get snoozeUntilMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {alarmId, occurrenceMs};
}

/// Per-field HLC stamps for LWW merge, keyed by (table, row, field).
class FieldClocks extends Table {
  /// Which table the row lives in, e.g. 'todos'. (Named `entity` because
  /// `tableName` collides with drift's `Table.tableName`.)
  TextColumn get entity => text()();
  TextColumn get rowId => text()();
  TextColumn get fieldName => text()();
  TextColumn get hlc => text()();

  @override
  Set<Column<Object>> get primaryKey => {entity, rowId, fieldName};
}
