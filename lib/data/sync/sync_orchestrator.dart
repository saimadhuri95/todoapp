import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'lan_transport.dart';
import 'mailbox_transport.dart';
import 'sync_engine.dart';

/// A reachable LAN peer (from mDNS browse, or manual entry).
typedef LanPeer = ({String host, int port});

class SyncReport {
  const SyncReport({
    this.mailboxApplied = 0,
    this.mailboxPublished = 0,
    this.lanApplied = 0,
    this.lanPeersReached = 0,
    this.skipped = false,
    this.errors = const [],
  });

  final int mailboxApplied;
  final int mailboxPublished;
  final int lanApplied;
  final int lanPeersReached;

  /// True when a sync was already in flight and this call did nothing.
  final bool skipped;
  final List<String> errors;

  int get totalApplied => mailboxApplied + lanApplied;
}

/// Decides *when* to sync and runs every configured transport (TASKS.md
/// 3.13). Transports are optional: mailbox appears once the user picks a
/// folder, LAN peers once discovery (or manual entry) provides them.
class SyncOrchestrator {
  SyncOrchestrator({
    required this.engine,
    required this.groupKey,
    this.mailbox,
    this.discoverPeers,
    this.connectTimeout = const Duration(seconds: 3),
  });

  final SyncEngine engine;
  final SecretKey groupKey;
  final MailboxTransport? mailbox;
  final Future<List<LanPeer>> Function()? discoverPeers;
  final Duration connectTimeout;

  Timer? _timer;
  bool _running = false;

  /// Runs one full sync pass. Reentrant calls are skipped, not queued —
  /// the running pass already covers their intent.
  Future<SyncReport> syncNow() async {
    if (_running) return const SyncReport(skipped: true);
    _running = true;
    try {
      var mailboxApplied = 0;
      var mailboxPublished = 0;
      var lanApplied = 0;
      var lanPeersReached = 0;
      final errors = <String>[];

      // Consume before publish so freshly learned writes get relayed in
      // the same pass.
      final box = mailbox;
      if (box != null) {
        try {
          mailboxApplied = await box.consume();
          mailboxPublished = await box.publish();
        } on FileSystemException catch (e) {
          errors.add('mailbox: ${e.message}');
        }
      }

      final discover = discoverPeers;
      if (discover != null) {
        for (final peer in await discover()) {
          try {
            final socket = await Socket.connect(
              peer.host,
              peer.port,
              timeout: connectTimeout,
            );
            lanApplied += await LanSync.sync(
              socket: socket,
              engine: engine,
              groupKey: groupKey,
            );
            lanPeersReached++;
          } on SocketException catch (e) {
            errors.add('lan ${peer.host}:${peer.port}: ${e.message}');
          }
        }
      }

      return SyncReport(
        mailboxApplied: mailboxApplied,
        mailboxPublished: mailboxPublished,
        lanApplied: lanApplied,
        lanPeersReached: lanPeersReached,
        errors: errors,
      );
    } finally {
      _running = false;
    }
  }

  /// Periodic background pass. Also call [syncNow] on app foreground and
  /// after local mutations (debounced) — those hooks live in the UI layer.
  void start({Duration period = const Duration(minutes: 5)}) {
    _timer?.cancel();
    _timer = Timer.periodic(period, (_) => syncNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
