import 'dart:convert';
import 'dart:io';

import '../sync/mailbox_store.dart';
import 'cloud_http.dart';

/// [MailboxStore] over Microsoft Graph's app folder (`special/approot`,
/// scope Files.ReadWrite.AppFolder — the token reaches only
/// `Apps/Knot/` in the user's OneDrive). Contents are ciphertext.
class OneDriveMailboxStore implements MailboxStore {
  OneDriveMailboxStore({required this.http, required this.accessToken});

  final CloudHttp http;
  final Future<String> Function() accessToken;

  static const _base = 'https://graph.microsoft.com/v1.0/me/drive';

  @override
  Future<List<String>> listDeviceDirs() async => (await _children(
    Uri.parse('$_base/special/approot/children'),
  )).where((e) => e.isFolder).map((e) => e.name).toList();

  @override
  Future<List<String>> listFiles(String deviceDir) async => (await _children(
    Uri.parse('$_base/special/approot:/$deviceDir:/children'),
  )).where((e) => !e.isFolder).map((e) => e.name).toList();

  @override
  Future<List<int>?> read(String deviceDir, String name) async {
    // Graph answers content GETs with a 302 to a pre-signed download URL;
    // dart:io follows redirects for GET by default via HttpClient? Our
    // wrapper doesn't disable them, so we receive the bytes directly.
    final response = await _send(
      'GET',
      Uri.parse('$_base/special/approot:/$deviceDir/$name:/content'),
    );
    if (response.status == 404) return null;
    _check(response, 'download');
    return response.bodyBytes;
  }

  @override
  Future<void> write(String deviceDir, String name, List<int> bytes) async {
    // Simple upload creates missing parent folders along the path.
    final response = await _send(
      'PUT',
      Uri.parse('$_base/special/approot:/$deviceDir/$name:/content'),
      contentType: 'application/octet-stream',
      body: bytes,
    );
    _check(response, 'upload');
  }

  @override
  Future<void> delete(String deviceDir, String name) async {
    final response = await _send(
      'DELETE',
      Uri.parse('$_base/special/approot:/$deviceDir/$name:'),
    );
    if (response.status == 404) return;
    _check(response, 'delete');
  }

  @override
  Future<void> wipeAll() async {
    for (final entry in await _children(
      Uri.parse('$_base/special/approot/children'),
    )) {
      final response = await _send(
        'DELETE',
        Uri.parse('$_base/special/approot:/${entry.name}:'),
      );
      if (response.status != 404) _check(response, 'wipe');
    }
  }

  Future<List<_Entry>> _children(Uri url) async {
    final entries = <_Entry>[];
    Uri? next = url;
    while (next != null) {
      final response = await _send('GET', next);
      if (response.status == 404) return entries; // Folder not created yet.
      _check(response, 'children');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      for (final e in json['value'] as List<dynamic>) {
        final map = e as Map<String, dynamic>;
        entries.add(_Entry(map['name'] as String, map.containsKey('folder')));
      }
      final link = json['@odata.nextLink'] as String?;
      next = link == null ? null : Uri.parse(link);
    }
    return entries;
  }

  Future<CloudHttpResponse> _send(
    String method,
    Uri url, {
    String? contentType,
    List<int>? body,
  }) async => http.send(
    method,
    url,
    headers: {
      'Authorization': 'Bearer ${await accessToken()}',
      'Content-Type': ?contentType,
    },
    body: body,
  );

  void _check(CloudHttpResponse response, String op) {
    if (!response.ok) {
      throw HttpException('OneDrive $op failed: HTTP ${response.status}');
    }
  }
}

class _Entry {
  const _Entry(this.name, this.isFolder);

  final String name;
  final bool isFolder;
}
