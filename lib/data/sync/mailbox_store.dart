import 'dart:io';

/// Storage backend contract for [MailboxTransport]. The mailbox protocol
/// (outbox-per-device, sortable changeset files, `vector.bin` markers) is
/// storage-agnostic; this seam lets the same protocol run over
///
/// - a locally replicated cloud-drive folder ([FolderMailboxStore] —
///   desktop pickers, iCloud Drive container), or
/// - a storage provider's REST API (Dropbox/Google Drive/OneDrive on
///   iPhone, where those providers expose no filesystem folder — see
///   `lib/data/cloud/`).
///
/// Implementations deal in raw bytes and names only: everything stored is
/// already XChaCha20-Poly1305 ciphertext (CLAUDE.md invariant 3), so a
/// store never needs — or gets — plaintext. Network/IO failures should
/// surface as [IOException]s; the sync orchestrator treats them as soft
/// errors and retries next round.
abstract interface class MailboxStore {
  /// Top-level outbox directory names (device ids), own outbox included.
  /// Empty when the mailbox doesn't exist yet.
  Future<List<String>> listDeviceDirs();

  /// File names inside one outbox. Empty when the outbox doesn't exist.
  Future<List<String>> listFiles(String deviceDir);

  /// File contents, or null when it doesn't exist.
  Future<List<int>?> read(String deviceDir, String name);

  /// Writes (creating the outbox on demand), replacing any existing file.
  Future<void> write(String deviceDir, String name, List<int> bytes);

  /// Deletes one file; missing files are ignored.
  Future<void> delete(String deviceDir, String name);

  /// Deletes the whole mailbox (device revocation — the group key was
  /// rotated, so every file is sealed with a burned key).
  Future<void> wipeAll();
}

/// [MailboxStore] over a plain directory that the user's own cloud drive
/// replicates (the original transport backing, TASKS.md 3.10/3.12).
class FolderMailboxStore implements MailboxStore {
  FolderMailboxStore(this.root);

  final Directory root;

  Directory _dir(String deviceDir) => Directory('${root.path}/$deviceDir');

  @override
  Future<List<String>> listDeviceDirs() async {
    if (!root.existsSync()) return const [];
    return root
        .listSync()
        .whereType<Directory>()
        .map((d) => d.path.split(Platform.pathSeparator).last)
        .toList();
  }

  @override
  Future<List<String>> listFiles(String deviceDir) async {
    final dir = _dir(deviceDir);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split(Platform.pathSeparator).last)
        .toList();
  }

  @override
  Future<List<int>?> read(String deviceDir, String name) async {
    final file = File('${_dir(deviceDir).path}/$name');
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(String deviceDir, String name, List<int> bytes) async {
    final dir = _dir(deviceDir);
    await dir.create(recursive: true);
    await File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete(String deviceDir, String name) async {
    final file = File('${_dir(deviceDir).path}/$name');
    if (file.existsSync()) await file.delete();
  }

  @override
  Future<void> wipeAll() async {
    if (root.existsSync()) await root.delete(recursive: true);
  }
}
