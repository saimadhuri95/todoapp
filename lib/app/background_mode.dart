import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'background_mode_native.dart'
    if (dart.library.js_interop) 'background_mode_web.dart';

/// "Run in background at login" (TASKS.md 5.2, desktop only): start with
/// the OS session and keep the app — live sync, alarms, cross-device
/// dismissals — running when the window is closed, which then hides
/// instead of quitting. The global hotkey (6.14) or the launcher brings
/// the window back; Settings offers an explicit Quit while enabled.
abstract interface class BackgroundMode {
  /// Registers/unregisters the login item and arms/disarms hide-on-close.
  /// Best-effort: platforms that can't do either just ignore it.
  Future<void> setEnabled(bool enabled);

  /// Really quit, bypassing hide-on-close.
  Future<void> quit();
}

/// Seeded from the `backgroundAtLogin` pref in main(); the settings toggle
/// writes both.
final backgroundAtLoginProvider = StateProvider<bool>((_) => false);

final backgroundModeProvider = Provider<BackgroundMode>(
  (_) => createBackgroundMode(),
);
