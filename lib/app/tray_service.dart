import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/platform_info.dart';
import '../data/db/database.dart';
import 'providers.dart';
import 'quick_capture.dart';

/// Active, top-level todos due on or before the end of today (overdue folds
/// in, matching the "Today" list section). Pure so the tray label is testable
/// without a windowing environment.
int dueTodayCount(List<Todo> todos, DateTime now) {
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
  final cutoff = startOfTomorrow.millisecondsSinceEpoch;
  var count = 0;
  for (final todo in todos) {
    if (todo.deleted || todo.completedAtMs != null || todo.parentId != null) {
      continue;
    }
    final due = todo.dueAtMs;
    if (due != null && due < cutoff) count++;
  }
  return count;
}

/// The tray tooltip/title text for [dueToday] items.
String trayTooltip(int dueToday) =>
    dueToday == 0 ? 'Knot' : 'Knot — $dueToday due today';

/// Desktop system-tray integration (TASKS.md 6.52 desktop tray, 5.1 Linux
/// tray): a menu-bar/taskbar icon whose tooltip shows today's count and whose
/// menu offers quick-add, show, and quit. Entirely a no-op off desktop and
/// best-effort everywhere (a headless CI session has no tray), so it never
/// blocks startup.
class TrayService with TrayListener {
  TrayService(this._ref);

  final Ref _ref;
  StreamSubscription<void>? _dbSub;
  Timer? _debounce;
  var _started = false;

  static const _quickAddKey = 'quick_add';
  static const _showKey = 'show';
  static const _quitKey = 'quit';

  // Windows needs the .ico; macOS/Linux take the .png.
  static String get _iconPath => platformIsWindows
      ? 'assets/tray/tray_icon.ico'
      : 'assets/tray/tray_icon.png';

  Future<void> start() async {
    if (!platformIsDesktop) return;
    try {
      await trayManager.setIcon(_iconPath);
      trayManager.addListener(this);
      await _refreshMenu();
      await _refreshTooltip();
      _dbSub = _ref.read(databaseProvider).tableUpdates().listen((_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 1), _refreshTooltip);
      });
      _started = true;
    } on Exception {
      // No tray in this session (headless CI, unsupported desktop env).
    }
  }

  Future<void> _refreshMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: _quickAddKey, label: 'Quick add todo'),
          MenuItem(key: _showKey, label: 'Show Knot'),
          MenuItem.separator(),
          MenuItem(key: _quitKey, label: 'Quit Knot'),
        ],
      ),
    );
  }

  Future<void> _refreshTooltip() async {
    if (!platformIsDesktop) return;
    try {
      final todos =
          await (_ref.read(databaseProvider).todos.select()..where(
                (t) => t.deleted.equals(false) & t.completedAtMs.isNull(),
              ))
              .get();
      final count = dueTodayCount(todos, _ref.read(clockProvider).now());
      await trayManager.setToolTip(trayTooltip(count));
    } on Exception {
      // Tooltip is cosmetic; never surface a failure.
    }
  }

  @override
  void onTrayIconMouseDown() => unawaited(_showWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _quickAddKey:
        unawaited(_quickAdd());
      case _showKey:
        unawaited(_showWindow());
      case _quitKey:
        unawaited(_quit());
    }
  }

  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } on Exception {
      // Best-effort.
    }
  }

  Future<void> _quickAdd() async {
    await _showWindow();
    // Reuses the quick-capture request channel the global hotkey uses.
    _ref.read(quickCaptureRequestsProvider.notifier).state++;
  }

  Future<void> _quit() async {
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } on Exception {
      // If the window is already gone there is nothing to do.
    }
  }

  Future<void> stop() async {
    _debounce?.cancel();
    await _dbSub?.cancel();
    _dbSub = null;
    if (!_started) return;
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } on Exception {
      // Already gone.
    }
    _started = false;
  }
}

final trayServiceProvider = Provider<TrayService>(TrayService.new);
