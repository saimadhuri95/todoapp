import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/hlc.dart';
import '../data/db/database.dart';
import '../data/repositories/list_repository.dart';
import '../data/repositories/todo_repository.dart';

/// Bound in main() (and overridden in tests): the real database and the
/// persistent device id have async setup, so they're injected, not built.
final databaseProvider = Provider<AppDatabase>(
  (_) => throw UnimplementedError('databaseProvider must be overridden'),
);

final deviceIdProvider = Provider<String>(
  (_) => throw UnimplementedError('deviceIdProvider must be overridden'),
);

final clockProvider = Provider<Clock>((_) => const SystemClock());

final hlcClockProvider = Provider<HlcClock>(
  (ref) => HlcClock(
    nodeId: ref.watch(deviceIdProvider),
    clock: ref.watch(clockProvider),
  ),
);

final todoRepositoryProvider = Provider<TodoRepository>(
  (ref) =>
      TodoRepository(ref.watch(databaseProvider), ref.watch(hlcClockProvider)),
);

final listRepositoryProvider = Provider<ListRepository>(
  (ref) =>
      ListRepository(ref.watch(databaseProvider), ref.watch(hlcClockProvider)),
);

/// Currently selected list filter (null = all lists).
final listFilterProvider = StateProvider<String?>((_) => null);

/// Search text applied to the active list (client-side filter).
final searchQueryProvider = StateProvider<String>((_) => '');

/// Selected todo id for the wide-layout detail pane.
final selectedTodoIdProvider = StateProvider<String?>((_) => null);

final activeTodosProvider = StreamProvider<List<Todo>>(
  (ref) => ref
      .watch(todoRepositoryProvider)
      .watchActive(listId: ref.watch(listFilterProvider)),
);

final completedTodosProvider = StreamProvider<List<Todo>>(
  (ref) => ref.watch(todoRepositoryProvider).watchCompleted(),
);

final listsProvider = StreamProvider<List<TodoList>>(
  (ref) => ref.watch(listRepositoryProvider).watchAll(),
);
