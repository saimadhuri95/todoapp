import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'export_service.dart';
import 'sync/pairing_crypto.dart';

/// Passphrase-encrypted backup/restore file (TASKS.md 6.41, R11.3).
///
/// Wraps [ExportService.exportJson] in an authenticated-encryption envelope
/// so a user can keep an offline snapshot that is safe to store anywhere.
/// A key is derived from the passphrase with PBKDF2-HMAC-SHA256 and the
/// payload is sealed with XChaCha20-Poly1305, reusing [PairingCrypto.seal]
/// and [PairingCrypto.open].
///
/// This is a *backup*, not a transport. Unlike the sync mailbox — which is a
/// live, self-healing replication channel — a backup is a point-in-time file
/// the user restores by hand. See docs/sync.md.
class BackupService {
  BackupService({required this.export, this.iterations = 210000});

  final ExportService export;

  /// PBKDF2 work factor. Defaults to the OWASP recommendation for
  /// HMAC-SHA256; overridable so tests aren't slowed by the pure-Dart KDF.
  /// The value used is recorded in each file so restore stays correct even
  /// if this default changes later.
  final int iterations;

  static const String _magic = 'knot-backup';
  static const int formatVersion = 1;
  static const int _saltLength = 16;

  /// Encrypts the current data as a JSON envelope string. The passphrase is
  /// never written — only a random salt, the work factor, and the sealed
  /// payload are.
  Future<String> createBackup(String passphrase) async {
    if (passphrase.isEmpty) {
      throw const FormatException('Passphrase must not be empty');
    }
    final plaintext = utf8.encode(await export.exportJson());
    final salt = _randomBytes(_saltLength);
    final key = await _deriveKey(passphrase, salt, iterations);
    final sealed = await PairingCrypto.seal(plaintext, key);
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'knot',
      'kind': _magic,
      'v': formatVersion,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'payload': base64Encode(sealed),
    });
  }

  /// Decrypts a backup envelope and imports it, returning (lists, todos).
  /// Throws [FormatException] on a file that isn't a Knot backup, and
  /// [BackupPassphraseError] when the passphrase is wrong or the file has
  /// been tampered with (the two are indistinguishable by design).
  Future<(int, int)> restoreBackup(
    String fileContent,
    String passphrase,
  ) async {
    final Map<String, dynamic> env;
    try {
      env = jsonDecode(fileContent) as Map<String, dynamic>;
    } on FormatException {
      throw const FormatException('Not a valid backup file');
    } on TypeError {
      throw const FormatException('Not a valid backup file');
    }
    if (env['kind'] != _magic || env['app'] != 'knot') {
      throw const FormatException('Not a Knot backup file');
    }
    if (env['v'] != formatVersion) {
      throw FormatException('Unsupported backup version: ${env['v']}');
    }
    final salt = base64Decode(env['salt'] as String);
    final sealed = base64Decode(env['payload'] as String);
    final storedIterations = env['iterations'] as int? ?? iterations;
    final key = await _deriveKey(passphrase, salt, storedIterations);
    final List<int> plaintext;
    try {
      plaintext = await PairingCrypto.open(sealed, key);
    } on SecretBoxAuthenticationError {
      throw const BackupPassphraseError();
    }
    return export.importJson(utf8.decode(plaintext));
  }

  Future<SecretKey> _deriveKey(String passphrase, List<int> salt, int rounds) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: rounds,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
  }

  static Uint8List _randomBytes(int n) {
    final rng = Random.secure();
    return Uint8List.fromList([for (var i = 0; i < n; i++) rng.nextInt(256)]);
  }
}

/// Thrown when a backup can't be decrypted — a wrong passphrase or a
/// corrupted/tampered file. Authenticated encryption can't tell these apart,
/// so both surface as the same error.
class BackupPassphraseError implements Exception {
  const BackupPassphraseError();

  @override
  String toString() => 'Wrong passphrase or corrupted backup';
}
