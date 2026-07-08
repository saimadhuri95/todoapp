import 'dart:convert';

import 'package:drift/drift.dart' show TableOrViewStatements;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/clock.dart';
import '../core/cloud_folder.dart';
import '../core/hlc.dart';
import '../data/cloud/cloud_account_service.dart';
import '../data/cloud/cloud_http.dart';
import '../data/cloud/cloud_providers.dart';
import '../data/db/database.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/list_repository.dart';
import '../data/repositories/todo_repository.dart';
import '../data/sync/device_identity.dart';
import '../data/sync/mailbox_store_factory.dart';
import '../data/sync/mailbox_transport.dart';
import '../data/sync/pairing_service.dart';
import '../data/sync/sync_engine.dart';
import 'cloud_folder_channel.dart';
import 'key_store_factory.dart';

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

/// Sharing groups + membership (ADR 0004, TASKS 8.2).
final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) =>
      GroupRepository(ref.watch(databaseProvider), ref.watch(hlcClockProvider)),
);

/// Active sharing groups, for the drawer sections and the Sharing &
/// storage screen (8.8/8.9).
final syncGroupsProvider = StreamProvider<List<SyncGroup>>(
  (ref) => ref.watch(groupRepositoryProvider).watchAll(),
);

/// Theme override — system/light/dark (TASKS.md 6.6). Seeded from the
/// `themeMode` pref in main(), persisted on change in settings.
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

/// Glanceable mode (TASKS.md 6.5): large bumps type + checkbox size on the
/// list for dashboard-mounted phones. Seeded from the `displayDensity` pref
/// in main(), persisted on change in settings.
enum DisplayDensity { standard, large }

final displayDensityProvider = StateProvider<DisplayDensity>(
  (_) => DisplayDensity.standard,
);

/// When the last sync pass finished on this device (null = none yet this
/// run); written by SyncService, shown in sync settings (TASKS.md 6.3).
final lastSyncPassProvider = StateProvider<DateTime?>((_) => null);

class SyncHealthSnapshot {
  const SyncHealthSnapshot({
    required this.transportLabel,
    required this.isSyncReady,
    this.pendingOutboundCount = 0,
  });

  final String transportLabel;
  final bool isSyncReady;
  final int pendingOutboundCount;
}

/// Sentinel [listFilterProvider] value for the Inbox view: unfiled todos
/// (listId == null). The Inbox is deliberately *not* a synced list row —
/// devices auto-creating one each would duplicate on merge, while a null
/// listId can't diverge (TASKS.md 6.15).
const kInboxFilter = '';
const kSomedayFilter = '__someday__';

enum SmartDateFilter { any, today, upcoming, someday }

class SavedSmartFilter {
  const SavedSmartFilter({
    required this.id,
    required this.name,
    this.listId,
    this.tag,
    this.minPriority = 0,
    this.dateFilter = SmartDateFilter.any,
  });

  final String id;
  final String name;
  final String? listId;
  final String? tag;
  final int minPriority;
  final SmartDateFilter dateFilter;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'listId': listId,
    'tag': tag,
    'minPriority': minPriority,
    'dateFilter': dateFilter.name,
  };

  factory SavedSmartFilter.fromJson(Map<String, Object?> json) {
    return SavedSmartFilter(
      id: json['id'] as String,
      name: json['name'] as String,
      listId: json['listId'] as String?,
      tag: json['tag'] as String?,
      minPriority: json['minPriority'] as int? ?? 0,
      dateFilter:
          SmartDateFilter.values.asNameMap()[json['dateFilter'] as String?] ??
          SmartDateFilter.any,
    );
  }

  SavedSmartFilter copyWith({required String id}) => SavedSmartFilter(
    id: id,
    name: name,
    listId: listId,
    tag: tag,
    minPriority: minPriority,
    dateFilter: dateFilter,
  );
}

class SavedSmartFiltersController
    extends StateNotifier<List<SavedSmartFilter>> {
  SavedSmartFiltersController() : super(const []) {
    _load();
  }

  static const storageKey = 'savedSmartFilters';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw) as List<dynamic>;
    state = [
      for (final entry in decoded)
        SavedSmartFilter.fromJson((entry as Map).cast<String, Object?>()),
    ];
  }

  Future<SavedSmartFilter> add(SavedSmartFilter draft) async {
    final filter = draft.copyWith(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    state = [...state, filter];
    await _save();
    return filter;
  }

  Future<void> remove(String id) async {
    state = [
      for (final filter in state)
        if (filter.id != id) filter,
    ];
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode([for (final filter in state) filter.toJson()]),
    );
  }
}

class ChecklistTemplate {
  const ChecklistTemplate({
    required this.id,
    required this.name,
    required this.title,
    this.notes = '',
    this.subtasks = const [],
  });

