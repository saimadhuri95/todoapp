/// Storage backend contract for mailbox sync.
///
/// Browser builds currently do not expose a shared filesystem-backed mailbox,
/// but the interface remains available so common providers compile.
abstract interface class MailboxStore {
  Future<List<String>> listDeviceDirs();
  Future<List<String>> listFiles(String deviceDir);
  Future<List<int>?> read(String deviceDir, String name);
  Future<void> write(String deviceDir, String name, List<int> bytes);
  Future<void> delete(String deviceDir, String name);
  Future<void> wipeAll();
}
