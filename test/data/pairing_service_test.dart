import 'package:drift/drift.dart' show TableOrViewStatements;
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/sync/device_identity.dart';
import 'package:todoapp/data/sync/pairing_service.dart';

import 'sync_engine_test.dart' show Device;

void main() {
  final start = DateTime.utc(2026, 7, 5, 12);
  late Device a;
  late Device b;
  late InMemoryKeyStore storeA;
  late InMemoryKeyStore storeB;
  late PairingService serviceA;
  late PairingService serviceB;

  setUp(() {
    a = Device('aa', start);
    b = Device('bb', start.add(const Duration(seconds: 5)));
    storeA = InMemoryKeyStore();
    storeB = InMemoryKeyStore();
    serviceA = PairingService(db: a.db, hlc: a.hlc, keyStore: storeA);
    serviceB = PairingService(db: b.db, hlc: b.hlc, keyStore: storeB);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  test(
    'invite/accept: same group key on both sides, fingerprint returned',
    () async {
      final identityA = await DeviceIdentity.loadOrCreate(storeA, a.id);
      final identityB = await DeviceIdentity.loadOrCreate(storeB, b.id);

      final invitation = await serviceA.createInvitation(
        identity: identityA,
        name: 'Laptop',
        platform: 'macos',
      );
      final result = await serviceB.accept(
        invitation,
        identity: identityB,
        name: 'Phone',
        platform: 'android',
      );

      expect(result.peer.deviceId, a.id);
      expect(result.fingerprint, matches(RegExp(r'^[0-9A-F-]{14}$')));

      final keyA = await serviceA.loadOrCreateGroupKey();
      final keyB = await serviceB.loadOrCreateGroupKey();
      expect(await keyA.extractBytes(), await keyB.extractBytes());
    },
  );

  test('device rows replicate through sync after pairing', () async {
    final identityA = await DeviceIdentity.loadOrCreate(storeA, a.id);
    final identityB = await DeviceIdentity.loadOrCreate(storeB, b.id);

    final invitation = await serviceA.createInvitation(
      identity: identityA,
      name: 'Laptop',
      platform: 'macos',
    );
    await serviceB.accept(
      invitation,
      identity: identityB,
      name: 'Phone',
      platform: 'android',
    );

    // B knows both devices already; A learns B's row via a normal sync.
    expect(await b.db.devices.all().get(), hasLength(2));
    await a.engine.pullFrom(b.engine);

    final devicesOnA = await a.db.devices.all().get();
    expect(devicesOnA, hasLength(2));
    final phone = devicesOnA.firstWhere((d) => d.id == b.id);
    expect(phone.name, 'Phone');
    expect(phone.platform, 'android');
    expect(phone.publicKey, isNotEmpty);
  });

  test('garbage and versioned-wrong invitations are rejected', () async {
    final identityB = await DeviceIdentity.loadOrCreate(storeB, b.id);

    for (final bad in [
      'not json',
      '{"v":2,"payload":"x","gk":"y"}',
      '{"v":1}',
    ]) {
      expect(
        () => serviceB.accept(
          bad,
          identity: identityB,
          name: 'Phone',
          platform: 'android',
        ),
        throwsFormatException,
        reason: bad,
      );
    }
    expect(await serviceB.hasGroupKey(), isFalse);
  });

  test('inviter keeps one stable group key across invitations', () async {
    final identityA = await DeviceIdentity.loadOrCreate(storeA, a.id);
    final one = await serviceA.createInvitation(
      identity: identityA,
      name: 'L',
      platform: 'macos',
    );
    final two = await serviceA.createInvitation(
      identity: identityA,
      name: 'L',
      platform: 'macos',
    );

    // Different payload timestamps aside, the embedded group key matches.
    String gk(String s) => RegExp(r'"gk":"([^"]+)"').firstMatch(s)!.group(1)!;
    expect(gk(one), gk(two));
  });
}
