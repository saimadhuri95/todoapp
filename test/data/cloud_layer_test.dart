import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/cloud/cloud_account_service.dart';
import 'package:todoapp/data/cloud/cloud_providers.dart';
import 'package:todoapp/data/cloud/dropbox_store.dart';
import 'package:todoapp/data/cloud/gdrive_store.dart';
import 'package:todoapp/data/cloud/oauth.dart';
import 'package:todoapp/data/cloud/onedrive_store.dart';
import 'package:todoapp/data/sync/device_identity.dart';

import '../support/fake_http.dart';

OAuthConfig testConfig({Map<String, String> extra = const {}}) => OAuthConfig(
  authorizationEndpoint: Uri.parse('https://auth.example/authorize'),
  tokenEndpoint: Uri.parse('https://auth.example/token'),
  clientId: 'client-123',
  redirectUri: Uri.parse('knot://oauth'),
  scopes: const ['files.read'],
  extraAuthParams: extra,
);

void main() {
  final clock = FixedClock(DateTime.utc(2026, 7, 8, 12));

  group('PkceFlow', () {
    test(
      'authorization URL carries PKCE + state and provider extras',
      () async {
        final flow = PkceFlow(http: FakeHttp(), clock: clock);
        final attempt = await flow.begin(
          testConfig(extra: {'token_access_type': 'offline'}),
        );
        final params = attempt.authorizationUrl.queryParameters;

        expect(params['response_type'], 'code');
        expect(params['client_id'], 'client-123');
        expect(params['redirect_uri'], 'knot://oauth');
        expect(params['scope'], 'files.read');
        expect(params['code_challenge_method'], 'S256');
        expect(params['state'], attempt.state);
        expect(params['token_access_type'], 'offline');

        // The challenge really is base64url(sha256(verifier)), unpadded.
        final expected = base64UrlEncode(
          (await Sha256().hash(ascii.encode(attempt.codeVerifier))).bytes,
        ).replaceAll('=', '');
        expect(params['code_challenge'], expected);
      },
    );

    test(
      'finish exchanges the code and stamps expiry from the clock',
      () async {
        final http = FakeHttp()
          ..on('POST', 'https://auth.example/token', {
            'access_token': 'at-1',
            'refresh_token': 'rt-1',
            'expires_in': 3600,
          });
        final flow = PkceFlow(http: http, clock: clock);
        final config = testConfig();
        final attempt = await flow.begin(config);

        final tokens = await flow.finish(
          config,
          attempt,
          Uri.parse('knot://oauth?code=c0de&state=${attempt.state}'),
        );

        expect(tokens.accessToken, 'at-1');
        expect(tokens.refreshToken, 'rt-1');
        expect(
          tokens.expiresAtMs,
          clock.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
        );
        final sent = Uri.splitQueryString(
          utf8.decode(http.requests.single.$4!),
        );
        expect(sent['grant_type'], 'authorization_code');
        expect(sent['code'], 'c0de');
        expect(sent['code_verifier'], attempt.codeVerifier);
        expect(sent['client_id'], 'client-123');
      },
    );

    test('finish rejects a state mismatch and provider errors', () async {
      final flow = PkceFlow(http: FakeHttp(), clock: clock);
      final config = testConfig();
      final attempt = await flow.begin(config);

      expect(
        () => flow.finish(
          config,
          attempt,
          Uri.parse('knot://oauth?code=x&state=forged'),
        ),
        throwsA(isA<OAuthException>()),
      );
      expect(
        () => flow.finish(
          config,
          attempt,
          Uri.parse('knot://oauth?error=access_denied&state=${attempt.state}'),
        ),
        throwsA(isA<OAuthException>()),
      );
    });

    test(
      'refresh keeps the old refresh token when none is rotated in',
      () async {
        final http = FakeHttp()
          ..on('POST', 'https://auth.example/token', {
            'access_token': 'at-2',
            'expires_in': 3600,
          });
        final flow = PkceFlow(http: http, clock: clock);

        final tokens = await flow.refresh(testConfig(), 'rt-keep');

        expect(tokens.accessToken, 'at-2');
        expect(tokens.refreshToken, 'rt-keep');
      },
    );
  });

  group('TokenSet', () {
    test('round-trips through encode/decode', () {
      final decoded = TokenSet.decode(
        const TokenSet(
          accessToken: 'a',
          refreshToken: 'r',
          expiresAtMs: 123,
        ).encode(),
      )!;
      expect(decoded.accessToken, 'a');
      expect(decoded.refreshToken, 'r');
      expect(decoded.expiresAtMs, 123);
      expect(TokenSet.decode(null), isNull);
      expect(TokenSet.decode(''), isNull);
      expect(TokenSet.decode('not json'), isNull);
    });

    test('expiry honors slack; unknown lifetime never expires', () {
      final now = DateTime.utc(2026, 7, 8, 12);
      final soon = TokenSet(
        accessToken: 'a',
        expiresAtMs: now.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      );
      expect(soon.isExpired(now), isTrue); // Inside the 2 min slack.
      final later = TokenSet(
        accessToken: 'a',
        expiresAtMs: now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      );
      expect(later.isExpired(now), isFalse);
      expect(const TokenSet(accessToken: 'a').isExpired(now), isFalse);
    });
  });

  group('CloudAccountService', () {
    test('connect is refused when the client id is not configured', () async {
      final service = CloudAccountService(
        keyStore: InMemoryKeyStore(),
        http: FakeHttp(),
        clock: clock,
      );
      // Default build: no dart-define client ids injected.
      expect(
        () => service.connect(
          CloudProviderId.dropbox,
          authenticate: (_) async => Uri.parse('knot://oauth'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('connect fetches and persists a Dropbox account label', () async {
      final http = FakeHttp()
        ..on('POST', 'https://auth.example/token', {
          'access_token': 'at-1',
          'refresh_token': 'rt-1',
        })
        ..on('POST', 'https://api.dropboxapi.com/2/users/get_current_account', {
          'email': 'ada@example.com',
          'name': {'display_name': 'Ada Lovelace'},
        });
      final service = CloudAccountService(
        keyStore: InMemoryKeyStore(),
        http: http,
        clock: clock,
      );

      final account = await service.connect(
        CloudProviderId.dropbox,
        configOverride: testConfig(),
        authenticate: (url) async => Uri.parse(
          'knot://oauth?code=c0de&state=${url.queryParameters['state']}',
        ),
      );

      expect(account.label, 'Ada Lovelace (ada@example.com)');
      expect((await service.accounts()).single.label, account.label);
    });

    test(
      'freshAccessToken refreshes an expired token and persists it',
      () async {
        final keyStore = InMemoryKeyStore();
        await keyStore.write('cloud_provider', 'dropbox');
        await keyStore.write(
          'cloud_tokens',
          TokenSet(
            accessToken: 'stale',
            refreshToken: 'rt',
            expiresAtMs: clock.now().millisecondsSinceEpoch, // Already stale.
          ).encode(),
        );
        final http = FakeHttp()
          ..on('POST', 'https://api.dropboxapi.com/oauth2/token', {
            'access_token': 'fresh',
            'expires_in': 14400,
          });
        final service = CloudAccountService(
          keyStore: keyStore,
          http: http,
          clock: clock,
        );

        expect(await service.freshAccessToken(), 'fresh');
        // Rotated set persisted: a second call needs no further HTTP.
        expect(await service.freshAccessToken(), 'fresh');
        expect(http.requests, hasLength(1));
      },
    );

    test(
      'disconnect forgets provider and tokens; store becomes null',
      () async {
        final keyStore = InMemoryKeyStore();
        await keyStore.write('cloud_provider', 'oneDrive');
        await keyStore.write(
          'cloud_tokens',
          const TokenSet(accessToken: 'a').encode(),
        );
        final service = CloudAccountService(
          keyStore: keyStore,
          http: FakeHttp(),
          clock: clock,
        );
        expect(await service.connectedProvider(), CloudProviderId.oneDrive);
        expect(await service.mailboxStore(), isA<OneDriveMailboxStore>());

        await service.disconnect();

        expect(await service.connectedProvider(), isNull);
        expect(await service.mailboxStore(), isNull);
      },
    );
  });

  group('DropboxMailboxStore', () {
    Future<String> token() async => 't0k';

    test('lists folders, paginating and separating files from dirs', () async {
      final http = FakeHttp()
        ..on(
          'POST',
          'https://api.dropboxapi.com/2/files/list_folder/continue',
          {
            'entries': [
              {'.tag': 'folder', 'name': 'device-b'},
            ],
            'has_more': false,
          },
        )
        ..on('POST', 'https://api.dropboxapi.com/2/files/list_folder', {
          'entries': [
            {'.tag': 'folder', 'name': 'device-a'},
            {'.tag': 'file', 'name': 'stray.txt'},
          ],
          'has_more': true,
          'cursor': 'c1',
        });
      final store = DropboxMailboxStore(http: http, accessToken: token);

      expect(await store.listDeviceDirs(), ['device-a', 'device-b']);
      expect(http.requests.first.$3['Authorization'], 'Bearer t0k');
    });

    test('missing folder lists empty; missing file reads null', () async {
      final http = FakeHttp()
        ..on('POST', 'https://api.dropboxapi.com/2/files/list_folder', {
          'error_summary': 'path/not_found/',
        }, status: 409)
        ..on('POST', 'https://content.dropboxapi.com/2/files/download', {
          'error_summary': 'path/not_found/',
        }, status: 409);
      final store = DropboxMailboxStore(http: http, accessToken: token);

      expect(await store.listFiles('nobody'), isEmpty);
      expect(await store.read('nobody', 'x.bin'), isNull);
    });

    test(
      'write uploads bytes with overwrite mode; failure throws IOException',
      () async {
        final http = FakeHttp()
          ..on('POST', 'https://content.dropboxapi.com/2/files/upload', {
            'name': 'f.bin',
          });
        final store = DropboxMailboxStore(http: http, accessToken: token);

        await store.write('dev', 'f.bin', [1, 2, 3]);

        final (_, _, headers, body) = http.requests.single;
        expect(body, [1, 2, 3]);
        final arg = jsonDecode(headers['Dropbox-API-Arg']!) as Map;
        expect(arg['path'], '/dev/f.bin');
        expect(arg['mode'], 'overwrite');

        final failing = DropboxMailboxStore(
          http: FakeHttp()
            ..on('POST', 'https://content.dropboxapi.com/2/files/upload', {
              'error': 'boom',
            }, status: 500),
          accessToken: token,
        );
        expect(
          () => failing.write('dev', 'f.bin', [1]),
          throwsA(isA<IOException>()),
        );
      },
    );

    test('write can root Dropbox mailboxes in a shared folder', () async {
      final http = FakeHttp()
        ..on('POST', 'https://content.dropboxapi.com/2/files/upload', {
          'name': 'f.bin',
        });
      final store = DropboxMailboxStore(
        http: http,
        accessToken: () async => 'shared',
        rootPath: '/Team Knot',
      );

      await store.write('dev', 'f.bin', [1]);

      final arg =
          jsonDecode(http.requests.single.$3['Dropbox-API-Arg']!) as Map;
      expect(arg['path'], '/Team Knot/dev/f.bin');
    });
  });

  group('OneDriveMailboxStore', () {
    Future<String> token() async => 'graph';
    const base = 'https://graph.microsoft.com/v1.0/me/drive';

    test('follows @odata.nextLink and tells folders from files', () async {
      final http = FakeHttp()
        ..on('GET', '$base/special/approot/children?page=2', {
          'value': [
            {'name': 'device-b', 'folder': <String, Object>{}},
          ],
        })
        ..on('GET', '$base/special/approot/children', {
          'value': [
            {'name': 'device-a', 'folder': <String, Object>{}},
            {'name': 'stray.txt', 'file': <String, Object>{}},
          ],
          '@odata.nextLink': '$base/special/approot/children?page=2',
        });
      final store = OneDriveMailboxStore(http: http, accessToken: token);

      expect(await store.listDeviceDirs(), ['device-a', 'device-b']);
    });

    test('404s: empty listing, null read, silent delete', () async {
      final http = FakeHttp()
        ..on('GET', '$base/special/approot:/dev:/children', '', status: 404)
        ..on(
          'GET',
          '$base/special/approot:/dev/f.bin:/content',
          '',
          status: 404,
        )
        ..on('DELETE', '$base/special/approot:/dev/f.bin:', '', status: 404);
      final store = OneDriveMailboxStore(http: http, accessToken: token);

      expect(await store.listFiles('dev'), isEmpty);
      expect(await store.read('dev', 'f.bin'), isNull);
      await store.delete('dev', 'f.bin'); // Must not throw.
    });

    test(
      'write PUTs raw bytes to the path-addressed content endpoint',
      () async {
        final http = FakeHttp()
          ..on('PUT', '$base/special/approot:/dev/f.bin:/content', {'id': '1'});
        final store = OneDriveMailboxStore(http: http, accessToken: token);

        await store.write('dev', 'f.bin', [9, 8]);

        final (method, url, headers, body) = http.requests.single;
        expect(method, 'PUT');
        expect(url.toString(), '$base/special/approot:/dev/f.bin:/content');
        expect(headers['Authorization'], 'Bearer graph');
        expect(body, [9, 8]);
      },
    );
  });

  group('GoogleDriveMailboxStore', () {
    Future<String> token() async => 'gd';

    test('write creates the device folder then multiparts the file in', () async {
      final http = FakeHttp()
        // Every metadata query comes back empty: nothing exists yet.
        ..on('GET', 'https://www.googleapis.com/drive/v3/files?', {
          'files': <Object>[],
        })
        ..on('POST', 'https://www.googleapis.com/drive/v3/files', {
          'id': 'folder-1',
        })
        ..on(
          'POST',
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
          {'id': 'file-1'},
        );
      final store = GoogleDriveMailboxStore(http: http, accessToken: token);

      await store.write('dev', 'f.bin', [7]);

      final upload = http.requests.last;
      expect(upload.$3['Content-Type'], contains('multipart/related'));
      final bodyText = String.fromCharCodes(upload.$4!);
      expect(bodyText, contains('"parents":["folder-1"]'));
      expect(bodyText, contains('"name":"f.bin"'));
    });

    test('read resolves folder + file ids then downloads media', () async {
      final http = FakeHttp()
        ..on(
          'GET',
          'https://www.googleapis.com/drive/v3/files/file-9?alt=media',
          [4, 2],
        )
        ..on('GET', 'https://www.googleapis.com/drive/v3/files?', {
          'files': [
            {'id': 'file-9', 'name': 'f.bin'},
          ],
        });
      final store = GoogleDriveMailboxStore(http: http, accessToken: token);

      expect(await store.read('dev', 'f.bin'), [4, 2]);
    });

    test('missing folder means empty listing and null read', () async {
      final http = FakeHttp()
        ..on('GET', 'https://www.googleapis.com/drive/v3/files?', {
          'files': <Object>[],
        });
      final store = GoogleDriveMailboxStore(http: http, accessToken: token);

      expect(await store.listFiles('dev'), isEmpty);
      expect(await store.read('dev', 'f.bin'), isNull);
    });
  });
}
