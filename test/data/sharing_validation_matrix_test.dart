import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/sync/mailbox_transport.dart';

import '../support/simulated_device.dart';

void main() {
  final start = DateTime.utc(2026, 7, 8, 12);

  late Device appleA;
  late Device appleB;
  late Device androidC;
  late Directory familyRoot;
  late Directory friendsRoot;
  late SecretKey familyKey;
  late SecretKey friendsKey;

  setUp(() async {
    appleA = Device('iphone-a', start);
    appleB = Device('iphone-b', start.add(const Duration(seconds: 1)));
    androidC = Device('android-c', start.add(const Duration(seconds: 2)));
    familyRoot = await Directory.systemTemp.createTemp('family_icloud');
    friendsRoot = await Directory.systemTemp.createTemp('friends_dropbox');
    familyKey = SecretKey(List<int>.generate(32, (i) => i));
    friendsKey = SecretKey(List<int>.generate(32, (i) => 255 - i));
  });

  tearDown(() async {
    await appleA.close();
    await appleB.close();
    await androidC.close();
    if (familyRoot.existsSync()) await familyRoot.delete(recursive: true);
    if (friendsRoot.existsSync()) await friendsRoot.delete(recursive: true);
  });

  MailboxTransport box(
    Device device, {
    required Directory root,
    required SecretKey key,
    required String groupId,
  }) => MailboxTransport(
    root: root,
    engine: device.engine,
    db: device.db,
    deviceId: device.id,
    groupKey: key,
    groupId: groupId,
  );

  Future<void> exchange(
    Device publisher,
    Device consumer, {
    required Directory root,
    required SecretKey key,
    required String groupId,
    int passes = 2,
  }) async {
    for (var i = 0; i < passes; i++) {
      await box(publisher, root: root, key: key, groupId: groupId).publish();
      await box(consumer, root: root, key: key, groupId: groupId).consume();
    }
  }

  Future<Set<String>> titles(Device device) async =>
      (await device.db.todos.select().get()).map((todo) => todo.title).toSet();

  test(
    'cross-ecosystem matrix keeps Apple, Dropbox, and solo scopes apart',
    () async {
      final family = await appleA.groups.create(
        name: 'Family',
        backendKind: 'icloud',
        localAccountRef: familyRoot.path,
      );
      final groceries = await appleA.lists.create(name: 'Groceries');
      await appleA.lists.setGroup(groceries.id, family.id);
      await appleA.todos.create(title: 'milk', listId: groceries.id);

      final friends = await appleA.groups.create(
        name: 'Friends',
        backendKind: 'dropbox',
        localAccountRef: 'dropbox-shared-ref',
      );
      final trip = await appleA.lists.create(name: 'Trip');
      await appleA.lists.setGroup(trip.id, friends.id);
      await appleA.todos.create(title: 'book train', listId: trip.id);

      final solo = await appleA.lists.create(name: 'Solo');
      await appleA.todos.create(title: 'private journal', listId: solo.id);

      await exchange(
        appleA,
        appleB,
        root: familyRoot,
        key: familyKey,
        groupId: family.id,
      );
      await exchange(
        appleA,
        androidC,
        root: friendsRoot,
        key: friendsKey,
        groupId: friends.id,
      );

      expect(await titles(appleB), contains('milk'));
      expect(await titles(appleB), isNot(contains('book train')));
      expect(await titles(appleB), isNot(contains('private journal')));
      expect(await titles(androidC), contains('book train'));
      expect(await titles(androidC), isNot(contains('milk')));
      expect(await titles(androidC), isNot(contains('private journal')));

      // A list created before the group move republishes its full history.
      final packing = await appleA.lists.create(name: 'Packing');
      await appleA.todos.create(title: 'pack charger', listId: packing.id);
      await box(
        appleA,
        root: friendsRoot,
        key: friendsKey,
        groupId: friends.id,
      ).publish();
      appleA.clock.advance(const Duration(minutes: 1));
      await appleA.lists.setGroup(packing.id, friends.id);
      await exchange(
        appleA,
        androidC,
        root: friendsRoot,
        key: friendsKey,
        groupId: friends.id,
      );

      expect(await titles(androidC), contains('pack charger'));
    },
  );

  test(
    'member removal with key rotation stops future shared-folder reads',
    () async {
      var root = friendsRoot;
      final friends = await appleA.groups.create(
        name: 'Friends',
        backendKind: 'dropbox',
        localAccountRef: 'dropbox-shared-ref',
      );
      final trip = await appleA.lists.create(name: 'Trip');
      await appleA.lists.setGroup(trip.id, friends.id);
      await appleA.todos.create(title: 'old plan', listId: trip.id);
      await exchange(
        appleA,
        androidC,
        root: root,
        key: friendsKey,
        groupId: friends.id,
      );
      expect(await titles(androidC), contains('old plan'));

      // Rotation burns the old mailbox: remaining members republish with the
      // new key, removed members can keep old history but cannot read new files.
      await root.delete(recursive: true);
      root = friendsRoot = await Directory.systemTemp.createTemp(
        'friends_dropbox_rotated',
      );
      final rotatedKey = SecretKey(
        List<int>.generate(32, (i) => (i * 7) % 256),
      );
      appleA.clock.advance(const Duration(minutes: 1));
      await appleA.todos.create(title: 'after rotation', listId: trip.id);
      await box(
        appleA,
        root: root,
        key: rotatedKey,
        groupId: friends.id,
      ).publish();

      expect(
        await box(
          androidC,
          root: root,
          key: friendsKey,
          groupId: friends.id,
        ).consume(),
        0,
      );
      await box(
        appleB,
        root: root,
        key: rotatedKey,
        groupId: friends.id,
      ).consume();

      expect(await titles(androidC), isNot(contains('after rotation')));
      expect(await titles(appleB), contains('after rotation'));
    },
  );

  test('three group sync is within a loose 2x perf sanity envelope', () async {
    final oneRoot = await Directory.systemTemp.createTemp('one_group_perf');
    final roots = <Directory>[];
    addTearDown(() async {
      if (oneRoot.existsSync()) await oneRoot.delete(recursive: true);
      for (final root in roots) {
        if (root.existsSync()) await root.delete(recursive: true);
      }
    });

    final oneGroup = await appleA.groups.create(
      name: 'One',
      backendKind: 'folder',
    );
    final oneList = await appleA.lists.create(name: 'One list');
    await appleA.lists.setGroup(oneList.id, oneGroup.id);
    for (var i = 0; i < 60; i++) {
      await appleA.todos.create(title: 'one-$i', listId: oneList.id);
    }
    final one = await _elapsed(
      () => exchange(
        appleA,
        appleB,
        root: oneRoot,
        key: familyKey,
        groupId: oneGroup.id,
      ),
    );

    final threeGroups = <String>[];
    for (var g = 0; g < 3; g++) {
      final root = await Directory.systemTemp.createTemp('three_group_$g');
      roots.add(root);
      final group = await appleA.groups.create(
        name: 'Group $g',
        backendKind: 'folder',
      );
      threeGroups.add(group.id);
      final list = await appleA.lists.create(name: 'List $g');
      await appleA.lists.setGroup(list.id, group.id);
      for (var i = 0; i < 20; i++) {
        await appleA.todos.create(title: 'g$g-$i', listId: list.id);
      }
    }
    final three = await _elapsed(() async {
      for (var i = 0; i < threeGroups.length; i++) {
        await exchange(
          appleA,
          androidC,
          root: roots[i],
          key: friendsKey,
          groupId: threeGroups[i],
        );
      }
    });

    expect(
      three.inMilliseconds,
      lessThanOrEqualTo(one.inMilliseconds * 2 + 500),
    );
  });
}

Future<Duration> _elapsed(Future<void> Function() body) async {
  final watch = Stopwatch()..start();
  await body();
  watch.stop();
  return watch.elapsed;
}
