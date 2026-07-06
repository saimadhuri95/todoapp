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
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text().nullable().references(TodoLists, #id)();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get dueAtMs => integer().nullable()();
  TextColumn get recurrenceRule => text().nullable()();
  IntColumn get completedAtMs => integer().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();

  /// Alarms (schema v3): JSON array of minute-offsets before [dueAtMs]
  /// (0 = at due time). LWW fields on the todo so they sync like
  /// everything else — the todo_alarms table is unused (see docs/alarms.md).
  TextColumn get alarmOffsetsJson => text().withDefault(const Constant('[]'))();

  /// Last dismissed occurrence (epoch ms). Dismissal *is* a synced field
  /// write: every device suppresses alarms for occurrences ≤ this.
  IntColumn get lastDismissedMs => integer().nullable()();

  /// Snoozed-until moment (epoch ms); one extra fire at this time.
  IntColumn get snoozeUntilMs => integer().nullable()();

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
