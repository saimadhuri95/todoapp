import 'dart:convert';
import 'dart:io';

import '../../core/clock.dart';
import '../sync/device_identity.dart';
import '../sync/mailbox_store.dart';
import 'cloud_http.dart';
import 'cloud_providers.dart';
import 'dropbox_store.dart';
import 'gdrive_store.dart';
import 'oauth.dart';
import 'onedrive_store.dart';
import 'webdav_store.dart';

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
  static const _webdavKey = 'cloud_webdav';

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

  /// WebDAV needs no OAuth (TASKS 8.11, issue #107): server URL +
  /// username/app-password over Basic auth. Probes the server before
  /// saving so bad credentials fail here, not silently at sync time.
  Future<void> connectWebDav({
    required Uri serverUrl,
    required String username,
    required String password,
  }) async {
    if (!serverUrl.isScheme('https') && !serverUrl.isScheme('http')) {
      throw const FormatException('Server URL must be http(s)://…');
    }
    final store = _webdavStore(
      WebDavCredentials(serverUrl, username, password),
    );
    if (!await store.probe()) {
      throw const HttpException(
        'Server rejected the credentials or is not a WebDAV server',
      );
    }
    await keyStore.write(
      _webdavKey,
      WebDavCredentials(serverUrl, username, password).encode(),
    );
    await keyStore.write(_providerKey, CloudProviderId.webdav.name);
  }

  /// Forgets the account and its tokens. Local data is untouched
  /// (local-first, CLAUDE.md invariant 1); the mailbox ciphertext stays in
  /// the user's cloud for reconnection.
  Future<void> disconnect() async {
    await keyStore.write(_tokensKey, '');
    await keyStore.write(_webdavKey, '');
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
  /// API-backed account is connected (iCloud goes through the folder path).
  Future<MailboxStore?> mailboxStore() async {
    final provider = await connectedProvider();
    switch (provider) {
      case null || CloudProviderId.icloud:
        return null;
      case CloudProviderId.webdav:
        final creds = WebDavCredentials.decode(await keyStore.read(_webdavKey));
        // Provider set but credentials gone (keychain wipe): treat as
        // disconnected rather than failing every sync pass.
        return creds == null ? null : _webdavStore(creds);
      case CloudProviderId.dropbox:
        return DropboxMailboxStore(http: _http, accessToken: freshAccessToken);
      case CloudProviderId.googleDrive:
        return GoogleDriveMailboxStore(
          http: _http,
          accessToken: freshAccessToken,
        );
      case CloudProviderId.oneDrive:
        return OneDriveMailboxStore(http: _http, accessToken: freshAccessToken);
    }
  }

  WebDavMailboxStore _webdavStore(WebDavCredentials creds) {
    // Slash-terminate before resolving, or `resolve` would replace the
    // last path segment ("…/dav/alice" + knot-mailbox → "…/dav/knot-mailbox").
    final url = creds.serverUrl;
    final base = url.path.endsWith('/')
        ? url
        : url.replace(path: '${url.path}/');
    return WebDavMailboxStore(
      http: _http,
      // Rooted in a dedicated collection so Knot never litters the
      // user's tree.
      baseUrl: base.resolve('knot-mailbox/'),
      username: creds.username,
      password: creds.password,
    );
  }
}

/// WebDAV account credentials; serialized as JSON into the keychain
/// beside the OAuth tokens (never anywhere else).
class WebDavCredentials {
  const WebDavCredentials(this.serverUrl, this.username, this.password);

  final Uri serverUrl;
  final String username;
  final String password;

  String encode() => jsonEncode({
    'url': serverUrl.toString(),
    'user': username,
    'pass': password,
  });

  static WebDavCredentials? decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return WebDavCredentials(
        Uri.parse(map['url'] as String),
        map['user'] as String,
        map['pass'] as String,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
