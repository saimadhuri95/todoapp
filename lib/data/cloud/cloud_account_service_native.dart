import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../db/database.dart';
import '../sync/device_identity.dart';
import '../sync/mailbox_store.dart';
import 'cloud_http.dart';
import 'cloud_providers.dart';
import 'dropbox_store.dart';
import 'gdrive_store.dart';
import 'oauth.dart';
import 'onedrive_store.dart';
import 'webdav_store.dart';

/// One signed-in storage account (TASKS 8.4, ADR 0004). Several can be
/// connected at once — including two on the same provider (work +
/// personal Dropbox): identity is the opaque [id], not the provider.
class CloudAccount {
  const CloudAccount({
    required this.id,
    required this.provider,
    required this.label,
  });

  final String id;
  final CloudProviderId provider;

  /// Human-readable handle (server host for WebDAV; provider name until
  /// 7.9 fetches real display names).
  final String label;

  Map<String, Object?> toJson() => {
    'id': id,
    'provider': provider.name,
    'label': label,
  };

  static CloudAccount? fromJson(Map<String, dynamic> map) {
    final provider = CloudProviderId.values.asNameMap()[map['provider']];
    if (provider == null) return null;
    return CloudAccount(
      id: map['id'] as String,
      provider: provider,
      label: map['label'] as String? ?? provider.displayName,
    );
  }
}

/// Signed-in storage accounts (TASKS 8.4): the registry lives in the
/// keychain as one JSON list; each account's secrets live beside it under
/// namespaced keys (`cloud_tokens:<id>` / `cloud_webdav:<id>`), so
/// removing an account removes exactly its credentials. iCloud Drive is
/// *not* managed here — it needs no tokens; connecting it points the
/// mailbox-folder path at the ubiquity container.
///
/// The **primary** account is the one backing the personal mailbox
/// (pre-groups behavior, ADR 0003); sharing groups reference accounts by
/// id via `sync_groups.local_account_ref` (8.2), which blocks removal
/// while in use.
class CloudAccountService {
  CloudAccountService({
    required this.keyStore,
    required CloudHttp http,
    required Clock clock,
    this.db,
  }) : _http = http,
       _flow = PkceFlow(http: http, clock: clock),
       _clock = clock;

  final KeyStore keyStore;

  /// For the group-reference guard on [removeAccount]; optional so pure
  /// token tests don't need a database.
  final AppDatabase? db;

  final CloudHttp _http;
  final PkceFlow _flow;
  final Clock _clock;

  static const _uuid = Uuid();

  static const _accountsKey = 'cloud_accounts';
  static const _primaryKey = 'cloud_primary_account';

  // Pre-8.4 single-account keys, migrated on first read.
  static const _legacyProviderKey = 'cloud_provider';
  static const _legacyTokensKey = 'cloud_tokens';
  static const _legacyWebdavKey = 'cloud_webdav';
  static const _legacyId = 'legacy';

  static String _tokensKey(String accountId) => 'cloud_tokens:$accountId';
  static String _webdavKey(String accountId) => 'cloud_webdav:$accountId';

  /// All signed-in accounts. Migrates the pre-8.4 single-account keys
  /// into the registry on first call, so existing installs keep their
  /// connection without re-authenticating.
  Future<List<CloudAccount>> accounts() async {
    await _migrateLegacy();
    final raw = await keyStore.read(_accountsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [
        for (final entry in jsonDecode(raw) as List<dynamic>)
          ?CloudAccount.fromJson(entry as Map<String, dynamic>),
      ];
    } on FormatException {
      return const [];
    }
  }

