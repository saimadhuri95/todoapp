import '../../core/clock.dart';
import '../sync/device_identity.dart';
import '../sync/mailbox_store.dart';
import 'cloud_http.dart';
import 'cloud_providers.dart';
import 'dropbox_store.dart';
import 'gdrive_store.dart';
import 'oauth.dart';
import 'onedrive_store.dart';

/// The one connected OAuth storage account (Dropbox / Google Drive /
/// OneDrive), if any. iCloud Drive is *not* managed here — it needs no
/// tokens; connecting it points the existing mailbox-folder path at the
/// ubiquity container (see the connect screen).
///
/// Tokens live in the device keychain ([KeyStore]) and never sync;
/// the provider choice sits beside them so a keychain wipe can't leave a
/// dangling provider with no credentials.
class CloudAccountService {
  CloudAccountService({
    required this.keyStore,
    required CloudHttp http,
    required Clock clock,
  }) : _http = http,
       _flow = PkceFlow(http: http, clock: clock),
       _clock = clock;

  final KeyStore keyStore;
  final CloudHttp _http;
  final PkceFlow _flow;
  final Clock _clock;

  static const _providerKey = 'cloud_provider';
  static const _tokensKey = 'cloud_tokens';

  Future<CloudProviderId?> connectedProvider() async {
    final name = await keyStore.read(_providerKey);
    if (name == null || name.isEmpty) return null;
    return CloudProviderId.values.asNameMap()[name];
  }

  /// Runs the PKCE dance for [id]. [authenticate] is the interactive leg:
  /// open the browser at the given URL and complete with the redirect URI
  /// the provider sends back (OAuthCallbackChannel on iOS).
  Future<void> connect(
    CloudProviderId id, {
    required Future<Uri> Function(Uri authorizationUrl) authenticate,
  }) async {
    final config = id.oauthConfig;
    if (config == null) {
      throw ArgumentError('$id does not use OAuth');
    }
    if (!config.isConfigured) {
      throw StateError(
        '${id.displayName} client id missing — see docs/cloud-providers.md',
      );
    }
    final attempt = await _flow.begin(config);
    final redirect = await authenticate(attempt.authorizationUrl);
    final tokens = await _flow.finish(config, attempt, redirect);
    await keyStore.write(_tokensKey, tokens.encode());
    await keyStore.write(_providerKey, id.name);
  }

  /// Forgets the account and its tokens. Local data is untouched
  /// (local-first, CLAUDE.md invariant 1); the mailbox ciphertext stays in
  /// the user's cloud for reconnection.
  Future<void> disconnect() async {
    await keyStore.write(_tokensKey, '');
    await keyStore.write(_providerKey, '');
  }

  /// Valid access token for the connected provider, refreshing (and
  /// persisting the rotated set) when stale.
  Future<String> freshAccessToken() async {
    final provider = await connectedProvider();
    final tokens = TokenSet.decode(await keyStore.read(_tokensKey));
    if (provider == null || tokens == null) {
      throw StateError('No cloud account connected');
    }
    if (!tokens.isExpired(_clock.now())) return tokens.accessToken;
    final refresh = tokens.refreshToken;
    if (refresh == null) {
      throw OAuthException('Access token expired and no refresh token held');
    }
    final rotated = await _flow.refresh(provider.oauthConfig!, refresh);
    await keyStore.write(_tokensKey, rotated.encode());
    return rotated.accessToken;
  }

  /// Mailbox store speaking the connected provider's API, or null when no
  /// OAuth account is connected.
  Future<MailboxStore?> mailboxStore() async {
    final provider = await connectedProvider();
    return switch (provider) {
      null || CloudProviderId.icloud => null,
      CloudProviderId.dropbox => DropboxMailboxStore(
        http: _http,
        accessToken: freshAccessToken,
      ),
      CloudProviderId.googleDrive => GoogleDriveMailboxStore(
        http: _http,
        accessToken: freshAccessToken,
      ),
      CloudProviderId.oneDrive => OneDriveMailboxStore(
        http: _http,
        accessToken: freshAccessToken,
      ),
    };
  }
}
