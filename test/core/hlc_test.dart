import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';

void main() {
  final t0 = DateTime.utc(2026, 7, 5, 12);
  final ms0 = t0.millisecondsSinceEpoch;

  group('Hlc.send', () {
    test('advances to wall clock and resets counter', () {
      const before = Hlc(1000, 7, 'a');
      expect(before.send(2000), const Hlc(2000, 0, 'a'));
    });

    test('increments counter when wall clock has not advanced', () {
      const before = Hlc(1000, 7, 'a');
      expect(before.send(1000), const Hlc(1000, 8, 'a'));
    });

    test('stays monotonic when wall clock regresses', () {
      const before = Hlc(1000, 7, 'a');
      expect(before.send(500), const Hlc(1000, 8, 'a'));
    });
  });

  group('Hlc.receive', () {
    test('wall clock ahead of both: adopts wall, resets counter', () {
      const local = Hlc(1000, 5, 'a');
      const remote = Hlc(1500, 9, 'b');
      expect(local.receive(remote, 2000), const Hlc(2000, 0, 'a'));
    });

    test('remote ahead: adopts remote millis, counter+1, keeps own node', () {
      const local = Hlc(1000, 5, 'a');
      const remote = Hlc(1500, 9, 'b');
      expect(local.receive(remote, 900), const Hlc(1500, 10, 'a'));
    });

    test('local ahead: keeps millis, increments own counter', () {
      const local = Hlc(2000, 5, 'a');
      const remote = Hlc(1500, 9, 'b');
      expect(local.receive(remote, 900), const Hlc(2000, 6, 'a'));
    });

    test('equal millis: max counter + 1', () {
      const local = Hlc(2000, 5, 'a');
      const remote = Hlc(2000, 9, 'b');
      expect(local.receive(remote, 900), const Hlc(2000, 10, 'a'));
    });

    test('result always exceeds both inputs', () {
      const local = Hlc(2000, 5, 'a');
      const remote = Hlc(2000, 9, 'b');
      final merged = local.receive(remote, 100);
      expect(merged > local, isTrue);
      expect(merged > remote, isTrue);
    });
  });

  group('ordering and encoding', () {
    test('compareTo: millis, then counter, then nodeId', () {
      expect(const Hlc(1, 9, 'z') < const Hlc(2, 0, 'a'), isTrue);
      expect(const Hlc(1, 1, 'z') < const Hlc(1, 2, 'a'), isTrue);
      expect(const Hlc(1, 1, 'a') < const Hlc(1, 1, 'b'), isTrue);
    });

    test('encode/parse roundtrip', () {
      final hlc = Hlc(ms0, 66, 'device-1234');
      expect(Hlc.parse(hlc.encode()), hlc);
    });

    test('lexicographic order of encoded form matches compareTo', () {
      final hlcs = [
        const Hlc(999, 0xFFFF, 'b'),
        Hlc(ms0, 0, 'a'),
        Hlc(ms0, 0, 'b'),
        Hlc(ms0, 16, 'a'),
        Hlc(ms0 + 1, 0, 'a'),
      ];
      final byCompare = [...hlcs]..sort();
      final byString = [...hlcs]
        ..sort((x, y) => x.encode().compareTo(y.encode()));
      expect(byString, byCompare);
    });

    test('parse rejects garbage', () {
      expect(() => Hlc.parse('not-an-hlc'), throwsFormatException);
    });
  });

  group('HlcClock', () {
    test('send is strictly monotonic under a frozen clock', () {
      final clock = FixedClock(t0);
      final hlcClock = HlcClock(nodeId: 'a', clock: clock);
      final first = hlcClock.send();
      final second = hlcClock.send();
      expect(second > first, isTrue);
      expect(second.millis, ms0);
    });

    test('send tracks an advancing clock', () {
      final clock = FixedClock(t0);
      final hlcClock = HlcClock(nodeId: 'a', clock: clock);
      hlcClock.send();
      clock.advance(const Duration(seconds: 1));
      expect(hlcClock.send(), Hlc(ms0 + 1000, 0, 'a'));
    });

    test('never regresses when wall clock jumps backwards', () {
      final clock = FixedClock(t0);
      final hlcClock = HlcClock(nodeId: 'a', clock: clock);
      final first = hlcClock.send();
      clock.time = t0.subtract(const Duration(hours: 1));
      final second = hlcClock.send();
      expect(second > first, isTrue);
    });

    test('receive folds remote into local state', () {
      final clock = FixedClock(t0);
      final hlcClock = HlcClock(nodeId: 'a', clock: clock);
      final merged = hlcClock.receive(Hlc(ms0 + 5000, 3, 'b'));
      expect(merged, Hlc(ms0 + 5000, 4, 'a'));
      expect(hlcClock.send() > merged, isTrue);
    });
  });
}
