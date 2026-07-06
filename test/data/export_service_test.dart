import 'package:drift/drift.dart' show TableOrViewStatements, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/export_service.dart';

import 'sync_engine_test.dart' show Device;

void main() {
  final start = DateTime.utc(2026, 7, 6, 12);
  late Device a;
  late Device b;
  late ExportService exportA;
  late ExportService importB;

  setUp(() {
    a = Device('aa', start);
    b = Device('bb', start.add(const Duration(seconds: 3)));
    exportA = ExportService(db: a.db, hlc: a.hlc);
    importB = ExportService(db: b.db, hlc: b.hlc);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('export/import roundtrips todos, lists, and tombstones', () async {
    final list = await a.lists.create(name: 'Groceries', color: 7);
    final keep = await a.todos.create(
      title: 'Buy milk',
      listId: list.id,
      dueAtMs: 12345,
      tags: ['errand'],
      priority: 2,
    );
    await a.todos.edit(keep.id, alarmOffsetsMinutes: const Value([0, 30]));
    final gone = await a.todos.create(title: 'deleted one');
    await a.todos.softDelete(gone.id);

    final (listCount, todoCount) = await importB.importJson(
      await exportA.exportJson(),
    );
    expect(listCount, 1);
    expect(todoCount, 2);

    final restored =
        await (b.db.todos.select()..where((t) => t.id.equals(keep.id)))
            .getSingle();
    expect(restored.title, 'Buy milk');
    expect(restored.listId, list.id);
    expect(restored.dueAtMs, 12345);
    expect(restored.tagsJson, '["errand"]');
    expect(restored.alarmOffsetsJson, '[0,30]');
    final tombstone =
        await (b.db.todos.select()..where((t) => t.id.equals(gone.id)))
            .getSingle();
    expect(tombstone.deleted, isTrue);
  });

  test('imported data syncs onward (stamps written)', () async {
    await a.todos.create(title: 'travels far');
    await importB.importJson(await exportA.exportJson());

    // A third device pulls from B and sees the imported todo.
    final c = Device('cc', start.add(const Duration(seconds: 9)));
    addTearDown(c.close);
    await c.engine.pullFrom(b.engine);
    expect((await c.db.todos.all().getSingle()).title, 'travels far');
  });

  test('import into a populated db upserts without duplicating', () async {
    final todo = await a.todos.create(title: 'original');
    final snapshot = await exportA.exportJson();
    await a.todos.edit(todo.id, title: const Value('edited later'));

    // Restore the older snapshot into the same db.
    final restore = ExportService(db: a.db, hlc: a.hlc);
    await restore.importJson(snapshot);

    final rows = await a.db.todos.all().get();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'original'); // snapshot restored
  });

  test('malformed and foreign files are rejected without writes', () async {
    for (final bad in ['nope', '{}', '{"v":1,"app":"other"}']) {
      expect(() => importB.importJson(bad), throwsFormatException, reason: bad);
    }
    expect(await b.db.todos.all().get(), isEmpty);
  });
}
