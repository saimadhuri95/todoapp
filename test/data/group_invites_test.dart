import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/repositories/group_repository.dart';
import 'package:todoapp/data/sync/device_identity.dart';
import 'package:todoapp/data/sync/pairing_service.dart';

/// Per-group keys + QR invitations (TASKS 8.5, ADR 0004): joining a group
/// hands over exactly that group's key — nothing else.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase dbA, dbB;
  late PairingService a, b;
  late DeviceIdentity idA, idB;
  late GroupRepository groupsA, groupsB;

  setUp(() async {
    dbA = AppDatabase(NativeDatabase.memory());
    dbB = AppDatabase(NativeDatabase.memory());
    final clockA = HlcClock(
      nodeId: 'dev-a',
      clock: FixedClock(DateTime.utc(2026, 7, 8, 12)),
    );
    final clockB = HlcClock(
      nodeId: 'dev-b',
      clock: FixedClock(DateTime.utc(2026, 7, 8, 12, 1)),
    );
    final storeA = InMemoryKeyStore();
    final storeB = InMemoryKeyStore();
    a = PairingService(db: dbA, hlc: clockA, keyStore: storeA);
    b = PairingService(db: dbB, hlc: clockB, keyStore: storeB);
    idA = await DeviceIdentity.loadOrCreate(storeA, 'dev-a');
    idB = await DeviceIdentity.loadOrCreate(storeB, 'dev-b');
    groupsA = GroupRepository(dbA, clockA);
    groupsB = GroupRepository(dbB, clockB);
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  test('group invitation hands over the group key and memberships', () async {
    final family = await groupsA.create(name: 'Family', backendKind: 'webdav');

    final invitation = await a.createGroupInvitation(
      identity: idA,
      name: 'A iPhone',
      platform: 'ios',
      group: family,
    );
    final result = await b.acceptGroupInvitation(
      invitation,
      identity: idB,
      name: 'B iPhone',
      platform: 'ios',
    );

    // Same group key on both sides.
    final keyA = await a.groupKeyFor(family.id);
    final keyB = await b.groupKeyFor(family.id);
    expect(await keyA!.extractBytes(), await keyB!.extractBytes());

    // B materialized the group row (unstamped) and can render it.
    final groupOnB = await groupsB.getById(family.id);
    expect(groupOnB!.name, 'Family');
    expect(groupOnB.backendKind, 'webdav');

    // Memberships: inviter recorded on A, joiner recorded on B (each
    // replicates to the other with the first sync).
    expect(await groupsA.watchMemberIds(family.id).first, ['dev-a']);
    expect(await groupsB.watchMemberIds(family.id).first, ['dev-b']);

    // The joiner learned the inviter's device row + fingerprint.
    expect(result.peer.deviceId, 'dev-a');
    expect(result.fingerprint, isNotEmpty);
  });

  test('the personal key never travels in a group invitation', () async {
    await a.loadOrCreateGroupKey(); // Personal key exists on A.
    final family = await groupsA.create(name: 'Family', backendKind: 'webdav');
    final invitation = await a.createGroupInvitation(
      identity: idA,
      name: 'A',
      platform: 'ios',
      group: family,
    );

    final personal = base64Encode(
      await (await a.loadOrCreateGroupKey()).extractBytes(),
    );
    expect(invitation.contains(personal), isFalse);

    await b.acceptGroupInvitation(
      invitation,
      identity: idB,
      name: 'B',
      platform: 'ios',
    );
    // Joining a group does not make B "paired" in the personal sense.
    expect(await b.hasGroupKey(), isFalse);
  });

  test('keys are independent per group and rotation burns only one', () async {
    final family = await groupsA.create(name: 'Family', backendKind: 'icloud');
    final friends = await groupsA.create(
      name: 'Friends',
      backendKind: 'webdav',
    );

    final famKey = await a.loadOrCreateGroupKeyFor(family.id);
    final friKey = await a.loadOrCreateGroupKeyFor(friends.id);
    expect(await famKey.extractBytes(), isNot(await friKey.extractBytes()));

    await a.rotateGroupKey(family.id);

    final famAfter = await a.groupKeyFor(family.id);
    final friAfter = await a.groupKeyFor(friends.id);
    expect(await famAfter!.extractBytes(), isNot(await famKey.extractBytes()));
    expect(await friAfter!.extractBytes(), await friKey.extractBytes());
  });

  test(
    'malformed and personal invitations are rejected as group joins',
    () async {
      expect(
        () => b.acceptGroupInvitation(
          'not json',
          identity: idB,
          name: 'B',
          platform: 'ios',
        ),
        throwsFormatException,
      );
      // A v1 personal invitation is not a group invitation.
      final personal = await a.createInvitation(
        identity: idA,
        name: 'A',
        platform: 'ios',
      );
      expect(
        () => b.acceptGroupInvitation(
          personal,
          identity: idB,
          name: 'B',
          platform: 'ios',
        ),
        throwsFormatException,
      );
      // Nothing was adopted.
      expect(await b.groupKeyFor('any'), isNull);
    },
  );
}
