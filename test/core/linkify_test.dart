import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/linkify.dart';

void main() {
  group('linkify', () {
    test('plain text yields one non-link segment', () {
      final segments = linkify('buy milk');
      expect(segments, hasLength(1));
      expect(segments.single.text, 'buy milk');
      expect(segments.single.isLink, isFalse);
    });

    test('empty text yields no segments', () {
      expect(linkify(''), isEmpty);
    });

    test('bare URL is a single link segment', () {
      final segments = linkify('https://example.com/a?b=1');
      expect(segments, hasLength(1));
      expect(segments.single.link, Uri.parse('https://example.com/a?b=1'));
    });

    test('URL mid-sentence splits into three segments', () {
      final segments = linkify('see https://example.com for details');
      expect(segments.map((s) => s.text), [
        'see ',
        'https://example.com',
        ' for details',
      ]);
      expect(segments[1].isLink, isTrue);
      expect(segments[0].isLink, isFalse);
    });

    test('segments concatenate back to the input', () {
      const text = 'a https://x.com b http://y.org/z. c';
      expect(linkify(text).map((s) => s.text).join(), text);
    });

    test('trailing sentence punctuation stays out of the URL', () {
      expect(
        linkify(
          'read https://example.com/doc.',
        ).firstWhere((s) => s.isLink).link,
        Uri.parse('https://example.com/doc'),
      );
      expect(
        linkify(
          'really, https://example.com!?',
        ).firstWhere((s) => s.isLink).link,
        Uri.parse('https://example.com'),
      );
    });

    test('wrapping parenthesis is dropped, balanced one kept', () {
      expect(
        linkify(
          '(see https://en.wikipedia.org/wiki/Foo_(bar))',
        ).firstWhere((s) => s.isLink).link,
        Uri.parse('https://en.wikipedia.org/wiki/Foo_(bar)'),
      );
    });

    test('http scheme and uppercase scheme are linked', () {
      expect(linkify('http://example.com').single.isLink, isTrue);
      expect(linkify('HTTPS://example.com').single.isLink, isTrue);
    });

    test('bare domains and other schemes are not linked', () {
      expect(linkify('example.com is nice').single.isLink, isFalse);
      expect(linkify('ftp://example.com').single.isLink, isFalse);
      expect(linkify('mailto:a@b.com').single.isLink, isFalse);
    });

    test('scheme without host is not linked', () {
      expect(linkify('https:// nothing').any((s) => s.isLink), isFalse);
    });
  });

  group('extractLinks', () {
    test('returns URLs in order, deduplicated', () {
      final links = extractLinks(
        'https://a.com then https://b.com then https://a.com again',
      );
      expect(links, [Uri.parse('https://a.com'), Uri.parse('https://b.com')]);
    });

    test('empty when no links', () {
      expect(extractLinks('no links here'), isEmpty);
    });
  });
}
