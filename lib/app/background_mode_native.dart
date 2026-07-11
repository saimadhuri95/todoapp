import 'dart:io';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../core/platform_info.dart';
import 'background_mode.dart';
import 'login_item.dart';

BackgroundMode createBackgroundMode() => DesktopBackgroundMode();

/// Start-at-login via [LoginItem] (XDG autostart / Run key) on Linux and
/// Windows and the SMAppService channel on sandboxed macOS, plus
/// window_manager prevent-close + hide for "keep running while the window
/// is closed". The `--hidden` launch arg lets the login start come up
/// without flashing a window (handled in main()).
class DesktopBackgroundMode with WindowListener implements BackgroundMode {
  static const _channel = MethodChannel('com.sai.knot/cloud_folder');

  var _listening = false;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (!platformIsDesktop) return;
    try {
      if (platformIsMacOS) {
        await _channel.invokeMethod<bool>('setLoginItem', {'enabled': enabled});
      } else {
        await LoginItem(
          execPath: Platform.resolvedExecutable,
        ).apply(enabled: enabled);
      }
    } on Exception {
      // No autostart facility (pre-13 macOS, sandbox restrictions) —
      // hide-on-close below still works for manually started sessions.
    }
    try {
      if (!_listening) {
        windowManager.addListener(this);
        _listening = true;
      }
      await windowManager.setPreventClose(enabled);
    } on Exception {
      // Headless test/CI session without a real window.
    }
  }

  @override
  Future<void> quit() async {
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } on Exception {
      exit(0); // last resort — the user asked to quit
    }
  }

  @override
  void onWindowClose() async {
    // Only reached while preventClose is armed: hide instead of quitting so
    // sync and alarms keep running (TASKS.md 5.2).
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }
}
