import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/repositories/todo_repository.dart';
import 'package:todoapp/data/sync/changeset.dart';
import 'package:todoapp/data/sync/lww_applier.dart';

import '../support/simulated_device.dart';

void main() {
  final start = DateTime.utc(2026, 7, 5, 12);

  group('SyncEngine', () {
    late Device a;
    late Device b;

    setUp(() {
      a = Device('aaa', start);
      b = Device('bbb', start.add(const Duration(seconds: 3)));
    });

    tearDown(() async {
      await a.close();
      await b.close();
    });

    test('full pull replicates rows created remotely', () async {
      final groceries = await a.lists.create(name: 'Groceries');
      await a.todos.create(
        title: 'Buy milk',
        listId: groceries.id,
        priority: 2,
        tags: ['errand'],
      );

      final applied = await b.engine.pullFrom(a.engine);
      expect(applied, greaterThan(0));

      final todo = await b.db.todos.all().getSingle();
      expect(todo.title, 'Buy milk');
      expect(todo.listId, groceries.id);
      expect(todo.priority, 2);
      expect(todo.tags, ['errand']);
      expect((await b.db.todoLists.all().getSingle()).name, 'Groceries');
      expect(await a.dump(), await b.dump());
      expect(b.engine.visibleTodoChanges, 1);
    });

    test('second pull is empty (version vector covers first)', () async {
      await a.todos.create(title: 't');
      await b.engine.pullFrom(a.engine);

      final delta = await a.engine.changesFor(await b.engine.versionVector());
      expect(delta.writes, isEmpty);
    });

    test('changeset JSON roundtrips', () async {
      await a.todos.create(title: 'encode me', tags: ['x']);
      final original = await a.engine.changesFor(const {});
      final decoded = Changeset.decode(original.encode());

      expect(decoded.deviceId, original.deviceId);
      expect(decoded.writes.length, original.writes.length);
      for (var i = 0; i < original.writes.length; i++) {
        expect(decoded.writes[i].entity, original.writes[i].entity);
        expect(decoded.writes[i].value, original.writes[i].value);
        expect(decoded.writes[i].hlc, original.writes[i].hlc);
      }
    });

    test('decode rejects unknown version', () {
      expect(
        () => Changeset.decode('{"v":99,"device":"x","writes":[]}'),
        throwsFormatException,
      );
    });

    test('re-applying the same changeset is a no-op', () async {
      await a.todos.create(title: 'once');
      final delta = await a.engine.changesFor(const {});

      expect(await b.engine.apply(delta), greaterThan(0));
      final before = await b.dump();
      expect(await b.engine.apply(delta), 0);
      expect(await b.dump(), before);
    });

    test('bidirectional sync merges concurrent edits per-field', () async {
      await a.todos.create(title: 'shared');
      await b.engine.pullFrom(a.engine);
      final id = (await a.db.todos.all().getSingle()).id;

      // Concurrent: A edits title (earlier clock), B edits priority (later).
      await a.todos.edit(id, title: const Value('A title'));
      await b.todos.edit(id, priority: const Value(3));

      await b.engine.pullFrom(a.engine);
      await a.engine.pullFrom(b.engine);

      expect(await a.dump(), await b.dump());
      final merged = await a.db.todos.all().getSingle();
      expect(merged.title, 'A title');
      expect(merged.priority, 3);
    });

    test('third-party writes relay through an intermediary', () async {
      final c = Device('ccc', start.add(const Duration(seconds: 9)));
      addTearDown(c.close);

      await a.todos.create(title: 'from a');
      // B learns from A; C only ever talks to B.
      await b.engine.pullFrom(a.engine);
      await c.engine.pullFrom(b.engine);

      expect((await c.db.todos.all().getSingle()).title, 'from a');
      expect(await c.dump(), await a.dump());
    });

    test('alarm dismissal syncs as a field write (3.15)', () async {
      final due = start.add(const Duration(hours: 1)).millisecondsSinceEpoch;
      final todo = await a.todos.create(title: 'ring', dueAtMs: due);
      await a.todos.edit(todo.id, alarmOffsetsMinutes: const Value([0]));
      await b.engine.pullFrom(a.engine);

      // B dismisses; A learns of it and would cancel its notification.
      await b.todos.dismissAlarm(todo.id, due);
      await a.engine.pullFrom(b.engine);

      final onA = await a.db.todos.all().getSingle();
      expect(onA.lastDismissedMs, due);
      expect(await a.dump(), await b.dump());
      expect(a.engine.visibleTodoChanges, 0);
    });

    test('non-todo writes do not mark visible todos changed', () async {
      final applied = await b.engine.apply(
        Changeset(
          deviceId: 'ccc',
          writes: [
            FieldWrite(
              entity: 'devices',
              rowId: 'ccc',
              field: 'name',
              value: 'Cab phone',
              hlc: Hlc(start.millisecondsSinceEpoch, 0, 'ccc'),
            ),
          ],
        ),
      );

      expect(applied, 1);
      expect(b.engine.visibleTodoChanges, 0);
    });

    test('todo created and tombstoned in one changeset is not a visible '
        'change', () async {
      FieldWrite ghostWrite(String field, Object? value, int counter) =>
          FieldWrite(
            entity: 'todos',
            rowId: 'ghost',
            field: field,
            value: value,
            hlc: Hlc(start.millisecondsSinceEpoch, counter, 'ccc'),
          );

      final applied = await b.engine.apply(
        Changeset(
          deviceId: 'ccc',
          writes: [
            ghostWrite('title', 'never shown here', 0),
            ghostWrite('deleted', 1, 1),
          ],
        ),
      );

      expect(applied, 2);
      expect(b.engine.visibleTodoChanges, 0);

      // A later edit to the tombstoned row stays invisible too.
      await b.engine.apply(
        Changeset(
          deviceId: 'ccc',
          writes: [ghostWrite('title', 'still not shown', 2)],
        ),
      );
      expect(b.engine.visibleTodoChanges, 0);
    });

    test('tombstone propagates and wins over older concurrent edit', () async {
      await a.todos.create(title: 'doomed');
      await b.engine.pullFrom(a.engine);
      final id = (await a.db.todos.all().getSingle()).id;

      // B edits first (older stamp), then A deletes (newer stamp).
      await b.todos.edit(id, title: const Value('B was here'));
      a.clock.advance(const Duration(minutes: 1));
      await a.todos.softDelete(id);

      await b.engine.pullFrom(a.engine);
      await a.engine.pullFrom(b.engine);

      expect(await a.dump(), await b.dump());
      final row = await a.db.todos.all().getSingle();
      expect(row.deleted, isTrue);
      expect(row.title, 'B was here'); // title field merged independently
    });
  });
}
