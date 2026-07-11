import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import 'kiosk.dart';

/// The platform power seam; overridden with a fake in widget tests.
final kioskPowerProvider = Provider<KioskPower>((_) => BatteryWakelockPower());

/// What the wall display shows: pinned, overdue, and due-today todos,
/// soonest first (undated pins last). Pure for testing.
List<Todo> kioskTodos(List<Todo> todos, DateTime now, {int limit = 12}) {
  final endOfDay = DateTime(now.year, now.month, now.day + 1);
  final visible = [
    for (final t in todos)
      if (t.pinned ||
          (t.dueAtMs != null && t.dueAtMs! < endOfDay.millisecondsSinceEpoch))
        t,
  ];
  visible.sort((a, b) {
    final ad = a.dueAtMs, bd = b.dueAtMs;
    if (ad == null) return bd == null ? 0 : 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  });
  return visible.length <= limit ? visible : visible.sublist(0, limit);
}

/// Full-screen wall display (TASKS.md 6.38, extends 6.5's glanceable mode):
/// clock header + today's todos, burn-in-safe pixel shifting and night
/// dimming, screen held awake while the device is on power.
class KioskScreen extends ConsumerStatefulWidget {
  const KioskScreen({super.key});

  @override
  ConsumerState<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends ConsumerState<KioskScreen> {
  late DateTime _now;
  late KioskPower _power; // captured here; ref is unusable in dispose()
  Timer? _tick;
  StreamSubscription<bool>? _powerChanges;

  @override
  void initState() {
    super.initState();
    _now = ref.read(clockProvider).now();
    // 20s ticks keep the minute display honest without burning battery.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      setState(() => _now = ref.read(clockProvider).now());
    });
    _power = ref.read(kioskPowerProvider);
    _powerChanges = _power.poweredChanges().listen(_power.setKeepAwake);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _powerChanges?.cancel();
    // Leaving the wall display always releases the screen.
    _power.setKeepAwake(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(allActiveTodosProvider).valueOrNull ?? const [];
    final visible = kioskTodos(todos, _now);
    final minuteIndex = _now.millisecondsSinceEpoch ~/ 60000;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Opacity(
        opacity: kioskDim(_now.hour),
        child: Transform.translate(
          offset: burnInShift(minuteIndex),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      DateFormat.Hm().format(_now),
                      style: textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w200,
                        fontSize: 96,
                      ),
                    ),
                    Text(
                      DateFormat.yMMMMEEEEd().format(_now),
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Text(
                                'All clear',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: Colors.white38,
                                ),
                              ),
                            )
                          : ListView(
                              children: [
                                for (final todo in visible)
                                  _KioskTodoTile(todo: todo, now: _now),
                              ],
                            ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: 'Exit wall display',
                    icon: const Icon(Icons.close, color: Colors.white38),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KioskTodoTile extends ConsumerWidget {
  const _KioskTodoTile({required this.todo, required this.now});

  final Todo todo;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = todo.dueAtMs;
    final overdue = due != null && due < now.millisecondsSinceEpoch;
    return ListTile(
      leading: Checkbox(
        value: false,
        side: const BorderSide(color: Colors.white54, width: 2),
        onChanged: (_) => ref.read(todoRepositoryProvider).complete(todo.id),
      ),
      title: Text(
        todo.title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: overdue ? Colors.orangeAccent : Colors.white,
        ),
      ),
      subtitle: due == null
          ? null
          : Text(
              DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(due)),
              style: const TextStyle(color: Colors.white54),
            ),
    );
  }
}
