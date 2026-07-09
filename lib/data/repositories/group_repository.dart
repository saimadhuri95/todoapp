import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/hlc.dart';
import '../db/database.dart';
import '../sync/sync_fields.dart';

/// Mutations for sharing groups and their membership (ADR 0004, TASKS
/// 8.2); same stamp-in-transaction contract as the other repositories.
/// Group *keys* live in the keychain (8.5), never here.
class GroupRepository {
  GroupRepository(this._db, this._hlc);

  static const _uuid = Uuid();

  final AppDatabase _db;
  final HlcClock _hlc;

  /// Creates a group. [localAccountRef] is this device's own way into the
  /// backend and is not a synced field — members each set their own.
  Future<SyncGroup> create({
    required String name,
    required String backendKind,
    String? localAccountRef,
  }) async {
    final id = _uuid.v7();
    final hlc = _hlc.send();
    await _db.transaction(() async {
      await _db.syncGroups.insertOne(
        SyncGroupsCompanion.insert(
          id: id,
          name: name,
          backendKind: Value(backendKind),
          localAccountRef: Value(localAccountRef),
        ),
      );
      await stampFields(
        db: _db,
        entity: 'sync_groups',
        rowId: id,
        fields: syncColumns['sync_groups']!.keys,
        hlc: hlc,
      );
    });
    return (await getById(id))!;
  }

  Future<void> rename(String id, String name) async {
    final hlc = _hlc.send();
    await _db.transaction(() async {
      final updated =
          await (_db.syncGroups.update()..where((g) => g.id.equals(id))).write(
            SyncGroupsCompanion(name: Value(name)),
          );
      if (updated == 0) throw StateError('No group with id $id');
      await stampFields(
        db: _db,
        entity: 'sync_groups',
        rowId: id,
        fields: const ['name'],
        hlc: hlc,
      );
    });
  }

  /// Device-local only (not synced, not stamped): where *this* device
  /// reaches the group's backend.
  Future<void> setLocalAccountRef(String id, String? ref) async {
    final updated =
        await (_db.syncGroups.update()..where((g) => g.id.equals(id))).write(
          SyncGroupsCompanion(localAccountRef: Value(ref)),
        );
    if (updated == 0) throw StateError('No group with id $id');
  }

  /// Tombstone (invariant 5). Lists keep their groupId; views resolve a
  /// deleted group as local-only rather than cascading.
  Future<void> dissolve(String id) async {
    final hlc = _hlc.send();
    await _db.transaction(() async {
      await (_db.syncGroups.update()..where((g) => g.id.equals(id))).write(
        const SyncGroupsCompanion(deleted: Value(true)),
      );
      await stampFields(
        db: _db,
        entity: 'sync_groups',
        rowId: id,
        fields: const ['deleted'],
        hlc: hlc,
      );
    });
  }

  /// Deterministic membership row id: two devices recording the same
  /// membership concurrently converge on one row.
  static String memberRowId(String groupId, String deviceId) =>
      '$groupId:$deviceId';

  /// Records that [deviceId] belongs to [groupId] (idempotent — rejoining
  /// clears a leave tombstone).
  Future<void> addMember(String groupId, String deviceId) async {
    final id = memberRowId(groupId, deviceId);
    final hlc = _hlc.send();
    await _db.transaction(() async {
      await _db.groupMembers.insertOne(
        GroupMembersCompanion.insert(
          id: id,
          groupId: Value(groupId),
          deviceId: Value(deviceId),
          deleted: const Value(false),
        ),
        mode: InsertMode.insertOrReplace,
      );
      await stampFields(
        db: _db,
        entity: 'group_members',
        rowId: id,
        fields: syncColumns['group_members']!.keys,
        hlc: hlc,
      );
    });
  }

  /// Tombstones the membership. Key rotation on removal is 8.5's job.
  Future<void> removeMember(String groupId, String deviceId) async {
    final id = memberRowId(groupId, deviceId);
    final hlc = _hlc.send();
    await _db.transaction(() async {
      final updated =
          await (_db.groupMembers.update()..where((m) => m.id.equals(id)))
              .write(const GroupMembersCompanion(deleted: Value(true)));
      if (updated == 0) throw StateError('No membership $id');
      await stampFields(
        db: _db,
        entity: 'group_members',
        rowId: id,
        fields: const ['deleted'],
        hlc: hlc,
      );
    });
  }

  Future<SyncGroup?> getById(String id) =>
      (_db.syncGroups.select()..where((g) => g.id.equals(id)))
          .getSingleOrNull();

  /// Active groups, name order.
  Stream<List<SyncGroup>> watchAll() =>
      (_db.syncGroups.select()
            ..where((g) => g.deleted.equals(false))
            ..orderBy([(g) => OrderingTerm(expression: g.name)]))
          .watch();

  /// Active (non-tombstoned) lists assigned to one group.
  Stream<int> watchListCount(String groupId) =>
      (_db.todoLists.select()
            ..where((l) => l.groupId.equals(groupId) & l.deleted.equals(false)))
          .watch()
          .map((rows) => rows.length);

  /// Active member device ids of one group.
  Stream<List<String>> watchMemberIds(String groupId) =>
      (_db.groupMembers.select()
            ..where((m) => m.groupId.equals(groupId) & m.deleted.equals(false)))
          .watch()
          .map(
            (rows) => [
              for (final row in rows)
                if (row.deviceId != null) row.deviceId!,
            ],
          );
}
