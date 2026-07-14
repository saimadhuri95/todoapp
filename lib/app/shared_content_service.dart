import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform_info.dart';
import 'providers.dart';

/// Turns text shared into the app into a todo title (TASKS.md 6.25).
/// Collapses whitespace and keeps the first non-empty line — a shared article
/// often arrives as "Title\nhttps://…"; the URL still lands in the todo via
/// [ingestSharedText] appending it to the notes-free title only when the first
/// line is empty. Returns null for blank shares.
String? sharedTextToTitle(String raw) {
  final lines = raw
      .split(RegExp(r'\r\n|\r|\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return null;
  // Prefer a human title line over a bare URL when both are present.
  final titleLine = lines.firstWhere(
    (l) => !_looksLikeUrl(l),
    orElse: () => lines.first,
  );
  return titleLine.replaceAll(RegExp(r'\s+'), ' ');
}

bool _looksLikeUrl(String s) =>
    s.startsWith('http://') || s.startsWith('https://');

/// Receives text from the OS share sheet and files it as an Inbox todo
/// (TASKS.md 6.25). Android delivers `ACTION_SEND` text over the
/// `com.sai.knot/share` MethodChannel — the launch share via `getInitialShare`
/// and later shares pushed as `shared`. iOS/macOS need a Share Extension
/// target (Xcode), deferred; the channel name and Dart handler are ready for
/// it. A no-op off Android so nothing else is affected.
class SharedContentService {
  SharedContentService(this._ref, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.sai.knot/share');

  final Ref _ref;
  final MethodChannel _channel;

  Future<void> start() async {
    if (!platformIsAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared' && call.arguments is String) {
        await ingestSharedText(call.arguments as String);
      }
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialShare');
      if (initial != null) await ingestSharedText(initial);
    } on PlatformException {
      // No share to consume, or the channel isn't wired in this session.
    }
  }

  /// Creates an Inbox todo from [raw]. Public for tests; also the single path
  /// both the launch share and subsequent shares funnel through.
  Future<void> ingestSharedText(String raw) async {
    final title = sharedTextToTitle(raw);
    if (title == null) return;
    await _ref.read(todoRepositoryProvider).create(title: title);
  }

  Future<void> stop() async {
    if (!platformIsAndroid) return;
    _channel.setMethodCallHandler(null);
  }
}

final sharedContentServiceProvider = Provider<SharedContentService>(
  SharedContentService.new,
);
