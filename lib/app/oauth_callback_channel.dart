import 'dart:async';

import 'package:flutter/services.dart';

/// Receives OAuth custom-scheme redirects (`knot://oauth?...`, plus the
/// Google reversed-client-id scheme) from the platform. Swift side lives
/// in ios/Runner/AppDelegate.swift: `application(_:open:options:)`
/// forwards any matching URL here. Same pattern as the cloud-folder
/// channel — platform glue behind a Dart seam (CLAUDE.md conventions).
class OAuthCallbackChannel {
  OAuthCallbackChannel._() {
    channel.setMethodCallHandler(_onCall);
  }

  static final instance = OAuthCallbackChannel._();

  static const channel = MethodChannel('com.sai.knot/oauth_callback');

  Completer<Uri>? _pending;

  /// Completes with the next redirect the OS delivers. One waiter at a
  /// time: starting a new sign-in abandons the previous wait.
  Future<Uri> waitForRedirect({Duration timeout = const Duration(minutes: 5)}) {
    _pending?.completeError(StateError('Superseded by a newer sign-in'));
    final completer = Completer<Uri>();
    _pending = completer;
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        if (identical(_pending, completer)) _pending = null;
        throw TimeoutException('Sign-in was not completed');
      },
    );
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'redirect') return;
    final pending = _pending;
    _pending = null;
    final url = Uri.tryParse(call.arguments as String? ?? '');
    if (pending == null || pending.isCompleted || url == null) return;
    pending.complete(url);
  }
}
