import 'dart:math' as math;

import 'clock.dart';

/// Hybrid logical clock timestamp: wall-clock millis + logical counter +
/// node id (device id). Total order: millis, then counter, then nodeId.
///
/// The encoded string form (`paddedMillis:hexCounter:nodeId`) sorts
/// lexicographically in the same order as [compareTo], so HLCs can be
/// compared directly in SQL.
class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.counter, this.nodeId)
      : assert(millis >= 0),
        assert(counter >= 0 && counter <= maxCounter);

  factory Hlc.zero(String nodeId) => Hlc(0, 0, nodeId);

  factory Hlc.parse(String encoded) {
    final first = encoded.indexOf(':');
    final second = encoded.indexOf(':', first + 1);
    if (first == -1 || second == -1) {
      throw FormatException('Invalid HLC: $encoded');
    }
    return Hlc(
      int.parse(encoded.substring(0, first)),
      int.parse(encoded.substring(first + 1, second), radix: 16),
      encoded.substring(second + 1),
    );
  }

  static const int maxCounter = 0xFFFF;

  final int millis;
  final int counter;
  final String nodeId;

  /// Timestamp for a local event. Monotonic even if the wall clock regressed.
  Hlc send(int wallMs) =>
      wallMs > millis ? Hlc(wallMs, 0, nodeId) : Hlc(millis, counter + 1, nodeId);

  /// Merge a remote timestamp on receipt; result exceeds both local and
  /// remote regardless of wall-clock skew between devices.
  Hlc receive(Hlc remote, int wallMs) {
    if (wallMs > millis && wallMs > remote.millis) {
      return Hlc(wallMs, 0, nodeId);
    }
    if (millis == remote.millis) {
      return Hlc(millis, math.max(counter, remote.counter) + 1, nodeId);
    }
    if (millis > remote.millis) {
      return Hlc(millis, counter + 1, nodeId);
    }
    return Hlc(remote.millis, remote.counter + 1, nodeId);
  }

  String encode() =>
      '${millis.toString().padLeft(15, '0')}:'
      '${counter.toRadixString(16).padLeft(4, '0')}:$nodeId';

  @override
  int compareTo(Hlc other) {
    if (millis != other.millis) return millis.compareTo(other.millis);
    if (counter != other.counter) return counter.compareTo(other.counter);
    return nodeId.compareTo(other.nodeId);
  }

  bool operator <(Hlc other) => compareTo(other) < 0;
  bool operator >(Hlc other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      millis == other.millis &&
      counter == other.counter &&
      nodeId == other.nodeId;

  @override
  int get hashCode => Object.hash(millis, counter, nodeId);

  @override
  String toString() => encode();
}

/// Stateful per-device clock: issues monotonically increasing [Hlc]s for
/// local mutations and folds in remote timestamps during sync.
class HlcClock {
  HlcClock({required String nodeId, required this.clock, Hlc? initial})
      : _last = initial ?? Hlc.zero(nodeId);

  final Clock clock;
  Hlc _last;

  Hlc get last => _last;

  Hlc send() => _last = _last.send(_wallMs());

  Hlc receive(Hlc remote) => _last = _last.receive(remote, _wallMs());

  int _wallMs() => clock.now().millisecondsSinceEpoch;
}
