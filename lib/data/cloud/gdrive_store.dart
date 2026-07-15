import 'dart:convert';
import 'dart:io';

import '../sync/mailbox_store.dart';
import 'cloud_http.dart';

/// [MailboxStore] over the Google Drive API, kept inside the hidden
/// `appDataFolder` space (scope drive.appdata): Knot can read only its own
/// app data, nothing else in the user's Drive. Contents are ciphertext.
///
/// Drive addresses by opaque file id, not path, so each op resolves
/// names → ids with a metadata query first. Mailboxes are tiny (a folder
/// per device, ≤ ~20 files each thanks to compaction), so the extra
/// round-trips are fine.
class GoogleDriveMailboxStore implements MailboxStore {
  GoogleDriveMailboxStore({required this.http, required this.accessToken});

  final CloudHttp http;
  final Future<String> Function() accessToken;

  static const _api = 'https://www.googleapis.com/drive/v3';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3';
  static const _folderMime = 'application/vnd.google-apps.folder';

  @override
  Future<List<String>> listDeviceDirs() async => (await _query(
    "mimeType='$_folderMime' and 'appDataFolder' in parents",
  )).map((f) => f.name).toList();

  @override
  Future<List<String>> listFiles(String deviceDir) async {
    final folder = await _folderId(deviceDir);
    if (folder == null) return const [];
    return (await _query(
      "'$folder' in parents and mimeType!='$_folderMime'",
    )).map((f) => f.name).toList();
  }

  @override
  Future<List<int>?> read(String deviceDir, String name) async {
    final id = await _fileId(deviceDir, name);
    if (id == null) return null;
    final response = await _send('GET', Uri.parse('$_api/files/$id?alt=media'));
    if (response.status == 404) return null;
    _check(response, 'download');
    return response.bodyBytes;
  }

  @override
  Future<void> write(String deviceDir, String name, List<int> bytes) async {
    final existing = await _fileId(deviceDir, name);
    if (existing != null) {
      final response = await _send(
        'PATCH',
        Uri.parse('$_upload/files/$existing?uploadType=media'),
        contentType: 'application/octet-stream',
        body: bytes,
      );
      _check(response, 'update');
      return;
    }
    final folder = await _folderId(deviceDir) ?? await _createFolder(deviceDir);
    // Multipart create: JSON metadata part + media part in one request.
    const boundary = 'knot-mailbox-boundary';
    final metadata = jsonEncode({
      'name': name,
      'parents': [folder],
    });
    final body = <int>[
      ...utf8.encode(
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/octet-stream\r\n\r\n',
      ),
      ...bytes,
      ...utf8.encode('\r\n--$boundary--'),
    ];
    final response = await _send(
      'POST',
      Uri.parse('$_upload/files?uploadType=multipart'),
      contentType: 'multipart/related; boundary=$boundary',
      body: body,
    );
    _check(response, 'create');
  }

  @override
  Future<void> delete(String deviceDir, String name) async {
    final id = await _fileId(deviceDir, name);
    if (id == null) return;
    final response = await _send('DELETE', Uri.parse('$_api/files/$id'));
    if (response.status == 404) return;
    _check(response, 'delete');
  }

  @override
  Future<void> wipeAll() async {
    // Deleting each device folder removes its children with it.
    for (final folder in await _query(
      "mimeType='$_folderMime' and 'appDataFolder' in parents",
    )) {
      final response = await _send(
        'DELETE',
        Uri.parse('$_api/files/${folder.id}'),
      );
      if (response.status != 404) _check(response, 'wipe');
    }
  }

  Future<String?> _folderId(String name) async {
    final matches = await _query(
      "name='$name' and mimeType='$_folderMime' and 'appDataFolder' in parents",
    );
    return matches.isEmpty ? null : matches.first.id;
  }

  Future<String?> _fileId(String deviceDir, String name) async {
    final folder = await _folderId(deviceDir);
    if (folder == null) return null;
    final matches = await _query("name='$name' and '$folder' in parents");
    return matches.isEmpty ? null : matches.first.id;
  }

  Future<String> _createFolder(String name) async {
    final response = await _send(
      'POST',
      Uri.parse('$_api/files'),
      contentType: 'application/json',
      body: utf8.encode(
        jsonEncode({
          'name': name,
          'mimeType': _folderMime,
          'parents': ['appDataFolder'],
        }),
      ),
    );
    _check(response, 'create folder');
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<List<_DriveFile>> _query(String q) async {
    final files = <_DriveFile>[];
    String? pageToken;
    do {
      final response = await _send(
        'GET',
        Uri.parse('$_api/files').replace(
          queryParameters: {
            'q': '$q and trashed=false',
            'spaces': 'appDataFolder',
            'fields': 'nextPageToken,files(id,name)',
            // Second+ page fetch: the prefix-only FakeHttp can't return two
            // different bodies for the same URL, and mailboxes are ≤~20 files
            // (compaction) so a real second page never occurs in practice.
            'pageToken': ?pageToken, // coverage:ignore-line
          },
        ),
      );
      _check(response, 'query');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      for (final f in json['files'] as List<dynamic>) {
        final map = f as Map<String, dynamic>;
        files.add(_DriveFile(map['id'] as String, map['name'] as String));
      }
      pageToken = json['nextPageToken'] as String?;
    } while (pageToken != null);
    return files;
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
      throw HttpException('Google Drive $op failed: HTTP ${response.status}');
    }
  }
}

class _DriveFile {
  const _DriveFile(this.id, this.name);

  final String id;
  final String name;
}
