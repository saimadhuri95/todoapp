abstract interface class KeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}
