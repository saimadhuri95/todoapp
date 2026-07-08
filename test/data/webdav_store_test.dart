import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/cloud/cloud_account_service.dart';
import 'package:todoapp/data/cloud/cloud_http.dart';
import 'package:todoapp/data/cloud/cloud_providers.dart';
import 'package:todoapp/data/cloud/webdav_store.dart';
import 'package:todoapp/data/sync/device_identity.dart';

import '../support/fake_http.dart';

const _base = 'https://nas.example/dav/knot-mailbox/';

WebDavMailboxStore store(FakeHttp http) => WebDavMailboxStore(
  http: http,
  baseUrl: Uri.parse(_base),
  username: 'alice',
  password: 's3cret',
);

/// Multistatus with mixed namespace prefixes, the collection's own row,
/// one device outbox, and one stray file.
const _rootListing = '''
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/knot-mailbox/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/knot-mailbox/device-a/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/knot-mailbox/stray.txt</d:href>
    <d:propstat><d:prop><d:resourcetype/></d:prop></d:propstat>
  </d:response>
</d:multistatus>''';

void main() {
  group('WebDavMailboxStore', () {
    test('lists collections as device dirs, skipping self and files', () async {
      final http = FakeHttp()..on('PROPFIND', _base, _rootListing, status: 207);

      expect(await store(http).listDeviceDirs(), ['device-a']);

      final (_, _, headers, _) = http.requests.single;
      expect(
        headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('alice:s3cret'))}',
      );
      expect(headers['Depth'], '1');
    });

    test('missing collection lists empty; missing file reads null', () async {
      final http = FakeHttp()
        ..on('PROPFIND', '${_base}nobody/', '', status: 404)
        ..on('GET', '${_base}nobody/x.bin', '', status: 404);

      expect(await store(http).listFiles('nobody'), isEmpty);
      expect(await store(http).read('nobody', 'x.bin'), isNull);
    });

    test('write creates missing collections and retries the PUT', () async {
      var putAttempts = 0;
      final fake = _SequencedHttp((method, url) {
        if (method == 'PUT') {
          putAttempts++;
          return putAttempts == 1 ? 409 : 201;
        }
        if (method == 'MKCOL') return url.path.endsWith('dev/') ? 201 : 405;
        return 500;
      });

      await WebDavMailboxStore(
        http: fake,
        baseUrl: Uri.parse(_base),
        username: 'alice',
        password: 's3cret',
      ).write('dev', 'f.bin', [1, 2]);

      expect(putAttempts, 2);
      expect(fake.calls.where((c) => c.$1 == 'MKCOL'), hasLength(2));
      expect(fake.calls.last.$3, [1, 2]);
    });

    test('delete ignores 404; other failures throw IOException', () async {
      final http = FakeHttp()
        ..on('DELETE', '${_base}dev/gone.bin', '', status: 404)
        ..on('DELETE', '${_base}dev/locked.bin', '', status: 423);

      await store(http).delete('dev', 'gone.bin'); // Must not throw.
      expect(
        () => store(http).delete('dev', 'locked.bin'),
        throwsA(isA<IOException>()),
      );
    });

    test('probe accepts 207, creates a missing root, rejects 401', () async {
      expect(
        await store(
          FakeHttp()..on('PROPFIND', _base, _rootListing, status: 207),
        ).probe(),
        isTrue,
      );

      final created = FakeHttp()
        ..on('PROPFIND', _base, '', status: 404)
        ..on('MKCOL', _base, '', status: 201);
      expect(await store(created).probe(), isTrue);

      expect(
        await store(FakeHttp()..on('PROPFIND', _base, '', status: 401)).probe(),
        isFalse,
      );
    });
  });

  group('CloudAccountService.connectWebDav', () {
    final clock = FixedClock(DateTime.utc(2026, 7, 8));

    test('stores credentials + provider after a successful probe', () async {
      final keyStore = InMemoryKeyStore();
      final http = FakeHttp()
        ..on(
          'PROPFIND',
          'https://nas.example/dav/alice/knot-mailbox/',
          _rootListing,
          status: 207,
        );
      final service = CloudAccountService(
        keyStore: keyStore,
        http: http,
        clock: clock,
      );

      // No trailing slash on purpose: the service must not lose 'alice'.
      await service.connectWebDav(
        serverUrl: Uri.parse('https://nas.example/dav/alice'),
        username: 'alice',
        password: 'pw',
      );

      expect(await service.connectedProvider(), CloudProviderId.webdav);
      final mailbox = await service.mailboxStore();
      expect(mailbox, isA<WebDavMailboxStore>());
      expect(
        (mailbox! as WebDavMailboxStore).root.toString(),
        'https://nas.example/dav/alice/knot-mailbox/',
      );
    });

    test('rejected probe stores nothing', () async {
      final keyStore = InMemoryKeyStore();
      final service = CloudAccountService(
        keyStore: keyStore,
        http: FakeHttp()..on('PROPFIND', 'https://', '', status: 401),
        clock: clock,
      );

      await expectLater(
        service.connectWebDav(
          serverUrl: Uri.parse('https://nas.example/dav/'),
          username: 'alice',
          password: 'wrong',
        ),
        throwsA(isA<IOException>()),
      );
      expect(await service.connectedProvider(), isNull);
      expect(await service.mailboxStore(), isNull);
    });

    test('non-http URL is refused up front', () async {
      final service = CloudAccountService(
        keyStore: InMemoryKeyStore(),
        http: FakeHttp(),
        clock: clock,
      );
      expect(
        () => service.connectWebDav(
          serverUrl: Uri.parse('ftp://nas.example/'),
          username: 'a',
          password: 'b',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

/// Status-only fake where the response depends on call order.
class _SequencedHttp implements CloudHttp {
  _SequencedHttp(this.statusFor);

  final int Function(String method, Uri url) statusFor;
  final calls = <(String, Uri, List<int>?)>[];

  @override
  Future<CloudHttpResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    calls.add((method, url, body));
    return CloudHttpResponse(statusFor(method, url), const []);
  }
}
