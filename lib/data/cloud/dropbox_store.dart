import 'dart:convert';
import 'dart:io';

import '../sync/mailbox_store.dart';
import 'cloud_http.dart';

/// [MailboxStore] over the Dropbox HTTP API (app-folder scoped app, so
/// every path below is relative to `Apps/Knot/` and the token can touch
/// nothing else). Contents are ciphertext before they get here.
class DropboxMailboxStore implements MailboxStore {
  DropboxMailboxStore({
    required this.http,
    required this.accessToken,
    this.rootPath = '',
  });

  final CloudHttp http;

  /// Fresh token per call — the account service refreshes behind this.
  final Future<String> Function() accessToken;

  /// Dropbox path that contains the Knot mailbox. Empty means the app folder
  /// root; shared groups can point at a mounted shared folder.
  final String rootPath;

  static final _api = Uri.parse('https://api.dropboxapi.com');
  static final _content = Uri.parse('https://content.dropboxapi.com');

  @override
  Future<List<String>> listDeviceDirs() async => (await _listFolder(
    _root,
  )).where((e) => e.isFolder).map((e) => e.name).toList();

  @override
  Future<List<String>> listFiles(String deviceDir) async => (await _listFolder(
    _path(deviceDir),
  )).where((e) => !e.isFolder).map((e) => e.name).toList();

  @override
  Future<List<int>?> read(String deviceDir, String name) async {
    final response = await http.send(
      'POST',
      _content.replace(path: '/2/files/download'),
      headers: {
        'Authorization': 'Bearer ${await accessToken()}',
        'Dropbox-API-Arg': jsonEncode({'path': _path(deviceDir, name)}),
      },
    );
    if (response.status == 409) return null; // not_found
    _check(response, 'download');
    return response.bodyBytes;
  }

  @override
  Future<void> write(String deviceDir, String name, List<int> bytes) async {
    final response = await http.send(
      'POST',
      _content.replace(path: '/2/files/upload'),
      headers: {
        'Authorization': 'Bearer ${await accessToken()}',
        'Dropbox-API-Arg': jsonEncode({
          'path': _path(deviceDir, name),
          'mode': 'overwrite',
          'mute': true,
        }),
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );
    _check(response, 'upload');
  }

  @override
  Future<void> delete(String deviceDir, String name) =>
      _delete(_path(deviceDir, name));

  @override
  Future<void> wipeAll() async {
    for (final entry in await _listFolder(_root)) {
      await _delete(_path(entry.name));
    }
  }

  String get _root {
    final clean = rootPath
        .trim()
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
    return clean.isEmpty ? '' : '/$clean';
  }

  String _path(String first, [String? second]) {
    final parts = [
      if (_root.isNotEmpty) _root.substring(1),
      first,
      ?second,
    ].where((part) => part.isNotEmpty).join('/');
    return parts.isEmpty ? '' : '/$parts';
  }

  Future<void> _delete(String path) async {
    final response = await _rpc('/2/files/delete_v2', {'path': path});
    if (response.status == 409) return; // Already gone.
    _check(response, 'delete');
  }

  Future<List<_Entry>> _listFolder(String path) async {
    var response = await _rpc('/2/files/list_folder', {'path': path});
    if (response.status == 409) return const []; // Folder not created yet.
    _check(response, 'list_folder');
    final entries = <_Entry>[];
    while (true) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      for (final e in json['entries'] as List<dynamic>) {
        final map = e as Map<String, dynamic>;
        entries.add(_Entry(map['name'] as String, map['.tag'] == 'folder'));
      }
      if (json['has_more'] != true) return entries;
      response = await _rpc('/2/files/list_folder/continue', {
        'cursor': json['cursor'],
      });
      _check(response, 'list_folder/continue');
    }
  }

  Future<CloudHttpResponse> _rpc(String path, Map<String, Object?> arg) async =>
      http.send(
        'POST',
        _api.replace(path: path),
        headers: {
          'Authorization': 'Bearer ${await accessToken()}',
          'Content-Type': 'application/json',
        },
        body: utf8.encode(jsonEncode(arg)),
      );

  void _check(CloudHttpResponse response, String op) {
    if (!response.ok) {
      throw HttpException('Dropbox $op failed: HTTP ${response.status}');
    }
  }
}

class _Entry {
  const _Entry(this.name, this.isFolder);

  final String name;
  final bool isFolder;
}
