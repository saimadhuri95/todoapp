const _alphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
const _base = 62;
const _spacing = 4096;
const _width = 8;

/// A lexicographically sortable key with gaps between adjacent positions.
///
/// This is intentionally a string, not an integer index: peers can insert
/// between existing keys without shifting every row, and ties still converge
/// by the caller sorting secondarily on the stable row id.
String spacedOrderKey(int index) {
  if (index < 0) {
    throw ArgumentError.value(index, 'index', 'Must be non-negative.');
  }
  return _encode((index + 1) * _spacing).padLeft(_width, _alphabet[0]);
}

/// Returns a key that sorts strictly between [lower] and [upper].
///
/// Either bound may be null. When two devices pick the same gap concurrently
/// they may mint the same key; callers should sort by `(sortKey, rowId)` so the
/// merged order remains deterministic without integer indexes.
String orderKeyBetween(String? lower, String? upper) {
  final lo = _clean(lower);
  final hi = _clean(upper);
  if (lo != null && hi != null && lo.compareTo(hi) >= 0) {
    throw ArgumentError('lower must sort before upper.');
  }

  final prefix = StringBuffer();
  var position = 0;
  while (true) {
    final lowDigit = position < (lo?.length ?? 0) ? _digit(lo![position]) : -1;
    final highDigit = position < (hi?.length ?? 0)
        ? _digit(hi![position])
        : _base;

    if (highDigit - lowDigit > 1) {
      return '${prefix.toString()}${_alphabet[(lowDigit + highDigit) ~/ 2]}';
    }

    prefix.write(position < (lo?.length ?? 0) ? lo![position] : _alphabet[0]);
    position++;
  }
}

String? _clean(String? key) {
  final value = key?.trim();
  return value == null || value.isEmpty ? null : value;
}

int _digit(String char) {
  final value = _alphabet.indexOf(char);
  if (value < 0) throw ArgumentError('Invalid order key character: $char');
  return value;
}

String _encode(int value) {
  if (value == 0) return _alphabet[0];
  final buffer = StringBuffer();
  var rest = value;
  while (rest > 0) {
    buffer.write(_alphabet[rest % _base]);
    rest ~/= _base;
  }
  return buffer.toString().split('').reversed.join();
}
