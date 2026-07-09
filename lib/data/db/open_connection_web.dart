import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

QueryExecutor openConnectionImpl() => LazyDatabase(() async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final fileSystem = await IndexedDbFileSystem.open(dbName: 'todoapp');
  sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);

  return WasmDatabase(
    sqlite3: sqlite,
    path: '/todoapp.sqlite',
    fileSystem: fileSystem,
  );
});
