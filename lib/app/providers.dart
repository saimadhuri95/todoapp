import 'package:drift/drift.dart' show TableOrViewStatements;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/clock.dart';
import '../core/cloud_folder.dart';
import '../core/hlc.dart';
import '../data/db/database.dart';
import '../data/repositories/list_repository.dart';
import '../data/repositories/todo_repository.dart';
import '../data/sync/device_identity.dart';
import '../data/sync/pairing_service.dart';
import '../data/sync/sync_engine.dart';
import 'cloud_folder_channel.dart';

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

/// Theme override — system/light/dark (TASKS.md 6.6). Seeded from the
/// `themeMode` pref in main(), persisted on change in settings.
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

/// Sentinel [listFilterProvider] value for the Inbox view: unfiled todos
/// (listId == null). The Inbox is deliberately *not* a synced list row —
/// devices auto-creating one each would duplicate on merge, while a null
/// listId can't diverge (TASKS.md 6.15).
const kInboxFilter = '';

/// Currently selected list filter (null = all lists, [kInboxFilter] = Inbox).
final listFilterProvider = StateProvider<String?>((_) => null);

/// Search text applied to the active list (client-side filter).
final searchQueryProvider = StateProvider<String>((_) => '');

/// Selected todo id for the wide-layout detail pane.
final selectedTodoIdProvider = StateProvider<String?>((_) => null);

final activeTodosProvider = StreamProvider<List<Todo>>((ref) {
  final filter = ref.watch(listFilterProvider);
  return ref
      .watch(todoRepositoryProvider)
      .watchActive(
        listId: filter == kInboxFilter ? null : filter,
        unfiledOnly: filter == kInboxFilter,
      );
});

final completedTodosProvider = StreamProvider<List<Todo>>(
  (ref) => ref.watch(todoRepositoryProvider).watchCompleted(),
);

final listsProvider = StreamProvider<List<TodoList>>(
  (ref) => ref.watch(listRepositoryProvider).watchAll(),
);

// --- Sync & pairing ---

/// Keychain first; file fallback for ad-hoc-signed builds where the
/// keychain entitlement is unavailable (TASKS.md 4.17).
final keyStoreProvider = Provider<KeyStore>(
  (_) => FallbackKeyStore(
    primary: const SecureKeyStore(),
    fallback: FileKeyStore(getApplicationSupportDirectory),
  ),
);

final deviceIdentityProvider = FutureProvider<DeviceIdentity>(
  (ref) => DeviceIdentity.loadOrCreate(
    ref.watch(keyStoreProvider),
    ref.watch(deviceIdProvider),
  ),
);

final pairingServiceProvider = Provider<PairingService>(
  (ref) => PairingService(
    db: ref.watch(databaseProvider),
    hlc: ref.watch(hlcClockProvider),
    keyStore: ref.watch(keyStoreProvider),
  ),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    db: ref.watch(databaseProvider),
    hlcClock: ref.watch(hlcClockProvider),
    deviceId: ref.watch(deviceIdProvider),
  ),
);

/// Paired devices (this one included once registered); revoked devices
/// are tombstoned and hidden.
final devicesProvider = StreamProvider<List<Device>>(
  (ref) =>
      (ref.watch(databaseProvider).devices.select()
            ..where((d) => d.deleted.equals(false)))
          .watch(),
);

/// peerId → sync_log row, for "last synced" display.
final syncLogProvider = StreamProvider<Map<String, SyncLogData>>(
  (ref) => ref
      .watch(databaseProvider)
      .syncLog
      .select()
      .watch()
      .map((rows) => {for (final r in rows) r.peerId: r}),
);

/// Mailbox folder path; seeded from prefs in main(), persisted on change.
final mailboxPathProvider = StateProvider<String?>((_) => null);

/// Managed cloud folder + folder bookmarks (iCloud Drive / security-scoped
/// bookmarks on Apple platforms); unsupported elsewhere.
final cloudFolderProvider = Provider<CloudFolderLocator>(
  (_) => platformCloudFolder(),
);
