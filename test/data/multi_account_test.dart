import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/cloud/cloud_account_service.dart';
import 'package:todoapp/data/cloud/cloud_providers.dart';
import 'package:todoapp/data/cloud/oauth.dart';
import 'package:todoapp/data/cloud/webdav_store.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/repositories/group_repository.dart';
import 'package:todoapp/data/sync/device_identity.dart';

import '../support/fake_http.dart';

/// Multi-account registry (TASKS 8.4, ADR 0004): several signed-in
/// storage accounts at once, per-account keychain namespacing, legacy
/// single-account migration, and the group-reference removal guard.
void main() {
  final clock = FixedClock(DateTime.utc(2026, 7, 8, 12));
  const dav = 'https://nas.example/dav/knot-mailbox/';
  const dav2 = 'https://nas2.example/dav/knot-mailbox/';

  const probeOk =
      '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">'
      '<d:response><d:href>/dav/knot-mailbox/</d:href>'
      '<d:propstat><d:prop><d:resourcetype><d:collection/>'
      '</d:resourcetype></d:prop></d:propstat></d:response></d:multistatus>';

  CloudAccountService service(
    InMemoryKeyStore keyStore,
    FakeHttp http, {
    AppDatabase? db,
  }) =>
      CloudAccountService(keyStore: keyStore, http: http, clock: clock, db: db);

  test(
    'two accounts on the same provider coexist with separate secrets',
    () async {
      final keyStore = InMemoryKeyStore();
      final http = FakeHttp()
        ..on('PROPFIND', dav, probeOk, status: 207)
        ..on('PROPFIND', dav2, probeOk, status: 207);
      final s = service(keyStore, http);

      final home = await s.connectWebDav(
        serverUrl: Uri.parse('https://nas.example/dav/'),
        username: 'alice',
        password: 'pw1',
      );
      final work = await s.connectWebDav(
        serverUrl: Uri.parse('https://nas2.example/dav/'),
        username: 'alice',
        password: 'pw2',
      );

      final all = await s.accounts();
      expect(all, hasLength(2));
      expect({for (final a in all) a.label}, {'nas.example', 'nas2.example'});
      expect(home.id, isNot(work.id));

      // Secrets are namespaced per account id.
      expect(await keyStore.read('cloud_webdav:${home.id}'), contains('pw1'));
      expect(await keyStore.read('cloud_webdav:${work.id}'), contains('pw2'));

      // The last connect became primary; its store roots at nas2.
      final store = await s.mailboxStore() as WebDavMailboxStore?;
      expect(store!.root.host, 'nas2.example');
      // Address the first account explicitly.
      final homeStore =
          await s.mailboxStore(accountId: home.id) as WebDavMailboxStore?;
      expect(homeStore!.root.host, 'nas.example');
    },
  );

  test('per-account token refresh never crosses accounts', () async {
    final keyStore = InMemoryKeyStore();
    // Two dropbox accounts: one stale (refreshes), one fresh.
    await keyStore.write(
      'cloud_accounts',
      '[{"id":"d1","provider":"dropbox","label":"Dropbox 1"},'
          '{"id":"d2","provider":"dropbox","label":"Dropbox 2"}]',
    );
    await keyStore.write('cloud_primary_account', 'd1');
    await keyStore.write(
      'cloud_tokens:d1',
      TokenSet(
        accessToken: 'stale-1',
        refreshToken: 'rt-1',
        expiresAtMs: clock.now().millisecondsSinceEpoch,
      ).encode(),
    );
    await keyStore.write(
      'cloud_tokens:d2',
      const TokenSet(accessToken: 'fresh-2').encode(),
    );
    final http = FakeHttp()
      ..on('POST', 'https://api.dropboxapi.com/oauth2/token', {
        'access_token': 'rotated-1',
        'expires_in': 14400,
      });
    final s = service(keyStore, http);

    expect(await s.freshAccessToken('d1'), 'rotated-1');
    expect(await s.freshAccessToken('d2'), 'fresh-2');
    expect(http.requests, hasLength(1)); // Only d1 refreshed.
    expect(await keyStore.read('cloud_tokens:d1'), contains('rotated-1'));
    expect(await keyStore.read('cloud_tokens:d2'), contains('fresh-2'));
  });

  test(
    'legacy single-account keys migrate once, keeping the connection',
    () async {
      final keyStore = InMemoryKeyStore();
      await keyStore.write('cloud_provider', 'webdav');
      await keyStore.write(
        'cloud_webdav',
        WebDavCredentials(
          Uri.parse('https://nas.example/dav/'),
          'alice',
          'pw',
        ).encode(),
      );

      final s = service(keyStore, FakeHttp());
      final all = await s.accounts();

      expect(all, hasLength(1));
      expect(all.single.provider, CloudProviderId.webdav);
      expect(all.single.label, 'nas.example');
      expect((await s.primaryAccount())!.id, all.single.id);
      // Old keys are cleared; secrets moved to the namespaced slot.
      expect(await keyStore.read('cloud_provider'), isEmpty);
      expect(await keyStore.read('cloud_webdav'), isEmpty);
      expect(await keyStore.read('cloud_webdav:legacy'), contains('alice'));
      // Second call must not duplicate the account.
      expect(await s.accounts(), hasLength(1));
    },
  );

  test('removal is refused while a sharing group uses the account', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final keyStore = InMemoryKeyStore();
    final http = FakeHttp()..on('PROPFIND', dav, probeOk, status: 207);
    final s = service(keyStore, http, db: db);
    final account = await s.connectWebDav(
      serverUrl: Uri.parse('https://nas.example/dav/'),
      username: 'alice',
      password: 'pw',
    );

    final groups = GroupRepository(db, HlcClock(nodeId: 'dev', clock: clock));
    final family = await groups.create(
      name: 'Family',
      backendKind: 'webdav',
      localAccountRef: account.id,
    );

    await expectLater(
      s.removeAccount(account.id),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Family'),
        ),
      ),
    );
    expect(await s.accounts(), hasLength(1));

    // Re-point the group; removal now proceeds and clears everything.
    await groups.setLocalAccountRef(family.id, null);
    await s.removeAccount(account.id);
    expect(await s.accounts(), isEmpty);
    expect(await s.primaryAccount(), isNull);
    expect(await keyStore.read('cloud_webdav:${account.id}'), isEmpty);
  });

  test(
    'disconnect removes the primary account (connect-screen semantics)',
    () async {
      final keyStore = InMemoryKeyStore();
      final http = FakeHttp()..on('PROPFIND', dav, probeOk, status: 207);
      final s = service(keyStore, http);
      await s.connectWebDav(
        serverUrl: Uri.parse('https://nas.example/dav/'),
        username: 'alice',
        password: 'pw',
      );
      expect(await s.connectedProvider(), CloudProviderId.webdav);

      await s.disconnect();

      expect(await s.connectedProvider(), isNull);
      expect(await s.accounts(), isEmpty);
    },
  );
}
