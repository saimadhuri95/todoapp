import '../../core/clock.dart';
import '../db/database.dart';
import '../sync/device_identity.dart';
import '../sync/mailbox_store.dart';
import 'cloud_http.dart';
import 'cloud_providers.dart';
import 'oauth.dart';

/// See the native implementation for semantics.
class CloudAccount {
  const CloudAccount({
    required this.id,
    required this.provider,
    required this.label,
  });

  final String id;
  final CloudProviderId provider;
  final String label;
}

class CloudAccountRef {
  const CloudAccountRef({required this.accountId, this.rootPath});

  final String accountId;
  final String? rootPath;

  String encode() => accountId;

  static CloudAccountRef decode(String ref) => CloudAccountRef(accountId: ref);
}

/// Web placeholder: cloud accounts are unavailable until a browser-safe
/// transport exists; everything reads as signed-out.
class CloudAccountService {
  CloudAccountService({
    required KeyStore keyStore,
    required CloudHttp http,
    required Clock clock,
    AppDatabase? db,
  });

  Future<List<CloudAccount>> accounts() async => const [];

  Future<CloudAccount?> primaryAccount() async => null;

  Future<CloudProviderId?> connectedProvider() async => null;

  Future<CloudAccount> connect(
    CloudProviderId id, {
    required Future<Uri> Function(Uri authorizationUrl) authenticate,
    Uri? redirectUri,
    OAuthConfig? configOverride,
  }) => throw UnsupportedError('Cloud sign-in is unavailable on web.');

  Future<CloudAccount> connectWebDav({
    required Uri serverUrl,
    required String username,
    required String password,
  }) => throw UnsupportedError('WebDAV sync is unavailable on web.');

  Future<void> removeAccount(String accountId) async {}

  Future<void> disconnect() async {}

  Future<String> freshAccessToken([String? accountId]) =>
      throw StateError('No cloud account connected');

  Future<MailboxStore?> mailboxStore({
    String? accountId,
    String? rootPath,
  }) async => null;

  Future<MailboxStore?> mailboxStoreForRef(String accountRef) async => null;
}
