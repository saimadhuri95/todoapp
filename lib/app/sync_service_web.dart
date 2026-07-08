import 'package:flutter_riverpod/flutter_riverpod.dart';

class WebSyncReport {
  const WebSyncReport({
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
  final bool skipped;
  final List<String> errors;

  int get totalApplied => mailboxApplied + lanApplied;
}

class WebSyncOrchestrator {
  Object? get mailbox => null;

  Future<WebSyncReport> syncNow() async => const WebSyncReport();
}

Future<WebSyncOrchestrator?> buildOrchestrator(ProviderContainer ref) async =>
    null;

class SyncService {
  SyncService(Ref _);

  Future<void> start() async {}

  Future<void> syncSoon() async {}

  Future<void> stop() async {}
}

final syncServiceProvider = Provider<SyncService>(SyncService.new);
