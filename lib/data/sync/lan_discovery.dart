import 'package:bonsoir/bonsoir.dart';

import 'sync_orchestrator.dart';

/// mDNS advertise + browse for LAN peers (rest of TASKS.md 3.9).
/// Untestable in CI (no multicast); exercised in the manual test matrix.
class LanDiscovery {
  LanDiscovery({required this.deviceId});

  static const _serviceType = '_todosync._tcp';

  final String deviceId;
  final Map<String, LanPeer> _peers = {};
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  /// Advertise our LAN sync server and start browsing for peers.
  Future<void> start({required int port}) async {
    final broadcast = BonsoirBroadcast(
      service: BonsoirService(
        name: 'knot-$deviceId',
        type: _serviceType,
        port: port,
      ),
    );
    await broadcast.initialize();
    await broadcast.start();
    _broadcast = broadcast;

    final discovery = BonsoirDiscovery(type: _serviceType);
    await discovery.initialize();
    discovery.eventStream?.listen((event) {
      final service = event.service;
      if (service == null || service.name == 'knot-$deviceId') return;
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          discovery.serviceResolver.resolveService(service);
        case BonsoirDiscoveryServiceResolvedEvent():
          final host = service.hostAddress;
          if (host != null) {
            _peers[service.name] = (host: host, port: service.port);
          }
        case BonsoirDiscoveryServiceLostEvent():
          _peers.remove(service.name);
        default:
          break;
      }
    });
    await discovery.start();
    _discovery = discovery;
  }

  /// Snapshot of currently visible peers — plugs into
  /// [SyncOrchestrator.discoverPeers].
  Future<List<LanPeer>> currentPeers() async => _peers.values.toList();

  Future<void> stop() async {
    await _broadcast?.stop();
    await _discovery?.stop();
    _peers.clear();
  }
}
