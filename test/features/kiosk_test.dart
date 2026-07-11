import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/kiosk/kiosk.dart';
import 'package:todoapp/features/kiosk/kiosk_screen.dart';

class FakeKioskPower implements KioskPower {
  final controller = StreamController<bool>.broadcast();
  final keepAwakeCalls = <bool>[];

  @override
  Stream<bool> poweredChanges() => controller.stream;

  @override
  Future<void> setKeepAwake(bool enabled) async {
    keepAwakeCalls.add(enabled);
  }
}

void main() {
  group('burnInShift', () {
    test('cycles through distinct small offsets and repeats', () {
      final ring = [for (var m = 0; m < 8; m++) burnInShift(m)];
      expect(ring.toSet(), hasLength(8));
      for (final offset in ring) {
        expect(offset.distance, lessThanOrEqualTo(8));
        expect(offset.distance, greaterThan(0));
      }
      expect(burnInShift(8), burnInShift(0)); // period 8
      expect(burnInShift(13), burnInShift(5));
    });
  });

  group('kioskDim', () {
    test('dims at night, full brightness during the day', () {
      expect(kioskDim(12), 1.0);
      expect(kioskDim(21), 1.0);
      expect(kioskDim(22), lessThan(1.0));
      expect(kioskDim(2), lessThan(1.0));
      expect(kioskDim(5), lessThan(1.0));
      expect(kioskDim(6), 1.0);
    });
  });

  group('kioskKeepAwake', () {
    test('holds the screen whenever not discharging', () {
      expect(kioskKeepAwake(BatteryState.charging), isTrue);
      expect(kioskKeepAwake(BatteryState.full), isTrue);
      expect(kioskKeepAwake(BatteryState.connectedNotCharging), isTrue);
      expect(kioskKeepAwake(BatteryState.unknown), isTrue);
      expect(kioskKeepAwake(BatteryState.discharging), isFalse);
    });
  });

  group('kioskTodos', () {
    final now = DateTime(2026, 7, 6, 12);
    Todo todo(String id, {int? dueAtMs, bool pinned = false}) => Todo(
      id: id,
      title: id,
      notes: '',
      dueAtMs: dueAtMs,
      priority: 0,
      tagsJson: '[]',
      sortKey: '',
      alarmOffsetsJson: '[]',
      pinned: pinned,
      deleted: false,
    );

    test('keeps pinned, overdue, and due-today; soonest first', () {
      final tonight = DateTime(2026, 7, 6, 20).millisecondsSinceEpoch;
      final yesterday = DateTime(2026, 7, 5, 9).millisecondsSinceEpoch;
      final tomorrow = DateTime(2026, 7, 7, 9).millisecondsSinceEpoch;
      final picked = kioskTodos([
        todo('undated'),
        todo('tonight', dueAtMs: tonight),
        todo('overdue', dueAtMs: yesterday),
        todo('tomorrow', dueAtMs: tomorrow),
        todo('pinned-undated', pinned: true),
      ], now);

      expect(picked.map((t) => t.id), ['overdue', 'tonight', 'pinned-undated']);
    });

    test('caps the list', () {
      final due = now.millisecondsSinceEpoch;
      final picked = kioskTodos(
        [for (var i = 0; i < 20; i++) todo('t$i', dueAtMs: due + i)],
        now,
        limit: 5,
      );
      expect(picked, hasLength(5));
    });
  });

  group('KioskScreen', () {
    late AppDatabase db;
    late FakeKioskPower power;
    late ProviderContainer container;
    final clock = FixedClock(DateTime(2026, 7, 6, 12, 30));

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      power = FakeKioskPower();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('kiosk-device'),
          clockProvider.overrideWithValue(clock),
          kioskPowerProvider.overrideWithValue(power),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      await power.controller.close();
    });

    Widget host() => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: KioskScreen()),
    );

    testWidgets('shows the clock and today\'s todos, and follows power '
        'changes with the wakelock', (tester) async {
      await container
          .read(todoRepositoryProvider)
          .create(
            title: 'water plants',
            dueAtMs: DateTime(2026, 7, 6, 18).millisecondsSinceEpoch,
          );

      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.text('12:30'), findsOneWidget);
      expect(find.text('water plants'), findsOneWidget);

      power.controller.add(true); // plugged in
      await tester.pump();
      expect(power.keepAwakeCalls, [true]);

      power.controller.add(false); // unplugged
      await tester.pump();
      expect(power.keepAwakeCalls, [true, false]);

      // Leaving the screen always releases the wakelock.
      await tester.pumpWidget(const SizedBox());
      expect(power.keepAwakeCalls.last, isFalse);
    });
  });
}
