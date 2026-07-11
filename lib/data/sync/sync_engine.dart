import 'package:drift/drift.dart';

import '../../core/hlc.dart';
import '../db/database.dart';
import 'changeset.dart';
import 'lww_applier.dart';
import 'sync_fields.dart';

/// Delta generation and application (TASKS.md 3.2/3.4).
///
/// State-based anti-entropy: `field_clocks` + current row values *are* the
/// CRDT state. A device's **version vector** (max HLC seen per origin
/// device, derived from field_clocks — HLCs embed their origin's nodeId)
/// summarizes everything it knows; a peer answers with exactly the writes
/// newer than that vector. This relays third-party writes transitively and
/// — unlike a scalar cursor — cannot lose writes that arrive with old
/// stamps via a different peer.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required HlcClock hlcClock,
    required this.deviceId,
  }) : _db = db,
       _hlc = hlcClock,
       _applier = LwwApplier(db);

  final AppDatabase _db;
  final HlcClock _hlc;
  final LwwApplier _applier;
  final String deviceId;
  var _visibleTodoChanges = 0;

  /// Monotonic count of [apply] calls that changed user-visible todos.
  /// Consumers snapshot it before syncing and compare after — unlike a
  /// take-and-clear flag, concurrent consumers (an inbound LAN session vs.
  /// an orchestrator pass) cannot consume each other's signal.
  int get visibleTodoChanges => _visibleTodoChanges;

  static const _visibleTodoFields = {
    'listId',
    'title',
    'notes',
    'dueAtMs',
    'recurrenceRule',
    'completedAtMs',
    'priority',
    'tagsJson',
    'alarmOffsetsJson',
    'nagIntervalMinutes',
    'deleted',
  };

  /// Max encoded HLC per origin nodeId across everything this device has.
  Future<Map<String, String>> versionVector() async {
    final clocks = await _db.fieldClocks.select().get();
    final vector = <String, String>{};
    for (final clock in clocks) {
      final origin = Hlc.parse(clock.hlc).nodeId;
      final current = vector[origin];
      // Encoded HLCs compare lexicographically in HLC order.
      if (current == null || clock.hlc.compareTo(current) > 0) {
        vector[origin] = clock.hlc;
      }
    }
    return vector;
  }

  /// Everything this device knows that the holder of [remoteVector] does
  /// not. Sorted by HLC so application preserves causality (a list's
  /// creation precedes the todo that references it).
  ///
  /// With [groupId] (TASKS 8.3, ADR 0004) the changeset is **scoped**: it
  /// carries only writes for that sharing group — its lists, their todos,
  /// the group row itself, its memberships, and its member devices.
  /// Nothing else can leak into a shared mailbox. Soundness with the
  /// mailbox's published-vector markers relies on [ListRepository.setGroup]
  /// re-stamping rows that *enter* a scope: an in-scope write older than a
  /// published marker must have been published (anything that entered
  /// scope later carries a fresh stamp). Null = unscoped, the personal
  /// mailbox/LAN behavior (your own devices see everything).
  Future<Changeset> changesFor(
    Map<String, String> remoteVector, {
    String? groupId,
  }) async {
    final scope = groupId == null ? null : await _scopeRowIds(groupId);
    final clocks = await _db.fieldClocks.select().get();
    final writes = <FieldWrite>[];
    for (final clock in clocks) {
      if (scope != null &&
          !(scope[clock.entity]?.contains(clock.rowId) ?? false)) {
        continue;
      }
      final origin = Hlc.parse(clock.hlc).nodeId;
      final known = remoteVector[origin];
      if (known != null && clock.hlc.compareTo(known) <= 0) continue;
      final column = syncColumns[clock.entity]![clock.fieldName]!;
      // Allowlisted names only (syncColumns); rowId is bound, not inlined.
      final row = await _db
          .customSelect(
            'SELECT $column AS v FROM ${clock.entity} WHERE id = ?',
            variables: [Variable<String>(clock.rowId)],
          )
          .getSingleOrNull();
      if (row == null) continue;
      writes.add(
        FieldWrite(
          entity: clock.entity,
          rowId: clock.rowId,
          field: clock.fieldName,
          value: row.data['v'] as Object?,
          hlc: Hlc.parse(clock.hlc),
        ),
      );
    }
    writes.sort((a, b) => a.hlc.compareTo(b.hlc));
    return Changeset(deviceId: deviceId, writes: writes);
  }

  /// Applies a changeset. Idempotent and commutative: re-applying any
  /// prefix, or applying in any order, converges (LWW rejects stale and
  /// duplicate writes). Returns the number of writes that won LWW.
  Future<int> apply(Changeset changeset) async {
    if (changeset.writes.isEmpty) return 0;
    final writes = [...changeset.writes]
      ..sort((a, b) => a.hlc.compareTo(b.hlc));
    // Visibility is compared at the changeset's endpoints, not per write:
    // two batched queries instead of two point lookups per write, and a
    // todo created and tombstoned within one changeset (never shown to the
    // user) correctly counts as no visible change.
    final candidateTodoIds = {
      for (final write in writes)
        if (write.entity == 'todos' && _visibleTodoFields.contains(write.field))
          write.rowId,
    };
    final visibleBefore = await _visibleTodoIds(candidateTodoIds);
    final appliedTodoIds = <String>{};
    var applied = 0;
    for (final write in writes) {
      if (await _applier.apply(write)) {
        applied++;
        if (write.entity == 'todos' &&
            _visibleTodoFields.contains(write.field)) {
          appliedTodoIds.add(write.rowId);
        }
      }
    }
    if (appliedTodoIds.any(visibleBefore.contains) ||
        (await _visibleTodoIds(appliedTodoIds)).isNotEmpty) {
      _visibleTodoChanges++;
    }
    // Keep the local HLC ahead of everything we've seen, and record the
    // exchange for sync-status UI (3.14).
    _hlc.receive(writes.last.hlc);
    await _db.syncLog.insertOne(
      SyncLogCompanion.insert(
        peerId: changeset.deviceId,
        lastAppliedHlc: Value(writes.last.hlc.encode()),
        lastSyncedAtMs: Value(_hlc.clock.now().millisecondsSinceEpoch),
      ),
      mode: InsertMode.insertOrReplace,
    );
    return applied;
  }

  /// Row ids belonging to one sharing group, per entity (TASKS 8.3):
  /// the group row, its memberships + their devices, its lists, and the
  /// todos on those lists.
  Future<Map<String, Set<String>>> _scopeRowIds(String groupId) async {
    final lists =
        await (_db.todoLists.select()..where((l) => l.groupId.equals(groupId)))
            .get();
    final listIds = {for (final l in lists) l.id};
    final todoIds = <String>{};
    if (listIds.isNotEmpty) {
      final todos =
          await (_db.todos.select()..where((t) => t.listId.isIn(listIds)))
              .get();
      todoIds.addAll(todos.map((t) => t.id));
    }
    final members =
        await (_db.groupMembers.select()
              ..where((m) => m.groupId.equals(groupId)))
            .get();
    return {
      'sync_groups': {groupId},
      'group_members': {for (final m in members) m.id},
      'devices': {
        for (final m in members)
          if (m.deviceId != null) m.deviceId!,
      },
      'todo_lists': listIds,
      'todos': todoIds,
    };
  }

  /// Which of [ids] exist and are not tombstoned, in chunks that stay
  /// under SQLite's bind-variable limit even on a 5k-todo first sync.
  Future<Set<String>> _visibleTodoIds(Set<String> ids) async {
    const chunkSize = 500;
    final visible = <String>{};
    final pending = ids.toList();
    for (var i = 0; i < pending.length; i += chunkSize) {
      final chunk = pending.sublist(
        i,
        i + chunkSize > pending.length ? pending.length : i + chunkSize,
      );
      final rows =
          await (_db.todos.select()
                ..where((t) => t.id.isIn(chunk) & t.deleted.equals(false)))
              .get();
      visible.addAll(rows.map((row) => row.id));
    }
    return visible;
  }

  /// One full pull from [peer] into this device.
  Future<int> pullFrom(SyncEngine peer) async =>
      apply(await peer.changesFor(await versionVector()));
}
