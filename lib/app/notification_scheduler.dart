import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/alarm_planner.dart';
import '../core/clock.dart';
import '../core/platform_info.dart';
import '../core/snooze_presets.dart';

/// What a notification action reports back to the app.
typedef AlarmActionHandler =
    void Function(String todoId, int occurrenceMs, String action);

/// AlarmScheduler on flutter_local_notifications (TASKS.md 2.2/2.3/2.7).
///
/// - Android: exact alarms (`SCHEDULE_EXACT_ALARM` requested on enable),
///   boot rescheduling via the plugin's receiver.
/// - iOS/macOS: UNUserNotificationCenter; the planner's cap keeps us
///   under iOS's 64-pending limit, and every replan is the refill.
/// - Linux: the plugin can only show immediately, so an in-app timer
///   chain fires notifications while the app runs (docs/alarms.md — the
///   resident-process variant is 5.1, still open).
class LocalNotificationsScheduler implements AlarmScheduler {
  LocalNotificationsScheduler({
    this.onAction,
    this.clock = const SystemClock(),
  });

  final AlarmActionHandler? onAction;
  final Clock clock;
  final _plugin = FlutterLocalNotificationsPlugin();
  final List<Timer> _linuxTimers = [];
  var _initialized = false;

  static const _dismissAction = 'dismiss';
  static const _syncInfoId = 0x4b4e4f54;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
        tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier),
      );
    } on Exception {
      // Fall back to the package default (UTC) rather than failing boot.
    }
    final darwinCategories = [
      DarwinNotificationCategory(
        'knot_alarm',
        actions: [
          DarwinNotificationAction.plain(_dismissAction, 'Dismiss'),
          // Snooze presets (TASKS.md 6.43): iOS shows the first as a quick
          // action and the rest via long-press/expand.
          for (final preset in SnoozePreset.values)
            DarwinNotificationAction.plain(preset.actionId, preset.label),
        ],
      ),
    ];
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          notificationCategories: darwinCategories,
        ),
        macOS: DarwinInitializationSettings(
          notificationCategories: darwinCategories,
        ),
        linux: const LinuxInitializationSettings(defaultActionName: 'Open'),
      ),
      onDidReceiveNotificationResponse: _handleResponse,
    );
    _initialized = true;
  }

  /// Asks the OS for notification (and Android exact-alarm) permission.
  /// Called when the user enables alarms on this device (2.5).
  Future<bool> ensurePermissions() async {
    await initialize();
    if (platformIsWeb) {
      return false;
    }
    if (platformIsAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notifications = await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      return notifications ?? false;
    }
    if (platformIsIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (platformIsMacOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  @override
  Future<void> replaceAll(List<AlarmInstance> alarms) async {
    await initialize();
    for (final timer in _linuxTimers) {
      timer.cancel();
    }
    _linuxTimers.clear();
    await _plugin.cancelAll();

    if (platformIsLinux) {
      _scheduleLinux(alarms);
      return;
    }
    for (final alarm in alarms) {
      await _plugin.zonedSchedule(
        id: _idFor(alarm),
        title: alarm.title,
        body: _body(alarm),
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
          tz.local,
          alarm.fireAtMs,
        ),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: _payload(alarm),
      );
    }
  }

  void _scheduleLinux(List<AlarmInstance> alarms) {
    final nowMs = clock.now().millisecondsSinceEpoch;
    for (final alarm in alarms) {
      final delay = alarm.fireAtMs - nowMs;
      if (delay < 0) continue;
      _linuxTimers.add(
        Timer(Duration(milliseconds: delay), () {
          _plugin.show(
            id: _idFor(alarm),
            title: alarm.title,
            body: _body(alarm),
            notificationDetails: _details(),
            payload: _payload(alarm),
          );
        }),
      );
    }
  }

  @override
  Future<void> showInfo({required String title, required String body}) async {
    await initialize();
    await _plugin.show(
      id: _syncInfoId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'knot_updates',
          'Updates',
          channelDescription: 'Sync status updates',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
    );
  }

  NotificationDetails _details() => NotificationDetails(
    android: AndroidNotificationDetails(
      'knot_alarms',
      'Alarms',
      channelDescription: 'Todo due-time alarms',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      // Snooze presets (TASKS.md 6.43): Android caps a notification at
      // three action buttons with no overflow, so offer Dismiss plus the
      // two quick offsets deterministically; the wall-clock presets
      // ("This evening"/"Tomorrow") are Darwin-only, where the expanded
      // card lists every category action.
      actions: [
        const AndroidNotificationAction(_dismissAction, 'Dismiss'),
        for (final preset in const [
          SnoozePreset.tenMinutes,
          SnoozePreset.oneHour,
        ])
          AndroidNotificationAction(preset.actionId, preset.label),
      ],
    ),
    iOS: const DarwinNotificationDetails(categoryIdentifier: 'knot_alarm'),
    macOS: const DarwinNotificationDetails(categoryIdentifier: 'knot_alarm'),
    linux: const LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.critical,
    ),
  );

  /// "Due now", plus attribution when the todo is on a shared list and
  /// someone else's edit is what's ringing (TASKS.md 6.51/6.2).
  static String _body(AlarmInstance alarm) => alarm.changedBy == null
      ? 'Due now'
      : 'Due now — changed by ${alarm.changedBy}';

  static String _payload(AlarmInstance alarm) =>
      jsonEncode({'todoId': alarm.todoId, 'occ': alarm.occurrenceMs});

  static int _idFor(AlarmInstance alarm) =>
      Object.hash(alarm.todoId, alarm.occurrenceMs, alarm.fireAtMs) &
      0x7fffffff;

  void _handleResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    final map = jsonDecode(payload) as Map<String, dynamic>;
    onAction?.call(
      map['todoId'] as String,
      map['occ'] as int,
      response.actionId ?? _dismissAction,
    );
  }
}
