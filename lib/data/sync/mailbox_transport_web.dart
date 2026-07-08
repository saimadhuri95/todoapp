import 'mailbox_store.dart';

/// Web placeholder for the native mailbox transport.
///
/// Web sync is disabled until a browser-safe transport is implemented; this
/// keeps common sync-health code compiling without pretending work was done.
class MailboxTransport {
  MailboxTransport({
    required Object root,
    required Object engine,
    required Object db,
    required String deviceId,
    required Object groupKey,
  });

  MailboxTransport.withStore({
    required MailboxStore store,
    required Object engine,
    required Object db,
    required String deviceId,
    required Object groupKey,
  });

  Future<int> pendingOutboundCount() async => 0;
}
