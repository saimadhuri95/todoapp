import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/sync/device_identity.dart';
import 'package:todoapp/data/sync/pairing_crypto.dart';

void main() {
  group('PairingCrypto', () {
    test(
      'both sides derive the same session key; seal/open roundtrips',
      () async {
        final alice = await PairingCrypto.generateIdentity();
        final bob = await PairingCrypto.generateIdentity();

        final aliceKey = await PairingCrypto.deriveSessionKey(
          mine: alice,
          theirs: await bob.extractPublicKey(),
          myDeviceId: 'device-a',
          theirDeviceId: 'device-b',
        );
        final bobKey = await PairingCrypto.deriveSessionKey(
          mine: bob,
          theirs: await alice.extractPublicKey(),
          myDeviceId: 'device-b',
          theirDeviceId: 'device-a',
        );

        final plaintext = utf8.encode('{"v":1,"writes":[]}');
        final sealed = await PairingCrypto.seal(plaintext, aliceKey);
        expect(await PairingCrypto.open(sealed, bobKey), plaintext);
        // Ciphertext never contains the plaintext.
        expect(String.fromCharCodes(sealed).contains('writes'), isFalse);
      },
    );

    test('tampered ciphertext fails authentication', () async {
      final alice = await PairingCrypto.generateIdentity();
      final key = await PairingCrypto.deriveSessionKey(
        mine: alice,
        theirs: await alice.extractPublicKey(),
        myDeviceId: 'a',
        theirDeviceId: 'b',
      );
      final sealed = await PairingCrypto.seal(utf8.encode('secret'), key);
      sealed[sealed.length ~/ 2] ^= 0xFF;

      expect(
        () => PairingCrypto.open(sealed, key),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('wrong key fails authentication', () async {
      final a = await PairingCrypto.generateIdentity();
      final b = await PairingCrypto.generateIdentity();
      final keyA = await PairingCrypto.deriveSessionKey(
        mine: a,
        theirs: await a.extractPublicKey(),
        myDeviceId: 'a',
        theirDeviceId: 'a2',
      );
      final keyB = await PairingCrypto.deriveSessionKey(
        mine: b,
        theirs: await b.extractPublicKey(),
        myDeviceId: 'b',
        theirDeviceId: 'b2',
      );
      final sealed = await PairingCrypto.seal(utf8.encode('x'), keyA);

      expect(
        () => PairingCrypto.open(sealed, keyB),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test(
      'same plaintext seals to different ciphertexts (random nonce)',
      () async {
        final id = await PairingCrypto.generateIdentity();
        final key = await PairingCrypto.deriveSessionKey(
          mine: id,
          theirs: await id.extractPublicKey(),
          myDeviceId: 'a',
          theirDeviceId: 'b',
        );
        final one = await PairingCrypto.seal(utf8.encode('same'), key);
        final two = await PairingCrypto.seal(utf8.encode('same'), key);
        expect(base64Encode(one), isNot(base64Encode(two)));
      },
    );

    test('fingerprint is symmetric and key-dependent', () async {
      final a = await (await PairingCrypto.generateIdentity())
          .extractPublicKey();
      final b = await (await PairingCrypto.generateIdentity())
          .extractPublicKey();
      final c = await (await PairingCrypto.generateIdentity())
          .extractPublicKey();

      final ab = await PairingCrypto.fingerprint(a, b);
      final ba = await PairingCrypto.fingerprint(b, a);
      final ac = await PairingCrypto.fingerprint(a, c);

      expect(ab, ba);
      expect(ab, isNot(ac));
      expect(ab, matches(RegExp(r'^[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$')));
    });
  });

  group('PairingPayload', () {
    test('encode/decode roundtrips with a usable public key', () async {
      final identity = await PairingCrypto.generateIdentity();
      final publicKey = await identity.extractPublicKey();
      final payload = PairingPayload(
        deviceId: 'device-1',
        name: 'My Phone',
        platform: 'android',
        publicKeyBase64: base64Encode(publicKey.bytes),
      );

      final decoded = PairingPayload.decode(payload.encode());
      expect(decoded.deviceId, 'device-1');
      expect(decoded.name, 'My Phone');
      expect(decoded.publicKey.bytes, publicKey.bytes);
    });

    test('rejects unknown version', () {
      expect(
        () => PairingPayload.decode(
          '{"v":9,"id":"x","name":"n",'
          '"platform":"p","pk":""}',
        ),
        throwsFormatException,
      );
    });
  });

  group('DeviceIdentity', () {
    test('creates once, persists, reloads the same key', () async {
      final store = InMemoryKeyStore();

      final first = await DeviceIdentity.loadOrCreate(store, 'dev-1');
      final second = await DeviceIdentity.loadOrCreate(store, 'dev-1');

      expect((await first.publicKey).bytes, (await second.publicKey).bytes);
    });

    test('pairing payload carries the identity public key', () async {
      final identity = await DeviceIdentity.loadOrCreate(
        InMemoryKeyStore(),
        'dev-9',
      );
      final payload = await identity.pairingPayload(
        name: 'Laptop',
        platform: 'macos',
      );

      expect(payload.deviceId, 'dev-9');
      expect(payload.publicKey.bytes, (await identity.publicKey).bytes);
    });
  });
}
