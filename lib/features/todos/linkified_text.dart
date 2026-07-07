import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/linkify.dart';

/// Opens a URL outside the app; injectable so widget tests can capture the
/// tap instead of launching a browser.
final urlOpenerProvider = Provider<void Function(Uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// [Text] drop-in that renders http/https URLs as tappable links
/// (TASKS.md 6.4). Tapping a link opens it; taps on plain text still reach
/// enclosing widgets (e.g. the todo tile's onTap).
class LinkifiedText extends ConsumerStatefulWidget {
  const LinkifiedText(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  ConsumerState<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends ConsumerState<LinkifiedText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final segments = linkify(widget.text);
    if (!segments.any((s) => s.isLink)) {
      return Text(widget.text, style: widget.style);
    }
    final open = ref.read(urlOpenerProvider);
    final linkStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final segment in segments)
            if (segment.isLink)
              TextSpan(
                text: segment.text,
                style: linkStyle,
                recognizer: () {
                  final recognizer = TapGestureRecognizer()
                    ..onTap = () => open(segment.link!);
                  _recognizers.add(recognizer);
                  return recognizer;
                }(),
              )
            else
              TextSpan(text: segment.text),
        ],
      ),
    );
  }
}
