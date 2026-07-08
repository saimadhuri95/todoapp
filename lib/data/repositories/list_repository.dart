import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/hlc.dart';
import '../db/database.dart';
import '../sync/sync_fields.dart';

/// Mutations for todo lists; same stamp-in-transaction contract as
/// [TodoRepository].
class ListRepository {
  ListRepository(this._db, this._hlc);

  static const _uuid = Uuid();

  final AppDatabase _db;
  final HlcClock _hlc;

  Future<TodoList> create({required String name, int? color}) async {
    final id = _uuid.v7();
    final hlc = _hlc.send();
    await _db.transaction(() async {
      await _db.todoLists.insertOne(
        TodoListsCompanion.insert(id: id, name: name, color: Value(color)),
      );
      await stampFields(
        db: _db,
        entity: 'todo_lists',
        rowId: id,
        fields: syncColumns['todo_lists']!.keys,
        hlc: hlc,
      );
    });
    return (await getById(id))!;
  }

  Future<void> rename(String id, String name) =>
      _write(id, TodoListsCompanion(name: Value(name)), const ['name']);

  Future<void> setColor(String id, int? color) =>
      _write(id, TodoListsCompanion(color: Value(color)), const ['color']);

  Future<void> setSortOrder(String id, int sortOrder) => _write(
    id,
    TodoListsCompanion(sortOrder: Value(sortOrder)),
    const ['sortOrder'],
  );

  /// Assigns the list to a sharing group, or back to local-only (null) —
  /// ADR 0004/TASKS 8.3. **Re-stamps every synced field of the list and
  /// of all its todos** with one fresh HLC: rows *entering* a scope must
  /// carry stamps newer than any vector marker a group mailbox has
  /// already published, or the group's members would never receive the
  /// pre-move history (scoped `changesFor` soundness). The re-stamp is
  /// CRDT-safe — fresh stamps with this device's nodeId win LWW
  /// deterministically, which is exactly "the move happened last".
  Future<void> setGroup(String id, String? groupId) async {
    final hlc = _hlc.send();
    await _db.transaction(() async {
      final updated =
          await (_db.todoLists.update()..where((l) => l.id.equals(id))).write(
            TodoListsCompanion(groupId: Value(groupId)),
          );
      if (updated == 0) throw StateError('No list with id $id');
      await stampFields(
        db: _db,
        entity: 'todo_lists',
        rowId: id,
        fields: syncColumns['todo_lists']!.keys,
        hlc: hlc,
      );
      final todos =
          await (_db.todos.select()..where((t) => t.listId.equals(id))).get();
      for (final todo in todos) {
        await stampFields(
          db: _db,
          entity: 'todos',
          rowId: todo.id,
          fields: syncColumns['todos']!.keys,
          hlc: hlc,
        );
      }
    });
  }

  /// Tombstone. Todos keep their listId; views resolve a deleted list as
  /// "no list" rather than cascading.
  Future<void> archive(String id) => _write(
    id,
    const TodoListsCompanion(deleted: Value(true)),
    const ['deleted'],
  );

  Future<TodoList?> getById(String id) =>
      (_db.todoLists.select()..where((l) => l.id.equals(id))).getSingleOrNull();

  Stream<List<TodoList>> watchAll() =>
      (_db.todoLists.select()
            ..where((l) => l.deleted.equals(false))
            ..orderBy([(l) => OrderingTerm(expression: l.sortOrder)]))
          .watch();

  Future<void> _write(
    String id,
    TodoListsCompanion companion,
    List<String> changedFields,
  ) async {
    final hlc = _hlc.send();
    await _db.transaction(() async {
      final updated =
          await (_db.todoLists.update()..where((l) => l.id.equals(id))).write(
            companion,
          );
      if (updated == 0) {
        throw StateError('No list with id $id');
      }
      await stampFields(
        db: _db,
        entity: 'todo_lists',
        rowId: id,
        fields: changedFields,
        hlc: hlc,
      );
    });
  }
}
