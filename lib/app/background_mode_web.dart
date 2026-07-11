import 'background_mode.dart';

BackgroundMode createBackgroundMode() => WebBackgroundMode();

/// Browsers own the tab lifecycle; background-at-login doesn't apply.
class WebBackgroundMode implements BackgroundMode {
  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> quit() async {}
}
