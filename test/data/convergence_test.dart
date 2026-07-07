import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/sync/changeset.dart';

import '../support/simulated_device.dart';

/// TASKS.md 3.3 — the sync release gate. Random ops on N devices with
/// random pairwise syncs must always converge to identical state. Seeds are
/// fixed so failures are reproducible; if a seed ever fails, keep it as a
/// dedicated regression case.
void main() {
  final start = DateTime.utc(2026, 7, 5, 12);

  Future<void> randomOp(Random rng, Device d, List<String> todoIds) async {
    switch (rng.nextInt(6)) {
      case 0:
        final t = await d.todos.create(
          title: 'todo-${d.id}-${todoIds.length}',
          dueAtMs: rng.nextBool() ? null : rng.nextInt(1 << 30),
          priority: rng.nextInt(4),
        );
        todoIds.add(t.id);
      case 1 when todoIds.isNotEmpty:
        await _tryEdit(
          d,
          todoIds[rng.nextInt(todoIds.length)],
          title: Value('edited-by-${d.id}-${rng.nextInt(1000)}'),
        );
      case 2 when todoIds.isNotEmpty:
        await _tryEdit(
          d,
          todoIds[rng.nextInt(todoIds.length)],
          priority: Value(rng.nextInt(4)),
        );
      case 3 when todoIds.isNotEmpty:
        await _tryComplete(d, todoIds[rng.nextInt(todoIds.length)]);
      case 4 when todoIds.isNotEmpty:
        await _trySoftDelete(d, todoIds[rng.nextInt(todoIds.length)]);
      default:
        // Advance this device's clock (simulates time skew drift).
        d.clock.advance(Duration(milliseconds: rng.nextInt(5000)));
    }
  }

  for (final seed in [7, 42, 1337]) {
    test(
      '3 devices converge under random ops and partial syncs (seed $seed)',
      () async {
        final rng = Random(seed);
        final devices = [
          Device('aa', start),
          Device('bb', start.add(const Duration(seconds: 17))),
          Device('cc', start.subtract(const Duration(seconds: 31))),
        ];
        for (final d in devices) {
          addTearDown(d.close);
        }
        // Ids each device knows about (grows as they sync + create).
        final known = {for (final d in devices) d.id: <String>[]};

        for (var round = 0; round < 30; round++) {
          // Each device does a few local ops.
          for (final d in devices) {
            for (var i = 0; i < 1 + rng.nextInt(3); i++) {
              await randomOp(rng, d, known[d.id]!);
            }
          }
          // One random directed sync per round (partial connectivity).
          final from = devices[rng.nextInt(devices.length)];
          final to = devices[rng.nextInt(devices.length)];
          if (from.id != to.id) {
            await to.engine.pullFrom(from.engine);
            // Receiving device now knows the sender's todos.
            final ids = (await to.db.todos.all().get()).map((t) => t.id);
            known[to.id]!
              ..clear()
              ..addAll(ids);
          }
        }

        // Final full anti-entropy: everyone pulls from everyone, twice.
        for (var i = 0; i < 2; i++) {
          for (final a in devices) {
            for (final b in devices) {
              if (a.id != b.id) await a.engine.pullFrom(b.engine);
            }
          }
        }

        final dumps = [for (final d in devices) await d.dump()];
        expect(dumps[1], dumps[0], reason: 'seed $seed: b != a');
        expect(dumps[2], dumps[0], reason: 'seed $seed: c != a');
      },
    );
  }

  test('reapplying any published prefix is idempotent', () async {
    final rng = Random(20260706);
    final a = Device('aa', start);
    final b = Device('bb', start.add(const Duration(seconds: 9)));
    for (final d in [a, b]) {
      addTearDown(d.close);
    }

    var publishedVector = const <String, String>{};
    final published = <Changeset>[];
    final knownIds = <String>[];

    for (var i = 0; i < 12; i++) {
      await randomOp(rng, a, knownIds);
      final delta = await a.engine.changesFor(publishedVector);
      if (delta.writes.isEmpty) continue;
      published.add(delta);
      publishedVector = await a.engine.versionVector();
    }

    for (final delta in published) {
      await b.engine.apply(delta);
    }
    final converged = await b.dump();

    for (var i = 1; i <= published.length; i++) {
      for (final delta in published.take(i)) {
        await b.engine.apply(delta);
      }
      expect(
        await b.dump(),
        converged,
        reason: 'prefix length $i changed state',
      );
    }
  });

  test(
    'applying a changeset in shuffled order converges identically',
    () async {
      final rng = Random(99);
      final a = Device('aa', start);
      final b = Device('bb', start);
      final c = Device('cc', start);
      for (final d in [a, b, c]) {
        addTearDown(d.close);
      }

      final list = await a.lists.create(name: 'L');
      for (var i = 0; i < 10; i++) {
        final t = await a.todos.create(title: 'todo $i', listId: list.id);
        if (i.isEven) await a.todos.complete(t.id);
      }

      final delta = await a.engine.changesFor(const {});
      // B gets writes in causal order; C gets them shuffled one by one.
      await b.engine.apply(delta);
      final shuffled = [...delta.writes]..shuffle(rng);
      for (final write in shuffled) {
        await c.engine.apply(Changeset(deviceId: 'aa', writes: [write]));
      }

      expect(await c.dump(), await b.dump());
    },
  );
}

Future<void> _tryEdit(
  Device d,
  String id, {
  Value<String> title = const Value.absent(),
  Value<int> priority = const Value.absent(),
}) async {
  try {
    await d.todos.edit(id, title: title, priority: priority);
  } on StateError {
    // Row not present on this device yet — fine in a partial-sync world.
  }
}

Future<void> _tryComplete(Device d, String id) async {
  try {
    await d.todos.complete(id);
  } on StateError {
    // Row not synced here yet.
  }
}

Future<void> _trySoftDelete(Device d, String id) async {
  try {
    await d.todos.softDelete(id);
  } on StateError {
    // Row not synced here yet.
  }
}
