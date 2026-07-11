import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:window_manager/window_manager.dart';

import '../core/platform_info.dart';

/// Bumped once per capture request from a platform trigger; the todo list
/// screen listens and opens the quick-add dialog (TASKS.md 6.14).
final quickCaptureRequestsProvider = StateProvider<int>((_) => 0);

/// Platform entry points that funnel straight into quick add:
/// - desktop: a system-wide hotkey (Ctrl/Cmd+Shift+K) that raises the
///   window and opens the dialog,
/// - Android: a long-press launcher shortcut,
/// - iOS: a Home-screen quick action.
///
/// Every platform call is defensive: a headless test runner, a Linux
/// session without keybinder, or a stripped-down launcher must never break
/// app start over a convenience shortcut.
class QuickCaptureService {
  QuickCaptureService(this.onCapture);

  /// What every platform trigger funnels into; public so tests can drive
  /// the wiring without platform channels.
  final void Function() onCapture;
  HotKey? _hotKey;

  static const shortcutType = 'quick_add';

  Future<void> start() async {
    if (platformIsWeb) return;
    if (platformIsAndroid || platformIsIOS) {
      await _startMobile();
    } else {
      await _startDesktop();
    }
  }

  Future<void> _startMobile() async {
    const actions = QuickActions();
    try {
      await actions.initialize((type) {
        if (type == shortcutType) onCapture();
      });
      await actions.setShortcutItems(const [
        ShortcutItem(type: shortcutType, localizedTitle: 'Add todo'),
      ]);
    } on Exception {
      // Launcher shortcuts unavailable — nothing to degrade.
    }
  }

  Future<void> _startDesktop() async {
    final hotKey = HotKey(
      key: PhysicalKeyboardKey.keyK,
      modifiers: [
        platformIsMacOS ? HotKeyModifier.meta : HotKeyModifier.control,
        HotKeyModifier.shift,
      ],
      scope: HotKeyScope.system,
    );
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) async {
          try {
            // The whole point of a *global* hotkey: surface the window
            // first, then open quick add.
            await windowManager.show();
            await windowManager.focus();
          } on Exception {
            // Window raise is best-effort; still open the dialog.
          }
          onCapture();
        },
      );
      _hotKey = hotKey;
    } on Exception {
      // No global-hotkey support in this session (e.g. missing keybinder
      // on Linux, or a headless CI run) — the in-app Ctrl/Cmd+N remains.
    }
  }

  Future<void> stop() async {
    final hotKey = _hotKey;
    _hotKey = null;
    if (hotKey != null) {
      try {
        await hotKeyManager.unregister(hotKey);
      } on Exception {
        // Already gone.
      }
    }
  }
}

final quickCaptureServiceProvider = Provider<QuickCaptureService>(
  (ref) => QuickCaptureService(
    () => ref.read(quickCaptureRequestsProvider.notifier).state++,
  ),
);
