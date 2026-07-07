import 'dart:math';

import 'package:todoapp/data/sync/changeset.dart';

import 'simulated_device.dart';

class FakeLanTransport {
  Future<int> sync(Device a, Device b) async {
    final aVector = await a.engine.versionVector();
    final bVector = await b.engine.versionVector();
    final aToB = await a.engine.changesFor(bVector);
    final bToA = await b.engine.changesFor(aVector);
    final appliedOnB = await b.engine.apply(aToB);
    final appliedOnA = await a.engine.apply(bToA);
    return appliedOnA + appliedOnB;
  }
}

class FakeMailboxEntry {
  const FakeMailboxEntry.changeset(this.changeset) : corrupt = false;
  const FakeMailboxEntry.corrupt() : changeset = null, corrupt = true;

  final Changeset? changeset;
  final bool corrupt;
}

class FakeMailboxTransport {
  final _outboxes = <String, List<FakeMailboxEntry>>{};
  final _publishedVectors = <String, Map<String, String>>{};
  final _cursors = <String, Map<String, int>>{};

  Future<int> publish(Device device) async {
    final since = _publishedVectors[device.id] ?? const <String, String>{};
    final delta = await device.engine.changesFor(since);
    if (delta.writes.isEmpty) return 0;
    _outboxes
        .putIfAbsent(device.id, () => [])
        .add(FakeMailboxEntry.changeset(delta));
    _publishedVectors[device.id] = await device.engine.versionVector();
    return delta.writes.length;
  }

  void injectCorruptTail(String deviceId) {
    _outboxes
        .putIfAbsent(deviceId, () => [])
        .add(const FakeMailboxEntry.corrupt());
  }

  void shuffleOutbox(String deviceId, Random rng) {
    final outbox = _outboxes[deviceId];
    if (outbox == null) return;
    outbox.shuffle(rng);
  }

  Future<int> consume(Device device) async {
    var applied = 0;
    final cursors = _cursors.putIfAbsent(device.id, () => {});
    for (final entry in _outboxes.entries) {
      if (entry.key == device.id) continue;
      var index = cursors[entry.key] ?? 0;
      while (index < entry.value.length) {
        final message = entry.value[index];
        if (message.corrupt) break;
        applied += await device.engine.apply(message.changeset!);
        index++;
        cursors[entry.key] = index;
      }
    }
    return applied;
  }
}

class SyncSimulator {
  final lan = FakeLanTransport();
  final mailbox = FakeMailboxTransport();

  Future<void> fullExchange(Iterable<Device> devices, {int passes = 2}) async {
    final all = devices.toList();
    for (var i = 0; i < passes; i++) {
      for (final device in all) {
        await mailbox.publish(device);
      }
      for (final device in all) {
        await mailbox.consume(device);
      }
      for (final a in all) {
        for (final b in all) {
          if (a.id == b.id) continue;
          await lan.sync(a, b);
        }
      }
    }
  }
}
