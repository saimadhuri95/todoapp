import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../sync/mailbox_store.dart';
import 'cloud_http.dart';

/// [MailboxStore] over plain WebDAV (RFC 4918) — the zero-registration
/// backend (TASKS.md 8.11, issue #107): Nextcloud/ownCloud, NAS boxes,
/// Koofr, Fastmail, pCloud… anything speaking PROPFIND/GET/PUT/DELETE/
/// MKCOL. Auth is HTTP Basic over TLS with the user's own account or an
/// app-password; there is no OAuth and no developer console anywhere.
///
/// The store roots at `<serverUrl>/knot-mailbox/` so Knot never litters
/// the user's tree. Contents are the usual ciphertext (invariant 3):
/// even a self-hosted server learns only file sizes and timing.
class WebDavMailboxStore implements MailboxStore {
  WebDavMailboxStore({
    required this.http,
    required Uri baseUrl,
    required String username,
    required String password,
  }) : root = _slashTerminated(baseUrl),
       _auth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  final CloudHttp http;

  /// Mailbox root collection, always `/`-terminated.
  final Uri root;

  final String _auth;

  @override
  Future<List<String>> listDeviceDirs() async =>
      (await _propfind(root)).where((e) => e.isDir).map((e) => e.name).toList();

  @override
  Future<List<String>> listFiles(String deviceDir) async => (await _propfind(
    root.resolve('$deviceDir/'),
  )).where((e) => !e.isDir).map((e) => e.name).toList();

  @override
  Future<List<int>?> read(String deviceDir, String name) async {
    final response = await _send('GET', root.resolve('$deviceDir/$name'));
    if (response.status == 404) return null;
    _check(response, 'GET');
    return response.bodyBytes;
  }

  @override
  Future<void> write(String deviceDir, String name, List<int> bytes) async {
    final url = root.resolve('$deviceDir/$name');
    var response = await _send('PUT', url, body: bytes);
    // 404/409: a parent collection doesn't exist yet — create the path
    // (MKCOL 405 = already there, fine) and retry once.
    if (response.status == 404 || response.status == 409) {
      await _mkcol(root);
      await _mkcol(root.resolve('$deviceDir/'));
      response = await _send('PUT', url, body: bytes);
    }
    _check(response, 'PUT');
  }

  @override
  Future<void> delete(String deviceDir, String name) async {
    final response = await _send('DELETE', root.resolve('$deviceDir/$name'));
    if (response.status == 404) return;
    _check(response, 'DELETE');
  }

  @override
  Future<void> wipeAll() async {
    // Deleting a collection is recursive in WebDAV.
    final response = await _send('DELETE', root);
    if (response.status == 404) return;
    _check(response, 'DELETE mailbox');
  }

  /// Cheap connectivity/credential probe for the connect form: true when
  /// the server answers a depth-0 PROPFIND on the parent of [root]
  /// (the mailbox itself may not exist yet).
  Future<bool> probe() async {
    final response = await _send('PROPFIND', root, depth: '0');
    if (response.status == 404) {
      // Root missing is fine — creating it proves write access.
      await _mkcol(root);
      return true;
    }
    return response.ok || response.status == 207;
  }

  Future<void> _mkcol(Uri url) async {
    final response = await _send('MKCOL', url);
    // 405 = collection already exists; both are success for our purposes.
    if (!response.ok && response.status != 405) {
      throw HttpException('WebDAV MKCOL failed: HTTP ${response.status}');
    }
  }

  /// Depth-1 PROPFIND listing the direct children of [collection]
  /// (excluding the collection itself). 404 → empty (not created yet).
  Future<List<_DavEntry>> _propfind(Uri collection) async {
    final response = await _send('PROPFIND', collection, depth: '1');
    if (response.status == 404) return const [];
    if (response.status != 207) {
      throw HttpException('WebDAV PROPFIND failed: HTTP ${response.status}');
    }
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(utf8.decode(response.bodyBytes));
    } on XmlException {
      throw const HttpException('WebDAV PROPFIND returned invalid XML');
    }
    // Namespace prefixes vary by server (D:, d:, none) — match local names.
    final entries = <_DavEntry>[];
    final selfPath = _normalizedPath(collection.path);
    for (final element in doc.findAllElements('response', namespace: '*')) {
      final href = element.getElement('href', namespace: '*')?.innerText;
      if (href == null) continue;
      final path = _normalizedPath(Uri.parse(href.trim()).path);
      if (path == selfPath) continue; // The collection lists itself first.
      final isDir = element
          .findAllElements('resourcetype', namespace: '*')
          .any((t) => t.getElement('collection', namespace: '*') != null);
      final name = Uri.decodeComponent(path.split('/').last);
      if (name.isEmpty) continue;
      entries.add(_DavEntry(name, isDir));
    }
    return entries;
  }

  Future<CloudHttpResponse> _send(
    String method,
    Uri url, {
    List<int>? body,
    String? depth,
  }) => http.send(
    method,
    url,
    headers: {
      'Authorization': _auth,
      'Depth': ?depth,
      if (body != null) 'Content-Type': 'application/octet-stream',
    },
    body: body,
  );

  void _check(CloudHttpResponse response, String op) {
    if (!response.ok) {
      throw HttpException('WebDAV $op failed: HTTP ${response.status}');
    }
  }

  static Uri _slashTerminated(Uri url) =>
      url.path.endsWith('/') ? url : url.replace(path: '${url.path}/');

  /// Path with the trailing slash stripped, for self-row comparison
  /// (servers report collections with a trailing `/`, requests may not).
  static String _normalizedPath(String path) =>
      path.endsWith('/') ? path.substring(0, path.length - 1) : path;
}

class _DavEntry {
  const _DavEntry(this.name, this.isDir);

  final String name;
  final bool isDir;
}
