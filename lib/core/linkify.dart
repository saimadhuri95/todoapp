/// Splits free text into plain and link segments (TASKS.md 6.4, R2.1).
///
/// Only explicit http/https URLs are linked — no markup, no bare-domain
/// guessing. Pure Dart so it's unit-testable; rendering lives in
/// `features/todos/linkified_text.dart`.
library;

class TextSegment {
  const TextSegment(this.text, [this.link]);

  final String text;

  /// Non-null when this segment is a tappable URL.
  final Uri? link;

  bool get isLink => link != null;
}

final _urlPattern = RegExp(r'https?://[^\s<>]+', caseSensitive: false);

/// Punctuation that ends a sentence around a URL rather than belonging to it.
const _trailing = ['.', ',', ';', ':', '!', '?', "'", '"', '’', '”'];

/// Splits [text] into segments; concatenating `segment.text` reproduces the
/// input exactly.
List<TextSegment> linkify(String text) {
  final segments = <TextSegment>[];
  var cursor = 0;
  for (final match in _urlPattern.allMatches(text)) {
    final url = _trimTrailing(match.group(0)!);
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) continue;
    if (match.start > cursor) {
      segments.add(TextSegment(text.substring(cursor, match.start)));
    }
    segments.add(TextSegment(url, uri));
    cursor = match.start + url.length;
  }
  if (cursor < text.length) segments.add(TextSegment(text.substring(cursor)));
  return segments;
}

/// URLs found in [text], deduplicated in order of appearance.
List<Uri> extractLinks(String text) {
  final seen = <String>{};
  return [
    for (final s in linkify(text))
      if (s.isLink && seen.add(s.link.toString())) s.link!,
  ];
}

String _trimTrailing(String url) {
  var end = url.length;
  while (end > 0) {
    final ch = url[end - 1];
    if (_trailing.contains(ch)) {
      end--;
      continue;
    }
    // Closing brackets stay only while a matching opener is inside the URL —
    // keeps "…/Foo_(bar)" intact but drops the ")" of "(see https://x.com)".
    const pairs = {')': '(', ']': '[', '}': '{'};
    final opener = pairs[ch];
    if (opener != null) {
      final body = url.substring(0, end);
      if (_count(body, opener) < _count(body, ch)) {
        end--;
        continue;
      }
    }
    break;
  }
  return url.substring(0, end);
}

int _count(String s, String ch) => s.length - s.replaceAll(ch, '').length;
