import 'dart:convert';
import 'dart:io';

import 'key_store.dart';

/// JSON file in the app's private container (TASKS.md 4.17 fallback).
///
/// Used when the platform keychain is unavailable - on macOS, keychain
/// access needs the Keychain Sharing capability, which is a restricted
/// entitlement that ad-hoc-signed local builds cannot carry. The file lives
/// inside the sandboxed app container and never syncs (invariant 3 covers
/// data leaving the device); still, the keychain is preferred, so flip the
/// capability on once real signing exists (docs/packaging.md).
class FileKeyStore implements KeyStore {
  FileKeyStore(this._directory);

  /// Deferred so the data layer stays free of path_provider; providers
  /// pass `getApplicationSupportDirectory`.
  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File('${dir.path}/key_store.json');
  }

  @override
  Future<String?> read(String key) async {
    final file = await _file();
    if (!await file.exists()) return null;
    final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return map[key] as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    final file = await _file();
    final map = await file.exists()
        ? jsonDecode(await file.readAsString()) as Map<String, dynamic>
        : <String, dynamic>{};
    map[key] = value;
    await file.writeAsString(jsonEncode(map), flush: true);
  }
}
