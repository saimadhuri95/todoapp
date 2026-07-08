import 'key_store.dart';

class FileKeyStore implements KeyStore {
  FileKeyStore(Object _);

  final _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}
