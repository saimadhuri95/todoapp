import 'dart:convert';

import '../../core/hlc.dart';
import 'lww_applier.dart';

/// Wire format for sync (TASKS.md 3.1): a versioned JSON envelope carrying
/// field-level writes. This is the plaintext layer — encryption (3.7) wraps
/// the encoded bytes; transports (3.9/3.10) move them.
///
/// Values are JSON scalars exactly as stored in SQLite (TEXT/INTEGER/NULL;
/// bools are 0/1 ints), so encode/decode is lossless by construction.
class Changeset {
  const Changeset({required this.deviceId, required this.writes});

  /// The device that *sent* this changeset (not necessarily the origin of
  /// each write — devices relay writes they learned from others).
  final String deviceId;

  final List<FieldWrite> writes;

  static const int schemaVersion = 1;

  String encode() => jsonEncode({
    'v': schemaVersion,
    'device': deviceId,
    'writes': [
      for (final w in writes)
        {
          'e': w.entity,
          'r': w.rowId,
          'f': w.field,
          'val': w.value,
          'h': w.hlc.encode(),
        },
    ],
  });

  factory Changeset.decode(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final version = map['v'];
    if (version != schemaVersion) {
      throw FormatException('Unsupported changeset version: $version');
    }
    return Changeset(
      deviceId: map['device'] as String,
      writes: [
        for (final w
            in (map['writes'] as List<dynamic>).cast<Map<String, dynamic>>())
          FieldWrite(
            entity: w['e'] as String,
            rowId: w['r'] as String,
            field: w['f'] as String,
            value: w['val'] as Object?,
            hlc: Hlc.parse(w['h'] as String),
          ),
      ],
    );
  }
}