  /// The account backing the personal mailbox, or null.
  Future<CloudAccount?> primaryAccount() async {
    final all = await accounts();
    if (all.isEmpty) return null;
    final id = await keyStore.read(_primaryKey);
    for (final account in all) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// Back-compat surface (main.dart seeding, connect screen state):
  /// the primary account's provider.
  Future<CloudProviderId?> connectedProvider() async =>
      (await primaryAccount())?.provider;

  /// Runs the PKCE dance for [id] and registers the account (also as
  /// primary — connecting from the connect screen keeps its pre-groups
  /// meaning). [authenticate] is the interactive leg: open the browser at
  /// the given URL, complete with the redirect URI the provider sends
  /// back (OAuthCallbackChannel on iOS).
  Future<CloudAccount> connect(
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
    final account = CloudAccount(
      id: _uuid.v7(),
      provider: id,
      label: id.displayName,
    );
    await keyStore.write(_tokensKey(account.id), tokens.encode());
    await _register(account);
    return account;
  }

  /// WebDAV needs no OAuth (TASKS 8.11): server URL + username/
  /// app-password over Basic auth. Probes the server before saving so bad
  /// credentials fail here, not silently at sync time.
  Future<CloudAccount> connectWebDav({
    required Uri serverUrl,
    required String username,
    required String password,
  }) async {
    if (!serverUrl.isScheme('https') && !serverUrl.isScheme('http')) {
      throw const FormatException('Server URL must be http(s)://…');
    }
    final creds = WebDavCredentials(serverUrl, username, password);
    if (!await _webdavStore(creds).probe()) {
      throw const HttpException(
        'Server rejected the credentials or is not a WebDAV server',
      );
    }
    final account = CloudAccount(
      id: _uuid.v7(),
      provider: CloudProviderId.webdav,
      label: serverUrl.host,
    );
    await keyStore.write(_webdavKey(account.id), creds.encode());
    await _register(account);
    return account;
  }

  /// Removes one account and exactly its credentials. Refused while a
  /// sharing group uses it (`sync_groups.local_account_ref`, 8.2) — the
  /// group must be left/re-pointed first. Local data is untouched
  /// (invariant 1); mailbox ciphertext stays in the cloud.
  Future<void> removeAccount(String accountId) async {
    final database = db;
    if (database != null) {
      final using =
          await (database.syncGroups.select()..where(
                (g) =>
                    g.localAccountRef.equals(accountId) &
                    g.deleted.equals(false),
              ))
              .get();
      if (using.isNotEmpty) {
        throw StateError(
          'Account is used by group "${using.first.name}" — leave or '
          're-point the group first',
        );
      }
    }
    final remaining = [
      for (final account in await accounts())
        if (account.id != accountId) account,
    ];
    await keyStore.write(
      _accountsKey,
      jsonEncode([for (final a in remaining) a.toJson()]),
    );
    await keyStore.write(_tokensKey(accountId), '');
    await keyStore.write(_webdavKey(accountId), '');
    if (await keyStore.read(_primaryKey) == accountId) {
      await keyStore.write(_primaryKey, '');
    }
  }

  /// Back-compat: disconnecting from the connect screen removes the
  /// primary account.
  Future<void> disconnect() async {
    final primary = await primaryAccount();
    if (primary != null) await removeAccount(primary.id);
  }

  /// Valid access token for [accountId] (default: primary), refreshing —
  /// and persisting the rotated set — when stale. Refresh state is fully
  /// per-account: two accounts on one provider never share tokens.
  Future<String> freshAccessToken([String? accountId]) async {
    final account = accountId == null
        ? await primaryAccount()
        : await _byId(accountId);
    if (account == null) throw StateError('No cloud account connected');
    final tokens = TokenSet.decode(await keyStore.read(_tokensKey(account.id)));
    if (tokens == null) throw StateError('No tokens for ${account.label}');
    if (!tokens.isExpired(_clock.now())) return tokens.accessToken;
    final refresh = tokens.refreshToken;
    if (refresh == null) {
      throw OAuthException('Access token expired and no refresh token held');
    }
    final rotated = await _flow.refresh(account.provider.oauthConfig!, refresh);
    await keyStore.write(_tokensKey(account.id), rotated.encode());
    return rotated.accessToken;
  }

  /// Mailbox store for [accountId] (default: the primary account), or
  /// null when none/iCloud (which goes through the folder path).
  Future<MailboxStore?> mailboxStore({String? accountId}) async {
    final account = accountId == null
        ? await primaryAccount()
        : await _byId(accountId);
    switch (account?.provider) {
      case null || CloudProviderId.icloud:
        return null;
      case CloudProviderId.webdav:
        final creds = WebDavCredentials.decode(
          await keyStore.read(_webdavKey(account!.id)),
        );
        // Registry entry without credentials (keychain wipe): treat as
        // disconnected rather than failing every sync pass.
        return creds == null ? null : _webdavStore(creds);
      case CloudProviderId.dropbox:
        return DropboxMailboxStore(
          http: _http,
          accessToken: () => freshAccessToken(account!.id),
        );
      case CloudProviderId.googleDrive:
        return GoogleDriveMailboxStore(
          http: _http,
          accessToken: () => freshAccessToken(account!.id),
        );
      case CloudProviderId.oneDrive:
        return OneDriveMailboxStore(
          http: _http,
          accessToken: () => freshAccessToken(account!.id),
        );
    }
  }

  Future<CloudAccount?> _byId(String id) async {
    for (final account in await accounts()) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// Adds to the registry and makes it primary (the connect screen's
  /// single-account semantics; 8.8's wizard will register without
  /// switching primary).
  Future<void> _register(CloudAccount account) async {
    final all = [...await accounts(), account];
    await keyStore.write(
      _accountsKey,
      jsonEncode([for (final a in all) a.toJson()]),
    );
    await keyStore.write(_primaryKey, account.id);
  }

  /// Pre-8.4 installs kept a single provider + secrets under fixed keys;
  /// fold them into the registry once, preserving the connection.
  Future<void> _migrateLegacy() async {
    final providerName = await keyStore.read(_legacyProviderKey);
    if (providerName == null || providerName.isEmpty) return;
    final provider = CloudProviderId.values.asNameMap()[providerName];
    await keyStore.write(_legacyProviderKey, '');
    if (provider == null) return;

    final webdav = await keyStore.read(_legacyWebdavKey);
    final tokens = await keyStore.read(_legacyTokensKey);
    final account = CloudAccount(
      id: _legacyId,
      provider: provider,
      label: provider == CloudProviderId.webdav
          ? (WebDavCredentials.decode(webdav)?.serverUrl.host ??
                provider.displayName)
          : provider.displayName,
    );
    if (webdav != null && webdav.isNotEmpty) {
      await keyStore.write(_webdavKey(_legacyId), webdav);
      await keyStore.write(_legacyWebdavKey, '');
    }
    if (tokens != null && tokens.isNotEmpty) {
      await keyStore.write(_tokensKey(_legacyId), tokens);
      await keyStore.write(_legacyTokensKey, '');
    }
    final raw = await keyStore.read(_accountsKey);
    final existing = (raw == null || raw.isEmpty)
        ? <CloudAccount>[]
        : [
            for (final entry in jsonDecode(raw) as List<dynamic>)
              ?CloudAccount.fromJson(entry as Map<String, dynamic>),
          ];
    await keyStore.write(
      _accountsKey,
      jsonEncode([
        for (final a in [...existing, account]) a.toJson(),
      ]),
    );
    if ((await keyStore.read(_primaryKey) ?? '').isEmpty) {
      await keyStore.write(_primaryKey, account.id);
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
