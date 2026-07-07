import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'changeset.dart';
import 'pairing_crypto.dart';
import 'sync_engine.dart';

/// LAN peer-to-peer transport (TASKS.md 3.9): one TCP session fully syncs
/// two devices in both directions.
///
/// Wire format: length-prefixed frames, each frame an XChaCha20-Poly1305
/// box under the group key. Knowing the group key *is* the authentication —
/// a stranger's frames fail AEAD and the session is dropped without reply.
///
///   client → hello   {v, id, vector}
///   server → reply   {v, id, vector, changeset}   (delta for client)
///   client → deltas  {changeset}                  (delta for server)
///
/// mDNS advertise/browse (service `_todosync._tcp`) is wired separately —
/// this layer only needs a connected [Socket], which is what makes it
/// loopback-testable.
class LanSync {
  static const protocolVersion = 1;

  /// Serves one incoming connection; returns writes applied locally.
  static Future<int> serve({
    required Socket socket,
    required SyncEngine engine,
    required SecretKey groupKey,
    Future<void> Function()? onVisibleTodosChanged,
  }) async {
    final io = _SecureFrameIO(socket, groupKey);
    try {
      final hello = await io.readJson();
      if (hello == null || hello['v'] != protocolVersion) return 0;
      final clientVector = (hello['vector'] as Map<String, dynamic>)
          .cast<String, String>();

      await io.writeJson({
        'v': protocolVersion,
        'id': engine.deviceId,
        'vector': await engine.versionVector(),
        'changeset': (await engine.changesFor(clientVector)).encode(),
      });

      final deltas = await io.readJson();
      if (deltas == null) return 0;
      final visibleChangesBefore = engine.visibleTodoChanges;
      final applied = await engine.apply(
        Changeset.decode(deltas['changeset'] as String),
      );
      if (applied > 0 && engine.visibleTodoChanges != visibleChangesBefore) {
        await onVisibleTodosChanged?.call();
      }
      return applied;
    } on SecretBoxAuthenticationError {
      return 0; // Not paired with us: drop silently.
    } on FormatException {
      return 0;
    } finally {
      await socket.flush();
      socket.destroy();
    }
  }

  /// Runs the client side over a connected socket; returns writes applied
  /// locally.
  static Future<int> sync({
    required Socket socket,
    required SyncEngine engine,
    required SecretKey groupKey,
  }) async {
    final io = _SecureFrameIO(socket, groupKey);
    try {
      await io.writeJson({
        'v': protocolVersion,
        'id': engine.deviceId,
        'vector': await engine.versionVector(),
      });

      final reply = await io.readJson();
      if (reply == null || reply['v'] != protocolVersion) return 0;
      final applied = await engine.apply(
        Changeset.decode(reply['changeset'] as String),
      );

      final serverVector = (reply['vector'] as Map<String, dynamic>)
          .cast<String, String>();
      await io.writeJson({
        'changeset': (await engine.changesFor(serverVector)).encode(),
      });
      await socket.flush();
      return applied;
    } on SecretBoxAuthenticationError {
      return 0;
    } on FormatException {
      return 0;
    } finally {
      socket.destroy();
    }
  }
}

/// Accepts LAN sync connections. Discovery/advertising is layered on top.
class LanSyncServer {
  LanSyncServer({
    required this.engine,
    required this.groupKey,
    this.onVisibleTodosChanged,
  });

  final SyncEngine engine;
  final SecretKey groupKey;
  final Future<void> Function()? onVisibleTodosChanged;
  ServerSocket? _server;

  int? get port => _server?.port;

  Future<int> start({int port = 0}) async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen((socket) {
      // Sessions are independent; failures must not kill the listener.
      LanSync.serve(
        socket: socket,
        engine: engine,
        groupKey: groupKey,
        onVisibleTodosChanged: onVisibleTodosChanged,
      ).ignore();
    });
    return server.port;
  }

  Future<void> stop() async => _server?.close();
}

/// Length-prefixed frames (u32 BE), each sealed with the group key.
class _SecureFrameIO {
  _SecureFrameIO(Socket socket, this._key)
    : _socket = socket,
      _incoming = StreamIterator(socket);

  final Socket _socket;
  final SecretKey _key;
  final StreamIterator<Uint8List> _incoming;
  final _buffer = BytesBuilder();

  Future<void> writeJson(Map<String, Object?> message) async {
    final sealed = await PairingCrypto.seal(
      utf8.encode(jsonEncode(message)),
      _key,
    );
    final header = ByteData(4)..setUint32(0, sealed.length);
    _socket.add(header.buffer.asUint8List());
    _socket.add(sealed);
  }

  /// Null on clean end-of-stream. Throws [SecretBoxAuthenticationError]
  /// for frames not sealed with our key.
  Future<Map<String, dynamic>?> readJson() async {
    final frame = await _readFrame();
    if (frame == null) return null;
    final clear = await PairingCrypto.open(frame, _key);
    return (jsonDecode(utf8.decode(clear)) as Map<String, dynamic>);
  }

  Future<Uint8List?> _readFrame() async {
    while (true) {
      final bytes = _buffer.toBytes();
      if (bytes.length >= 4) {
        final length = ByteData.sublistView(bytes, 0, 4).getUint32(0);
        if (bytes.length >= 4 + length) {
          _buffer.clear();
          _buffer.add(bytes.sublist(4 + length));
          return Uint8List.sublistView(bytes, 4, 4 + length);
        }
      }
      if (!await _incoming.moveNext()) return null;
      _buffer.add(_incoming.current);
    }
  }
}
