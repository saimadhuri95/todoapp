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
  var _visibleTodosChanged = false;

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
  Future<Changeset> changesFor(Map<String, String> remoteVector) async {
    final clocks = await _db.fieldClocks.select().get();
    final writes = <FieldWrite>[];
    for (final clock in clocks) {
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
    var applied = 0;
    for (final write in writes) {
      final tracksVisibleTodo =
          write.entity == 'todos' && _visibleTodoFields.contains(write.field);
      final wasVisible = tracksVisibleTodo
          ? await _todoIsVisible(write.rowId)
          : false;
      if (await _applier.apply(write)) {
        applied++;
        if (tracksVisibleTodo) {
          final isVisible = await _todoIsVisible(write.rowId);
          _visibleTodosChanged =
              _visibleTodosChanged || wasVisible || isVisible;
        }
      }
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

  bool takeVisibleTodosChanged() {
    final changed = _visibleTodosChanged;
    _visibleTodosChanged = false;
    return changed;
  }

  Future<bool> _todoIsVisible(String id) async {
    final todo = await (_db.todos.select()..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return todo != null && !todo.deleted;
  }

  /// One full pull from [peer] into this device.
  Future<int> pullFrom(SyncEngine peer) async =>
      apply(await peer.changesFor(await versionVector()));
}
