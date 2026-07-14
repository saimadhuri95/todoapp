import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/sync/lww_applier.dart';

/// Spike for docs/decisions/0001-crdt-choice.md: two devices with
/// independent databases converge under per-field LWW, regardless of
/// apply order or duplication.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase dbA;
  late AppDatabase dbB;

  Future<void> seed(AppDatabase db) async {
    await db.todoLists.insertOne(
      TodoListsCompanion.insert(id: 'l1', name: 'Inbox'),
    );
    await db.todos.insertOne(
      TodosCompanion.insert(id: 't1', title: 'original'),
    );
  }

  setUp(() async {
    dbA = AppDatabase(NativeDatabase.memory());
    dbB = AppDatabase(NativeDatabase.memory());
    await seed(dbA);
    await seed(dbB);
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  FieldWrite write(String field, Object? value, int ms, String node) =>
      FieldWrite(
        entity: 'todos',
        rowId: 't1',
        field: field,
        value: value,
        hlc: Hlc(ms, 0, node),
      );

  Future<String> title(AppDatabase db) async =>
      (await db.todos.all().getSingle()).title;

  test(
    'concurrent edits converge to the same winner in either order',
    () async {
      final fromA = write('title', 'milk (A)', 1000, 'a');
      final fromB = write('title', 'milk (B)', 2000, 'b');

      final applierA = LwwApplier(dbA);
      final applierB = LwwApplier(dbB);

      // Device A: local write first, then receives B's.
      await applierA.apply(fromA);
      await applierA.apply(fromB);
      // Device B: opposite order.
      await applierB.apply(fromB);
      expect(await applierB.apply(fromA), isFalse);

      expect(await title(dbA), 'milk (B)');
      expect(await title(dbB), 'milk (B)');
    },
  );

  test('duplicate application is a no-op', () async {
    final applier = LwwApplier(dbA);
    final w = write('title', 'once', 1000, 'a');

    expect(await applier.apply(w), isTrue);
    expect(await applier.apply(w), isFalse);
    expect(await title(dbA), 'once');
  });

  test('stale write after newer one is rejected', () async {
    final applier = LwwApplier(dbA);
    await applier.apply(write('title', 'newer', 2000, 'b'));

    expect(await applier.apply(write('title', 'older', 1000, 'a')), isFalse);
    expect(await title(dbA), 'newer');
  });

  test('same millis: nodeId breaks the tie identically everywhere', () async {
    final fromA = write('title', 'from a', 1000, 'a');
    final fromB = write('title', 'from b', 1000, 'b');

    await LwwApplier(dbA).apply(fromA);
    await LwwApplier(dbA).apply(fromB);
    await LwwApplier(dbB).apply(fromB);
    await LwwApplier(dbB).apply(fromA);

    expect(await title(dbA), 'from b');
    expect(await title(dbB), 'from b');
  });

  test('different fields merge independently', () async {
    final applier = LwwApplier(dbA);
    await applier.apply(write('title', 'walk dog', 2000, 'a'));
    await applier.apply(write('priority', 3, 1000, 'b'));

    final row = await dbA.todos.all().getSingle();
    expect(row.title, 'walk dog');
    expect(row.priority, 3);
  });

  test('tombstone via deleted field participates in LWW', () async {
    final applier = LwwApplier(dbA);
    await applier.apply(write('deleted', 1, 2000, 'b'));
    // Older edit does not resurrect the deleted row's field clock.
    expect(await applier.apply(write('deleted', 0, 1000, 'a')), isFalse);

    expect((await dbA.todos.all().getSingle()).deleted, isTrue);
  });

  test(
    'unknown field is skipped, not applied (forward compat, #141)',
    () async {
      final applier = LwwApplier(dbA);
      // A field an older build doesn't know (a newer peer's column, or an
      // injection attempt) must be a no-op returning false — never a throw
      // that would abort the whole changeset. SQL-name allowlisting is still
      // enforced: only syncColumns entries reach the UPDATE.
      expect(
        await applier.apply(write('nope; DROP TABLE todos', 'x', 1, 'a')),
        isFalse,
      );
      // The table is intact and the known row is untouched.
      expect(await title(dbA), 'original');

      // A known field in the *same* changeset still applies — the unknown one
      // doesn't poison its neighbours.
      expect(
        await applier.apply(write('title', 'from newer peer', 2, 'b')),
        true,
      );
      expect(await title(dbA), 'from newer peer');
    },
  );
}
