import 'dart:io';

Future<void> resetDirectory(String path) async {
  final dir = Directory(path);
  if (dir.existsSync()) {
    await dir.delete(recursive: true);
    await dir.create(recursive: true);
  }
}
