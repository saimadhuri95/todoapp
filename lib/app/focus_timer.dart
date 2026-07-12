import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform_info.dart';
import 'alarm_service.dart';
import 'providers.dart';

/// A running per-task focus session (TASKS.md 6.11): title kept alongside
/// the id so the end notification doesn't need a DB round trip after the
/// todo may have changed.
class FocusSession {
  const FocusSession({
    required this.todoId,
    required this.todoTitle,
    required this.endAt,
  });

  final String todoId;
  final String todoTitle;
  final DateTime endAt;
}

/// One focus session app-wide at a time — starting a new one replaces
/// whatever was running. Purely ephemeral/local: not synced, not persisted
/// across restarts (TASKS.md 6.11).
class FocusTimerController extends StateNotifier<FocusSession?> {
  FocusTimerController(this._ref) : super(null);

  final Ref _ref;
  Timer? _timer;

  void start({
    required String todoId,
    required String todoTitle,
    required Duration duration,
  }) {
    _timer?.cancel();
    final now = _ref.read(clockProvider).now();
    state = FocusSession(
      todoId: todoId,
      todoTitle: todoTitle,
      endAt: now.add(duration),
    );
    _timer = Timer(duration, _finish);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }

  Future<void> _finish() async {
    final session = state;
    state = null;
    if (session == null) return;
    // End notification (TASKS.md 6.11): mobile always pings; desktop stays
    // behind the alarms opt-in like every other alarm on this device.
    if (platformIsDesktop && !_ref.read(alarmsEnabledProvider)) return;
    await _ref
        .read(alarmSchedulerProvider)
        .showInfo(title: 'Focus session done', body: session.todoTitle);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final focusTimerProvider =
    StateNotifierProvider<FocusTimerController, FocusSession?>(
      FocusTimerController.new,
    );

/// Offered focus-session lengths (classic Pomodoro-ish set).
const kFocusDurationChoices = [
  Duration(minutes: 15),
  Duration(minutes: 25),
  Duration(minutes: 45),
];
