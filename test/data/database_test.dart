import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('todo insert/query roundtrip with list reference', () async {
    await db.todoLists.insertOne(
      TodoListsCompanion.insert(id: 'list-1', name: 'Groceries'),
    );
    await db.todos.insertOne(
      TodosCompanion.insert(
        id: 'todo-1',
        title: 'Buy milk',
        listId: const Value('list-1'),
        dueAtMs: const Value(1000),
      ),
    );

    final row = await db.todos.all().getSingle();
    expect(row.title, 'Buy milk');
    expect(row.listId, 'list-1');
    expect(row.deleted, isFalse);
    expect(row.tagsJson, '[]');
  });

  test('foreign keys are enforced', () async {
    expect(
      () => db.todoAlarms.insertOne(
        TodoAlarmsCompanion.insert(
          id: 'alarm-1',
          todoId: 'missing-todo',
          atLocal: '2026-07-05T09:00',
          tz: 'Asia/Kolkata',
        ),
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('tombstone update keeps the row', () async {
    await db.todoLists.insertOne(
      TodoListsCompanion.insert(id: 'list-1', name: 'Old'),
    );
    await (db.todoLists.update()..where((t) => t.id.equals('list-1'))).write(
      const TodoListsCompanion(deleted: Value(true)),
    );

    final row = await db.todoLists.all().getSingle();
    expect(row.deleted, isTrue);
  });

  test('field clock upsert takes the newer stamp', () async {
    Future<void> stamp(String hlc) => db.fieldClocks.insertOne(
      FieldClocksCompanion.insert(
        entity: 'todos',
        rowId: 'todo-1',
        fieldName: 'title',
        hlc: hlc,
      ),
      mode: InsertMode.insertOrReplace,
    );

    await stamp('000000000001000:0000:a');
    await stamp('000000000002000:0000:b');

    final row = await db.fieldClocks.all().getSingle();
    expect(row.hlc, '000000000002000:0000:b');
  });

  test('alarm dismissal keyed per occurrence', () async {
    await db.todoLists.insertOne(TodoListsCompanion.insert(id: 'l', name: 'L'));
    await db.todos.insertOne(
      TodosCompanion.insert(id: 't', title: 'T', listId: const Value('l')),
    );
    await db.todoAlarms.insertOne(
      TodoAlarmsCompanion.insert(
        id: 'a',
        todoId: 't',
        atLocal: '2026-07-05T09:00',
        tz: 'Asia/Kolkata',
      ),
    );

    for (final occurrence in [1000, 2000]) {
      await db.alarmDismissals.insertOne(
        AlarmDismissalsCompanion.insert(
          alarmId: 'a',
          occurrenceMs: occurrence,
          dismissedBy: 'device-1',
          hlc: '000000000001000:0000:a',
          action: 'dismiss',
        ),
      );
    }

    expect(await db.alarmDismissals.all().get(), hasLength(2));
  });

  test('schema migration v4 to v5 adds task organization columns', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('ALTER TABLE todos DROP COLUMN parent_id');
    await db.customStatement('ALTER TABLE todos DROP COLUMN section');
    await db.customStatement('ALTER TABLE todos DROP COLUMN sort_key');
    await db.todos.insertOne(TodosCompanion.insert(id: 't1', title: 'Pre-v5'));

    await db.migration.onUpgrade(db.createMigrator(), 4, 5);

    final migrated = await db.todos.all().getSingle();
    expect(migrated.parentId, isNull);
    expect(migrated.section, isNull);
    expect(migrated.sortKey, '');
  });

  test('schema migration v7 to v8 adds the nag interval column', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      'ALTER TABLE todos DROP COLUMN nag_interval_minutes',
    );
    await db.todos.insertOne(TodosCompanion.insert(id: 't1', title: 'Pre-v8'));

    await db.migration.onUpgrade(db.createMigrator(), 7, 8);

    final migrated = await db.todos.all().getSingle();
    expect(migrated.nagIntervalMinutes, isNull);
  });

  test('schema migration v8 to v9 adds assignee and streak columns', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      'ALTER TABLE todos DROP COLUMN assignee_device_id',
    );
    await db.customStatement('ALTER TABLE todos DROP COLUMN current_streak');
    await db.todos.insertOne(TodosCompanion.insert(id: 't1', title: 'Pre-v9'));

    await db.migration.onUpgrade(db.createMigrator(), 8, 9);

    final migrated = await db.todos.all().getSingle();
    expect(migrated.assigneeDeviceId, isNull);
    expect(migrated.currentStreak, 0);
  });
}
