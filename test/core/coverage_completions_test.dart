import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/alarm_planner.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/cloud_folder.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/core/order_key.dart';
import 'package:todoapp/core/platform_info.dart';
import 'package:todoapp/core/recurrence.dart';
import 'package:todoapp/core/snooze_presets.dart';

/// Covers the small pure-logic leaves the behavioural suites don't reach:
/// no-op/default implementations, trivial accessors, error guards, and the
/// non-UTC calendar branches — so the pure layers hit 100% (not make-work,
/// each still asserts the real contract).
void main() {
  test('NoopAlarmScheduler does nothing and never throws', () async {
    const scheduler = NoopAlarmScheduler();
    await scheduler.replaceAll(const [
      AlarmInstance(todoId: 't', title: 'x', fireAtMs: 1, occurrenceMs: 1),
    ]);
    await scheduler.showInfo(title: 'hi', body: 'there');
  });

  test('SystemClock.now returns a real wall-clock time', () {
    final before = DateTime.now();
    final now = const SystemClock().now();
    final after = DateTime.now();
    expect(now.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
    expect(now.isAfter(after.add(const Duration(seconds: 1))), isFalse);
  });

  test(
    'UnsupportedCloudFolder is the inert default on unsupported hosts',
    () async {
      const folder = UnsupportedCloudFolder();
      expect(folder.isSupported, isFalse);
      expect(await folder.documentsPath(), isNull);
      expect(await folder.createBookmark('/tmp/x'), isNull);
      expect(await folder.resolveBookmark('bookmark'), isNull);
      expect(await folder.shareFolder('/tmp/x'), isFalse);
    },
  );

  group('Hlc / HlcClock leaves', () {
    test('hashCode agrees with == and toString round-trips', () {
      const a = Hlc(1000, 3, 'node');
      const b = Hlc(1000, 3, 'node');
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), a.encode());
      // hashCode differs for a different value (not strictly required, but a
      // sane hash — and it exercises the getter with distinct inputs).
      expect(const Hlc(1000, 4, 'node').hashCode, isNot(a.hashCode));
    });

    test('HlcClock.last reflects the most recent stamp', () {
      final clock = HlcClock(
        nodeId: 'n',
        clock: FixedClock(DateTime.utc(2026)),
      );
      final sent = clock.send();
      expect(clock.last, sent);
    });
  });

  group('order key guards', () {
    test('spacedOrderKey rejects a negative index', () {
      expect(() => spacedOrderKey(-1), throwsArgumentError);
    });

    test('orderKeyBetween rejects lower >= upper', () {
      expect(() => orderKeyBetween('B', 'A'), throwsArgumentError);
      expect(() => orderKeyBetween('A', 'A'), throwsArgumentError);
    });
  });

  test('every SnoozePreset has a distinct label', () {
    final labels = {for (final p in SnoozePreset.values) p.label};
    expect(labels, hasLength(SnoozePreset.values.length));
    expect(SnoozePreset.tenMinutes.label, 'Snooze 10 min');
    expect(SnoozePreset.tomorrow.label, 'Tomorrow');
  });

  test('platform_info getters are all evaluable on the test host', () {
    // Referencing each getter executes its expression regardless of the
    // host's actual OS; exactly one of the OS flags is true.
    final flags = [
      platformIsWeb,
      platformIsAndroid,
      platformIsIOS,
      platformIsLinux,
      platformIsMacOS,
      platformIsWindows,
    ];
    expect(flags.where((f) => f).length, 1);
    expect(platformIsDesktop, isA<bool>());
    expect(platformSupportsIcloud, isA<bool>());
    expect(platformSupportsCameraScanner, isA<bool>());
    expect(platformSupportsVoiceInput, isA<bool>());
    expect(defaultAlarmsEnabled, isA<bool>());
    expect(platformDeviceName, isNotEmpty);
    expect(platformName, isNotEmpty);
    expect(platformPathSeparator, isNotEmpty);
  });

  test('recurrence builds occurrences from a non-UTC (local) anchor', () {
    // A local-time anchor takes the DateTime(...) branch of _at rather than
    // DateTime.utc(...); monthly/yearly must still land on the right day.
    final anchor = DateTime(2026, 1, 15, 9); // local
    final monthly = Recurrence.parse('FREQ=MONTHLY');
    final next = monthly.nextAfter(anchor, anchor: anchor);
    expect(next.isUtc, isFalse);
    expect(next.year, 2026);
    expect(next.month, 2);
    expect(next.day, 15);
    expect(next.hour, 9);

    final yearly = Recurrence.parse('FREQ=YEARLY');
    final nextYear = yearly.nextAfter(anchor, anchor: anchor);
    expect(nextYear.isUtc, isFalse);
    expect(nextYear.year, 2027);
    expect(nextYear.month, 1);
    expect(nextYear.day, 15);
  });

  test('nextFromCompletion works from a non-UTC (local) anchor', () {
    // The completion-anchored ("chore") path has its own local/UTC branch;
    // the behavioural suite only uses UTC anchors, so cover the local one.
    final anchor = DateTime(2026, 6, 1, 8); // local
    final completedAt = DateTime(2026, 7, 6, 15, 30); // local
    final daily = Recurrence.parse('FREQ=DAILY;ANCHOR=COMPLETION');
    final next = daily.nextFromCompletion(completedAt, anchor: anchor);
    expect(next.isUtc, isFalse);
    // interval-1 day after completion's date, at the anchor's time of day.
    expect(next.year, 2026);
    expect(next.month, 7);
    expect(next.day, 7);
    expect(next.hour, 8);
    expect(next.minute, 0);

    // The monthly chore path (clamped) from a local anchor too.
    final monthly = Recurrence.parse('FREQ=MONTHLY;ANCHOR=COMPLETION');
    final nextMonth = monthly.nextFromCompletion(
      DateTime(2026, 1, 31, 12),
      anchor: anchor,
    );
    expect(nextMonth.isUtc, isFalse);
    expect(nextMonth.month, 2);
    expect(nextMonth.day, 28); // Jan 31 + 1 month clamps to Feb 28
  });
}
