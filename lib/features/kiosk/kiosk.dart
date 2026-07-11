import 'dart:async';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Pure kiosk-mode policies (TASKS.md 6.38), kept widget-free so they are
/// trivially testable.
///
/// Burn-in-safe pixel shift: walks a small ring of offsets, one step per
/// minute, so static content (the clock especially) never parks on the same
/// pixels of an always-on display. Radius is a handful of logical pixels —
/// invisible at arm's length, enough to spread wear.
Offset burnInShift(int minuteIndex) {
  const positions = 8;
  const radius = 6.0;
  final angle = (minuteIndex % positions) * (2 * math.pi / positions);
  return Offset(radius * math.cos(angle), radius * math.sin(angle));
}

/// Content opacity for the given local hour: full during the day, dimmed
/// through the night — easier on OLED panels and on anyone sleeping nearby.
double kioskDim(int hour) => hour >= 22 || hour < 6 ? 0.35 : 1.0;

/// Keep-screen-on policy: hold the wakelock whenever the device is on
/// external power ("keep-screen-on while charging"). `unknown` and
/// desktop/no-battery states count as powered so a plugged-in wall tablet
/// or a desktop without a battery never sleeps mid-display.
bool kioskKeepAwake(BatteryState state) => state != BatteryState.discharging;

/// Platform seam for the kiosk screen's power handling (screen wakelock +
/// charging detection), so tests can fake both sides.
abstract interface class KioskPower {
  /// Emits the current powered-ness first, then every change.
  Stream<bool> poweredChanges();

  Future<void> setKeepAwake(bool enabled);
}

/// Production implementation on battery_plus + wakelock_plus.
class BatteryWakelockPower implements KioskPower {
  final _battery = Battery();

  @override
  Stream<bool> poweredChanges() async* {
    try {
      yield kioskKeepAwake(await _battery.batteryState);
    } on Exception {
      yield true; // No battery info (some desktops): treat as powered.
    }
    yield* _battery.onBatteryStateChanged.map(kioskKeepAwake);
  }

  @override
  Future<void> setKeepAwake(bool enabled) =>
      enabled ? WakelockPlus.enable() : WakelockPlus.disable();
}
