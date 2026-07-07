import 'package:drift/drift.dart' show TableOrViewStatements, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/alarm_planner.dart';

import '../support/simulated_device.dart';
import '../support/sync_simulator.dart';

void main() {
  final start = DateTime.utc(2026, 7, 6, 12);
  late Device a;
  late Device b;
  late Device c;
  late SyncSimulator simulator;

  setUp(() {
    a = Device('aa', start);
    b = Device('bb', start.add(const Duration(seconds: 7)));
    c = Device('cc', start.subtract(const Duration(seconds: 11)));
    simulator = SyncSimulator();
  });

  tearDown(() async {
    await a.close();
    await b.close();
    await c.close();
  });

  test('three-device LAN to mailbox relay converges in process', () async {
    await a.todos.create(title: 'offline on a');
    await simulator.lan.sync(a, b);
    await simulator.mailbox.publish(b);
    await simulator.mailbox.consume(c);

    await c.todos.create(title: 'reply from c');
    await simulator.mailbox.publish(c);
    await simulator.mailbox.consume(b);
    await simulator.lan.sync(b, a);

    await simulator.fullExchange([a, b, c]);

    final dumpA = await a.dump();
    expect(await b.dump(), dumpA);
    expect(await c.dump(), dumpA);
  });

  test(
    'corrupt mailbox tail is left unread without crashing the consumer',
    () async {
      await a.todos.create(title: 'safe write');
      await simulator.mailbox.publish(a);

      expect(await simulator.mailbox.consume(b), greaterThan(0));
      final before = await b.dump();

      simulator.mailbox.injectCorruptTail(a.id);

      expect(await simulator.mailbox.consume(b), 0);
      expect(await b.dump(), before);
    },
  );

  test(
    'dismissal propagation suppresses the matching alarm occurrence',
    () async {
      final due = start.add(const Duration(minutes: 30)).millisecondsSinceEpoch;
      final todo = await a.todos.create(title: 'ring me', dueAtMs: due);
      await a.todos.edit(todo.id, alarmOffsetsMinutes: const Value([0]));
      await simulator.lan.sync(a, b);

      final plannedBefore = planAlarms(
        await b.db.todos.all().get(),
        now: start,
        horizon: const Duration(days: 1),
      );
      expect(plannedBefore, hasLength(1));

      await a.todos.dismissAlarm(todo.id, due);
      await simulator.mailbox.publish(a);
      await simulator.mailbox.consume(b);

      final plannedAfter = planAlarms(
        await b.db.todos.all().get(),
        now: start,
        horizon: const Duration(days: 1),
      );
      expect(plannedAfter, isEmpty);
    },
  );
}
