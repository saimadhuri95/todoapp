import '../../core/clock.dart';
import '../sync/device_identity.dart';
import '../sync/mailbox_store.dart';
import 'cloud_http.dart';
import 'cloud_providers.dart';

class CloudAccountService {
  CloudAccountService({
    required KeyStore keyStore,
    required CloudHttp http,
    required Clock clock,
  });

  Future<CloudProviderId?> connectedProvider() async => null;

  Future<void> connect(
    CloudProviderId id, {
    required Future<Uri> Function(Uri authorizationUrl) authenticate,
  }) => throw UnsupportedError('Cloud sign-in is unavailable on web.');

  Future<void> connectWebDav({
    required Uri serverUrl,
    required String username,
    required String password,
  }) => throw UnsupportedError('WebDAV sync is unavailable on web.');

  Future<void> disconnect() async {}

  Future<String> freshAccessToken() =>
      throw StateError('No cloud account connected');

  Future<MailboxStore?> mailboxStore() async => null;
}
