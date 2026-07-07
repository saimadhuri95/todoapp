import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/alarm_planner.dart';
import '../data/sync/lan_discovery.dart';
import '../data/sync/lan_transport.dart';
import '../data/sync/mailbox_transport.dart';
import '../data/sync/sync_orchestrator.dart';
import 'alarm_service.dart';
import 'providers.dart';

/// Builds a ready-to-run orchestrator from current app state, or null when
/// the device isn't paired yet. Shared by the settings screen's "Sync now"
/// and [SyncService]'s automatic triggers.
Future<SyncOrchestrator?> buildOrchestrator(
  ProviderContainer ref, {
  Future<List<LanPeer>> Function()? discoverPeers,
  AlarmScheduler? notifications,
  bool notificationsEnabled = true,
}) async {
  final pairing = ref.read(pairingServiceProvider);
  if (!await pairing.hasGroupKey()) return null;
  final groupKey = await pairing.loadOrCreateGroupKey();
  final engine = ref.read(syncEngineProvider);
  final mailboxPath = ref.read(mailboxPathProvider);
  return SyncOrchestrator(
    engine: engine,
    groupKey: groupKey,
    mailbox: mailboxPath == null
        ? null
        : MailboxTransport(
            root: Directory(mailboxPath),
            engine: engine,
            db: ref.read(databaseProvider),
            deviceId: ref.read(deviceIdProvider),
            groupKey: groupKey,
          ),
    discoverPeers: discoverPeers,
    notifications: notifications,
    notificationsEnabled: notificationsEnabled,
  );
}

/// Automatic sync triggers (rest of TASKS.md 3.14): app foreground,
/// debounced local mutations, periodic timer. Also runs the LAN sync
/// server + mDNS advertise/browse so nearby devices find each other.
class SyncService with WidgetsBindingObserver {
  SyncService(
    this._ref, {
    this.debounce = const Duration(seconds: 5),
    this.period = const Duration(minutes: 5),
  });

  final Ref _ref;
  final Duration debounce;
  final Duration period;

  StreamSubscription<void>? _mutations;
  Timer? _debounceTimer;
  Timer? _periodic;
  LanSyncServer? _server;
  LanDiscovery? _discovery;
  bool _syncing = false;

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);

    // Local mutation → debounced sync.
    _mutations = _ref.read(databaseProvider).tableUpdates().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, syncSoon);
    });

    _periodic = Timer.periodic(period, (_) => syncSoon());

    // LAN server + discovery, only meaningful once paired.
    final pairing = _ref.read(pairingServiceProvider);
    if (await pairing.hasGroupKey()) {
      await _startLan();
    }

    unawaited(syncSoon());
  }

  Future<void> _startLan() async {
    if (_server != null) return;
    final server = LanSyncServer(
      engine: _ref.read(syncEngineProvider),
      groupKey: await _ref.read(pairingServiceProvider).loadOrCreateGroupKey(),
      onVisibleTodosChanged: _notifyVisibleTodoChanges,
    );
    final port = await server.start();
    _server = server;
    final discovery = LanDiscovery(deviceId: _ref.read(deviceIdProvider));
    try {
      await discovery.start(port: port);
      _discovery = discovery;
    } on Exception {
      // mDNS unavailable (some networks/platforms): mailbox still works.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncSoon());
  }

  /// One guarded pass; safe to call from any trigger.
  Future<void> syncSoon() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _startLan(); // no-op until paired, idempotent after
      final orchestrator = await buildOrchestrator(
        _ref.container,
        discoverPeers: _discovery?.currentPeers,
        notifications: _ref.read(alarmSchedulerProvider),
        notificationsEnabled: _ref.read(alarmsEnabledProvider),
      );
      if (orchestrator != null) {
        await orchestrator.syncNow();
        _ref.read(lastSyncPassProvider.notifier).state = _ref
            .read(clockProvider)
            .now();
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _notifyVisibleTodoChanges() async {
    if (!_ref.read(alarmsEnabledProvider)) return;
    await _ref
        .read(alarmSchedulerProvider)
        .showInfo(
          title: 'List updated',
          body: 'Changes from another device were applied.',
        );
  }

  Future<void> stop() async {
    WidgetsBinding.instance.removeObserver(this);
    await _mutations?.cancel();
    _debounceTimer?.cancel();
    _periodic?.cancel();
    await _server?.stop();
    await _discovery?.stop();
  }
}

final syncServiceProvider = Provider<SyncService>(SyncService.new);