  final String id;
  final String name;
  final String title;
  final String notes;
  final List<String> subtasks;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'title': title,
    'notes': notes,
    'subtasks': subtasks,
  };

  factory ChecklistTemplate.fromJson(Map<String, Object?> json) =>
      ChecklistTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        title: json['title'] as String,
        notes: json['notes'] as String? ?? '',
        subtasks: [
          for (final item in json['subtasks'] as List<dynamic>? ?? const [])
            item as String,
        ],
      );

  ChecklistTemplate copyWith({required String id}) => ChecklistTemplate(
    id: id,
    name: name,
    title: title,
    notes: notes,
    subtasks: subtasks,
  );
}

class ChecklistTemplatesController
    extends StateNotifier<List<ChecklistTemplate>> {
  ChecklistTemplatesController() : super(const []) {
    _load();
  }

  static const storageKey = 'checklistTemplates';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw) as List<dynamic>;
    state = [
      for (final entry in decoded)
        ChecklistTemplate.fromJson((entry as Map).cast<String, Object?>()),
    ];
  }

  Future<ChecklistTemplate> add(ChecklistTemplate draft) async {
    final template = draft.copyWith(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    state = [...state, template];
    await _save();
    return template;
  }

  Future<void> remove(String id) async {
    state = [
      for (final template in state)
        if (template.id != id) template,
    ];
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode([for (final template in state) template.toJson()]),
    );
  }
}

/// Currently selected list filter (null = all lists, [kInboxFilter] = Inbox).
final listFilterProvider = StateProvider<String?>((_) => null);

/// Exact day selected from the calendar view. Null means no calendar filter.
final dateFilterProvider = StateProvider<DateTime?>((_) => null);

final savedSmartFiltersProvider =
    StateNotifierProvider<SavedSmartFiltersController, List<SavedSmartFilter>>(
      (_) => SavedSmartFiltersController(),
    );

final activeSmartFilterIdProvider = StateProvider<String?>((_) => null);

final checklistTemplatesProvider =
    StateNotifierProvider<
      ChecklistTemplatesController,
      List<ChecklistTemplate>
    >((_) => ChecklistTemplatesController());

final activeSmartFilterProvider = Provider<SavedSmartFilter?>((ref) {
  final id = ref.watch(activeSmartFilterIdProvider);
  if (id == null) return null;
  for (final filter in ref.watch(savedSmartFiltersProvider)) {
    if (filter.id == id) return filter;
  }
  return null;
});

/// Search text applied to the active list (client-side filter).
final searchQueryProvider = StateProvider<String>((_) => '');

/// Selected todo id for the wide-layout detail pane.
final selectedTodoIdProvider = StateProvider<String?>((_) => null);

final allActiveTodosProvider = StreamProvider<List<Todo>>(
  (ref) => ref.watch(todoRepositoryProvider).watchActive(),
);

final activeTodosProvider = StreamProvider<List<Todo>>((ref) {
  final filter = ref.watch(listFilterProvider);
  final smartFilter = ref.watch(activeSmartFilterProvider);
  final exactDate = ref.watch(dateFilterProvider);
  final now = ref.watch(clockProvider).now();
  return ref
      .watch(todoRepositoryProvider)
      .watchActive(
        listId: smartFilter?.listId ?? (filter == kInboxFilter ? null : filter),
        unfiledOnly: smartFilter == null && filter == kInboxFilter,
        somedayOnly: smartFilter == null && filter == kSomedayFilter,
      )
      .map(
        (todos) => _applyActiveFilters(
          todos: todos,
          smartFilter: smartFilter,
          exactDate: exactDate,
          now: now,
        ),
      );
});

final completedTodosProvider = StreamProvider<List<Todo>>(
  (ref) => ref.watch(todoRepositoryProvider).watchCompleted(),
);

final subtasksProvider = StreamProvider.family<List<Todo>, String>(
  (ref, parentId) => ref.watch(todoRepositoryProvider).watchSubtasks(parentId),
);

List<Todo> _applyActiveFilters({
  required List<Todo> todos,
  required SavedSmartFilter? smartFilter,
  required DateTime? exactDate,
  required DateTime now,
}) {
  return [
    for (final todo in todos)
      if (_matchesSmartFilter(todo, smartFilter, now) &&
          _matchesExactDate(todo, exactDate))
        todo,
  ];
}

bool _matchesSmartFilter(Todo todo, SavedSmartFilter? filter, DateTime now) {
  if (filter == null) return true;
  final tag = filter.tag?.trim().toLowerCase();
  if (tag != null &&
      tag.isNotEmpty &&
      !todo.tags.any((value) => value.toLowerCase() == tag)) {
    return false;
  }
  if (todo.priority < filter.minPriority) return false;
  return switch (filter.dateFilter) {
    SmartDateFilter.any => true,
    SmartDateFilter.today => _isSameDayMs(todo.dueAtMs, now),
    SmartDateFilter.upcoming =>
      todo.dueAtMs != null &&
          !DateTime.fromMillisecondsSinceEpoch(
            todo.dueAtMs!,
          ).isBefore(DateTime(now.year, now.month, now.day + 1)),
    SmartDateFilter.someday => todo.dueAtMs == null,
  };
}

