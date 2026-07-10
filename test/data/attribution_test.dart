import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/repositories/todo_repository.dart';

void main() {
  late AppDatabase db;
  late TodoRepository todos;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    todos = TodoRepository(
      db,
      HlcClock(nodeId: 'aa', clock: FixedClock(DateTime.utc(2026, 7, 6, 12))),
    );
  });

  tearDown(() => db.close());

  test('returns null for a todo with no field clocks', () async {
    expect(await todos.lastChangedBy('missing'), isNull);
  });

  test('attributes the local writer by node id with no device row', () async {
    final todo = await todos.create(title: 'x');
    expect(await todos.lastChangedBy(todo.id), 'aa');
  });

  test('resolves the writer node id to a device display name', () async {
    final todo = await todos.create(title: 'x');
    await db
        .into(db.devices)
        .insert(
          DevicesCompanion.insert(
            id: 'aa',
            name: 'My Phone',
            platform: 'ios',
            publicKey: 'k',
          ),
        );
    expect(await todos.lastChangedBy(todo.id), 'My Phone');
  });

  test('the newest field write across devices wins', () async {
    final todo = await todos.create(title: 'x');
    // A later remote edit of one field by device bb wins the attribution.
    await db
        .into(db.fieldClocks)
        .insertOnConflictUpdate(
          FieldClocksCompanion.insert(
            entity: 'todos',
            rowId: todo.id,
            fieldName: 'title',
            hlc: Hlc(
              DateTime.utc(2026, 7, 7, 12).millisecondsSinceEpoch,
              0,
              'bb',
            ).encode(),
          ),
        );
    expect(await todos.lastChangedBy(todo.id), 'bb');
  });
}
