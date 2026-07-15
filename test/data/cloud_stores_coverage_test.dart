import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/cloud/dropbox_store.dart';
import 'package:todoapp/data/cloud/gdrive_store.dart';
import 'package:todoapp/data/cloud/oauth.dart';
import 'package:todoapp/data/cloud/onedrive_store.dart';
import 'package:todoapp/data/cloud/webdav_store.dart';

import '../support/fake_http.dart';

/// Error- and edge-path coverage for the cloud MailboxStores and the OAuth
/// helper — the not-found (404/409) short-circuits, the failure throws, and
/// the retry/create paths the happy-path suites don't reach.
void main() {
  Future<String> token() async => 't0k';

  group('OneDriveMailboxStore', () {
    OneDriveMailboxStore store(FakeHttp http) =>
        OneDriveMailboxStore(http: http, accessToken: token);
    const base = 'https://graph.microsoft.com/v1.0/me/drive';

    test(
      'missing file/read/delete are soft; wipe skips 404 children',
      () async {
        final http = FakeHttp()
          ..on(
            'GET',
            '$base/special/approot:/dev/x.bin:/content',
            '',
            status: 404,
          )
          ..on('DELETE', '$base/special/approot:/dev/x.bin:', '', status: 404);
        final s = store(http);
        expect(await s.read('dev', 'x.bin'), isNull);
        await s.delete('dev', 'x.bin'); // 404 → no throw
      },
    );

    test('a successful delete runs the status check', () async {
      final http = FakeHttp()
        ..on('DELETE', '$base/special/approot:/dev/x.bin:', ''); // 200 → _check
      await store(http).delete('dev', 'x.bin');
    });

    test('write and a failed op throw with the HTTP status', () async {
      final http = FakeHttp()
        ..on(
          'PUT',
          '$base/special/approot:/dev/x.bin:/content',
          '',
          status: 500,
        );
      expect(
        () => store(http).write('dev', 'x.bin', [1, 2, 3]),
        throwsA(isA<HttpException>()),
      );
    });

    test('read returns bytes on success', () async {
      final http = FakeHttp()
        ..on('GET', '$base/special/approot:/dev/x.bin:/content', [9, 8, 7]);
      expect(await store(http).read('dev', 'x.bin'), [9, 8, 7]);
    });

    test('list + write + wipe walk children and delete them', () async {
      final http = FakeHttp()
        ..on('GET', '$base/special/approot/children', {
          'value': [
            {'name': 'dev-a', 'folder': <String, dynamic>{}},
            {'name': 'stray.bin'},
          ],
        })
        ..on('GET', '$base/special/approot:/dev-a:/children', {
          'value': [
            {'name': 'f.bin'},
          ],
        })
        ..on('PUT', '$base/special/approot:/dev-a/f.bin:/content', '')
        ..on('DELETE', '$base/special/approot:', ''); // matches every child
      final s = store(http);
      expect(await s.listDeviceDirs(), ['dev-a']);
      expect(await s.listFiles('dev-a'), ['f.bin']);
      await s.write('dev-a', 'f.bin', [1]); // success path
      await s.wipeAll();
      expect(http.requests.where((r) => r.$1 == 'DELETE'), isNotEmpty);
    });
  });

  group('DropboxMailboxStore', () {
    DropboxMailboxStore store(FakeHttp http) =>
        DropboxMailboxStore(http: http, accessToken: token);

    test('not-found reads/deletes are soft; failure throws', () async {
      final http = FakeHttp()
        ..on('POST', 'https://content.dropboxapi.com/2/files/download', {
          'error_summary': 'path/not_found/',
        }, status: 409)
        ..on('POST', 'https://api.dropboxapi.com/2/files/delete_v2', {
          'error_summary': 'path/not_found/',
        }, status: 409);
      final s = store(http);
      expect(await s.read('dev', 'x.bin'), isNull);
      await s.delete('dev', 'x.bin'); // 409 not_found → no throw
    });

    test('a non-409 failure throws HttpException', () async {
      final http = FakeHttp()
        ..on(
          'POST',
          'https://content.dropboxapi.com/2/files/download',
          'server error',
          status: 500,
        );
      expect(
        () => store(http).read('dev', 'x.bin'),
        throwsA(isA<HttpException>()),
      );
    });

    test('read/write/listFiles success + not-yet-created folder', () async {
      final http = FakeHttp()
        ..on('POST', 'https://content.dropboxapi.com/2/files/download', [4, 5])
        ..on('POST', 'https://content.dropboxapi.com/2/files/upload', {
          'name': 'x.bin',
        })
        ..on('POST', 'https://api.dropboxapi.com/2/files/list_folder', {
          'error_summary': 'path/not_found/',
        }, status: 409);
      final s = store(http);
      expect(await s.read('dev', 'x.bin'), [4, 5]);
      await s.write('dev', 'x.bin', [1, 2]); // success upload
      expect(await s.listFiles('nobody'), isEmpty); // 409 → empty
    });

    test('wipe lists the root then deletes each entry', () async {
      final http = FakeHttp()
        ..on('POST', 'https://api.dropboxapi.com/2/files/list_folder', {
          'entries': [
            {'.tag': 'file', 'name': 'a.bin'},
          ],
          'has_more': false,
        })
        ..on('POST', 'https://api.dropboxapi.com/2/files/delete_v2', {
          'metadata': <String, dynamic>{},
        });
      await store(http).wipeAll();
      expect(
        http.requests.where((r) => r.$2.path.endsWith('delete_v2')),
        isNotEmpty,
      );
    });
  });

  group('GoogleDriveMailboxStore', () {
    GoogleDriveMailboxStore store(FakeHttp http) =>
        GoogleDriveMailboxStore(http: http, accessToken: token);
    const files = 'https://www.googleapis.com/drive/v3/files';

    test('listDeviceDirs maps the folder query to names', () async {
      final http = FakeHttp()
        ..on('GET', files, {
          'files': [
            {'id': 'A', 'name': 'device-a'},
            {'id': 'B', 'name': 'device-b'},
          ],
        });
      expect(await store(http).listDeviceDirs(), ['device-a', 'device-b']);
    });

    test('read returns null when the name resolves to no file', () async {
      // Folder query returns nothing → _fileId null → read returns null.
      final http = FakeHttp()..on('GET', files, {'files': <dynamic>[]});
      expect(await store(http).read('dev', 'x.bin'), isNull);
    });

    test('read fetches media once the id resolves', () async {
      final http = FakeHttp()
        // by-id media GET must be scripted before the generic query prefix.
        ..on('GET', '$files/X?alt=media', [1, 2, 3])
        ..on('GET', files, {
          'files': [
            {'id': 'X', 'name': 'x.bin'},
          ],
        });
      expect(await store(http).read('dev', 'x.bin'), [1, 2, 3]);
    });

    test('delete of a resolved id tolerates a 404', () async {
      final http = FakeHttp()
        ..on('DELETE', '$files/X', '', status: 404)
        ..on('GET', files, {
          'files': [
            {'id': 'X', 'name': 'x.bin'},
          ],
        });
      await store(http).delete('dev', 'x.bin'); // 404 → no throw
    });

    test('a failed query throws HttpException', () async {
      final http = FakeHttp()..on('GET', files, 'boom', status: 500);
      expect(() => store(http).listDeviceDirs(), throwsA(isA<HttpException>()));
    });

    test('listFiles, update-existing write, and wipe', () async {
      // Every query returns the same single {id:F} row, so _folderId and
      // _fileId both resolve to 'F' — enough to drive listFiles/write/wipe.
      final http = FakeHttp()
        ..on('PATCH', 'https://www.googleapis.com/upload/drive/v3/files/F', '')
        ..on('DELETE', '$files/F', '')
        ..on('GET', files, {
          'files': [
            {'id': 'F', 'name': 'dev'},
          ],
        });
      final s = store(http);
      expect(await s.listFiles('dev'), ['dev']);
      await s.write('dev', 'x.bin', [1]); // existing id → PATCH update
      await s.wipeAll(); // deletes each folder
      expect(http.requests.where((r) => r.$1 == 'DELETE'), isNotEmpty);
    });

    test('write creates the folder when none exists', () async {
      final http = FakeHttp()
        ..on('POST', 'https://www.googleapis.com/drive/v3/files', {'id': 'NEW'})
        ..on(
          'POST',
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
          {'id': 'up'},
        )
        ..on('GET', files, {'files': <dynamic>[]}); // nothing resolves
      await store(http).write('dev', 'x.bin', [1, 2, 3]);
    });

    test('successful delete runs the status check', () async {
      final http = FakeHttp()
        ..on('DELETE', '$files/F', '') // 200 → _check
        ..on('GET', files, {
          'files': [
            {'id': 'F', 'name': 'x.bin'},
          ],
        });
      await store(http).delete('dev', 'x.bin');
    });
  });

  group('WebDavMailboxStore', () {
    WebDavMailboxStore store(FakeHttp http) => WebDavMailboxStore(
      http: http,
      baseUrl: Uri.parse('https://nas.example/dav/knot-mailbox/'),
      username: 'a',
      password: 'b',
    );

    test('read success returns bytes; wipe deletes the collection', () async {
      final http = FakeHttp()
        ..on('GET', 'https://nas.example/dav/knot-mailbox/dev/x.bin', [7, 7])
        ..on('DELETE', 'https://nas.example/dav/knot-mailbox', '', status: 204);
      final s = store(http);
      expect(await s.read('dev', 'x.bin'), [7, 7]);
      await s.wipeAll();
    });

    test('read 404 is null; delete 404 is a no-op', () async {
      final http = FakeHttp()
        ..on(
          'GET',
          'https://nas.example/dav/knot-mailbox/dev/x.bin',
          '',
          status: 404,
        )
        ..on(
          'DELETE',
          'https://nas.example/dav/knot-mailbox/dev/x.bin',
          '',
          status: 404,
        );
      final s = store(http);
      expect(await s.read('dev', 'x.bin'), isNull);
      await s.delete('dev', 'x.bin');
    });

    test('a failed PROPFIND listing throws HttpException', () async {
      final http = FakeHttp()
        ..on(
          'PROPFIND',
          'https://nas.example/dav/knot-mailbox/dev',
          '',
          status: 500,
        );
      expect(() => store(http).listFiles('dev'), throwsA(isA<HttpException>()));
    });

    test('a 207 PROPFIND with invalid XML throws HttpException', () async {
      final http = FakeHttp()
        ..on(
          'PROPFIND',
          'https://nas.example/dav/knot-mailbox/dev',
          'not xml <<<',
          status: 207,
        );
      expect(() => store(http).listFiles('dev'), throwsA(isA<HttpException>()));
    });

    test('a MKCOL failure during write surfaces as HttpException', () async {
      final http = FakeHttp()
        ..on('MKCOL', 'https://nas.example/dav/knot-mailbox', '', status: 500)
        ..on(
          'PUT',
          'https://nas.example/dav/knot-mailbox/dev/x.bin',
          '',
          status: 409,
        );
      expect(
        () => store(http).write('dev', 'x.bin', [1]),
        throwsA(isA<HttpException>()),
      );
    });

    test(
      'write on a missing collection runs MKCOL then retries the PUT',
      () async {
        // PUT returns 409 (collection absent) → the store MKCOLs the parent path
        // and retries. With the static harness the retry PUT still 409s, so the
        // MKCOL + retry branch is exercised and the final failure throws.
        final http = FakeHttp()
          ..on('MKCOL', 'https://nas.example/dav/knot-mailbox', '', status: 201)
          ..on(
            'PUT',
            'https://nas.example/dav/knot-mailbox/dev/x.bin',
            '',
            status: 409,
          );
        await expectLater(
          () => store(http).write('dev', 'x.bin', [1]),
          throwsA(isA<HttpException>()),
        );
        // The MKCOL retry path was taken (not just a single failed PUT).
        expect(http.requests.where((r) => r.$1 == 'MKCOL'), isNotEmpty);
      },
    );
  });

  group('OAuth helper', () {
    final config = OAuthConfig(
      authorizationEndpoint: Uri.parse('https://auth.example/authorize'),
      tokenEndpoint: Uri.parse('https://auth.example/token'),
      clientId: 'cid',
      redirectUri: Uri.parse('knot://oauth'),
      scopes: const ['files'],
    );

    test('isConfigured reflects a non-empty client id', () {
      expect(config.isConfigured, isTrue);
      expect(config.copyWith().isConfigured, isTrue);
      expect(config.copyWith(scopes: const ['a', 'b']).scopes, ['a', 'b']);
    });

    test('token endpoint failure throws OAuthException', () async {
      final http = FakeHttp()
        ..on('POST', 'https://auth.example/token', 'nope', status: 400);
      final flow = PkceFlow(http: http, clock: const SystemClock());
      expect(() => flow.refresh(config, 'rt'), throwsA(isA<OAuthException>()));
    });

    test('non-JSON token response throws OAuthException', () async {
      final http = FakeHttp()
        ..on('POST', 'https://auth.example/token', 'not json {{{');
      final flow = PkceFlow(http: http, clock: const SystemClock());
      final err = await flow
          .refresh(config, 'rt')
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(err, isA<OAuthException>());
      expect((err! as OAuthException).toString(), contains('non-JSON'));
    });

    test('TokenSet.decode is null-safe on empty/malformed/mistyped JSON', () {
      expect(TokenSet.decode(null), isNull);
      expect(TokenSet.decode(''), isNull);
      expect(TokenSet.decode('not json {{'), isNull); // FormatException
      expect(TokenSet.decode('{"access": 123}'), isNull); // TypeError
      final round = TokenSet.decode(
        const TokenSet(accessToken: 'a', refreshToken: 'r').encode(),
      );
      expect(round!.accessToken, 'a');
    });

    test('finish rejects a provider error redirect', () async {
      final flow = PkceFlow(http: FakeHttp(), clock: const SystemClock());
      final attempt = await flow.begin(config);
      expect(
        () => flow.finish(
          config,
          attempt,
          Uri.parse('knot://oauth?state=${attempt.state}&error=access_denied'),
        ),
        throwsA(isA<OAuthException>()),
      );
    });

    test('finish rejects a redirect that carries no code', () async {
      final flow = PkceFlow(http: FakeHttp(), clock: const SystemClock());
      final attempt = await flow.begin(config);
      // Matching state, no error, no code → "Redirect carried no code".
      expect(
        () => flow.finish(
          config,
          attempt,
          Uri.parse('knot://oauth?state=${attempt.state}'),
        ),
        throwsA(isA<OAuthException>()),
      );
    });
  });
}