bool _matchesExactDate(Todo todo, DateTime? date) {
  if (date == null) return true;
  return _isSameDayMs(todo.dueAtMs, date);
}

bool _isSameDayMs(int? ms, DateTime date) {
  if (ms == null) return false;
  final value = DateTime.fromMillisecondsSinceEpoch(ms);
  return value.year == date.year &&
      value.month == date.month &&
      value.day == date.day;
}

final overdueTodosProvider = Provider<List<Todo>>((ref) {
  if (ref.watch(listFilterProvider) == kSomedayFilter) return const [];
  final todos = ref.watch(activeTodosProvider).value ?? const <Todo>[];
  final now = ref.watch(clockProvider).now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  return [
    for (final todo in todos)
      if (todo.dueAtMs != null &&
          DateTime.fromMillisecondsSinceEpoch(
            todo.dueAtMs!,
          ).isBefore(startOfToday))
        todo,
  ];
});

final staleTodoCandidatesProvider =
    StreamProvider.autoDispose<List<StaleTodoCandidate>>((ref) async* {
      final db = ref.watch(databaseProvider);
      final repo = ref.watch(todoRepositoryProvider);
      yield await repo.staleCandidates(now: ref.read(clockProvider).now());
      await for (final _ in db.tableUpdates()) {
        yield await repo.staleCandidates(now: ref.read(clockProvider).now());
      }
    });

final dismissedOverduePromptIdsProvider = StateProvider<Set<String>>(
  (_) => <String>{},
);

final listsProvider = StreamProvider<List<TodoList>>(
  (ref) => ref.watch(listRepositoryProvider).watchAll(),
);

// --- Sync & pairing ---

/// Keychain first; file fallback for ad-hoc-signed builds where the
/// keychain entitlement is unavailable (TASKS.md 4.17).
final keyStoreProvider = Provider<KeyStore>((_) => createKeyStore());

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

// --- Cloud storage accounts (Dropbox / Google Drive / OneDrive) ---

final cloudHttpProvider = Provider<CloudHttp>((_) => createCloudHttp());

final cloudAccountServiceProvider = Provider<CloudAccountService>(
  (ref) => CloudAccountService(
    keyStore: ref.watch(keyStoreProvider),
    http: ref.watch(cloudHttpProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Connected OAuth storage provider, mirrored out of the keychain for UI
/// reactivity (null = none). Seeded in main(), written by the connect
/// screen after connect/disconnect.
final cloudAccountProvider = StateProvider<CloudProviderId?>((_) => null);

/// Quiet sync-health summary for 6.27: active transport(s) and unpublished
/// mailbox changes, recomputed whenever local tables move.
final syncHealthProvider = StreamProvider.autoDispose<SyncHealthSnapshot>((
  ref,
) async* {
  ref.watch(mailboxPathProvider);
  final db = ref.watch(databaseProvider);
  yield await _readSyncHealth(ref);
  await for (final _ in db.tableUpdates()) {
    yield await _readSyncHealth(ref);
  }
});

/// Managed cloud folder + folder bookmarks (iCloud Drive / security-scoped
/// bookmarks on Apple platforms); unsupported elsewhere.
final cloudFolderProvider = Provider<CloudFolderLocator>(
  (_) => platformCloudFolder(),
);

Future<SyncHealthSnapshot> _readSyncHealth(Ref ref) async {
  final pairing = ref.read(pairingServiceProvider);
  final mailboxPath = ref.read(mailboxPathProvider);
  final cloudProvider = ref.read(cloudAccountProvider);
  final paired = await pairing.hasGroupKey();
  final hasMailbox = cloudProvider != null || mailboxPath != null;
  if (!paired && !hasMailbox) {
    return const SyncHealthSnapshot(
      transportLabel: 'Connect a cloud or pair a device to start sync',
      isSyncReady: false,
    );
  }

  var pendingOutboundCount = 0;
  final store = cloudProvider != null
      ? await ref.read(cloudAccountServiceProvider).mailboxStore()
      : (mailboxPath == null ? null : createFolderMailboxStore(mailboxPath));
  if (store != null) {
    final transport = MailboxTransport.withStore(
      store: store,
      engine: ref.read(syncEngineProvider),
      db: ref.read(databaseProvider),
      deviceId: ref.read(deviceIdProvider),
      groupKey: await pairing.loadOrCreateGroupKey(),
    );
    pendingOutboundCount = await transport.pendingOutboundCount();
  }

  return SyncHealthSnapshot(
    transportLabel: switch ((cloudProvider, mailboxPath)) {
      (final p?, _) => 'Using ${p.displayName}',
      (null, String()) => 'Using LAN + mailbox',
      _ => 'Using LAN',
    },
    isSyncReady: true,
    pendingOutboundCount: pendingOutboundCount,
  );
}
