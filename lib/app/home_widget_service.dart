import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../core/home_widget_summary.dart';
import '../core/platform_info.dart';
import 'providers.dart';

/// Keeps the home-screen "Today" widget in sync with the database
/// (TASKS.md 6.24): recomputes the summary on any todo change and pushes the
/// rendered strings to the native widget. Android-only for now (the iOS
/// WidgetKit extension is a deferred Xcode target); a no-op elsewhere so it
/// never affects other platforms or tests.
class HomeWidgetService {
  HomeWidgetService(this._ref, {this.debounce = const Duration(seconds: 1)});

  final Ref _ref;
  final Duration debounce;

  StreamSubscription<void>? _sub;
  Timer? _debounceTimer;

  static const androidWidgetName = 'TodayWidgetProvider';

  Future<void> start() async {
    if (!platformIsAndroid) return;
    _sub = _ref.read(databaseProvider).tableUpdates().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, push);
    });
    await push();
  }

  /// Recomputes and pushes the current summary to the widget.
  Future<void> push() async {
    if (!platformIsAndroid) return;
    final db = _ref.read(databaseProvider);
    final todos =
        await (db.todos.select()..where(
              (t) => t.deleted.equals(false) & t.completedAtMs.isNull(),
            ))
            .get();
    final summary = homeWidgetSummary(todos, _ref.read(clockProvider).now());
    try {
      await HomeWidget.saveWidgetData<String>(
        'headline',
        homeWidgetHeadline(summary),
      );
      await HomeWidget.saveWidgetData<String>('body', homeWidgetBody(summary));
      await HomeWidget.updateWidget(androidName: androidWidgetName);
    } on Exception {
      // No widget host in this session; the data is saved regardless.
    }
  }

  void stop() {
    _sub?.cancel();
    _debounceTimer?.cancel();
  }
}

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  HomeWidgetService.new,
);
