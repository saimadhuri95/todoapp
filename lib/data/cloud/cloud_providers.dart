import 'oauth.dart';

/// Storage providers the connect screen offers. iCloud Drive needs no
/// OAuth (the OS account + ubiquity container do the work); WebDAV needs
/// no OAuth either (server URL + Basic auth, TASKS 8.11); the other
/// three are OAuth/PKCE + REST ([MailboxStore] impls in this folder).
enum CloudProviderId { icloud, webdav, dropbox, googleDrive, oneDrive }

/// OAuth client ids are *app registrations the developer creates* in each
/// provider's console (see docs/cloud-providers.md) and are injected at
/// build time — they are identifiers, not secrets, but ours haven't been
/// registered yet, so default-empty keeps those rows in "setup required"
/// until then. PKCE means no client secret exists at all.
const dropboxClientId = String.fromEnvironment('KNOT_DROPBOX_CLIENT_ID');
const googleClientId = String.fromEnvironment('KNOT_GOOGLE_CLIENT_ID');
const microsoftClientId = String.fromEnvironment('KNOT_MS_CLIENT_ID');

/// Custom-scheme redirect for Dropbox and Microsoft. Registered in
/// ios/Runner/Info.plist and handled by OAuthCallbackChannel.
const knotRedirect = 'knot://oauth';

extension CloudProviderInfo on CloudProviderId {
  String get displayName => switch (this) {
    CloudProviderId.icloud => 'iCloud Drive',
    CloudProviderId.webdav => 'WebDAV',
    CloudProviderId.dropbox => 'Dropbox',
    CloudProviderId.googleDrive => 'Google Drive',
    CloudProviderId.oneDrive => 'OneDrive',
  };

  bool get needsOAuth => switch (this) {
    CloudProviderId.icloud || CloudProviderId.webdav => false,
    _ => true,
  };

  /// null for iCloud and WebDAV (no OAuth); `isConfigured == false` when
  /// the client id hasn't been registered/injected yet.
  OAuthConfig? get oauthConfig => switch (this) {
    CloudProviderId.icloud || CloudProviderId.webdav => null,
    CloudProviderId.dropbox => OAuthConfig(
      authorizationEndpoint: Uri.parse(
        'https://www.dropbox.com/oauth2/authorize',
      ),
      tokenEndpoint: Uri.parse('https://api.dropboxapi.com/oauth2/token'),
      clientId: dropboxClientId,
      redirectUri: Uri.parse(knotRedirect),
      // App-folder scoped app: these are the narrowest content scopes.
      scopes: const [
        'files.metadata.read',
        'files.content.read',
        'files.content.write',
      ],
      // Without this Dropbox issues no refresh token.
      extraAuthParams: const {'token_access_type': 'offline'},
    ),
    CloudProviderId.googleDrive => OAuthConfig(
      authorizationEndpoint: Uri.parse(
        'https://accounts.google.com/o/oauth2/v2/auth',
      ),
      tokenEndpoint: Uri.parse('https://oauth2.googleapis.com/token'),
      clientId: googleClientId,
      // Google iOS clients must redirect to the reversed client id scheme;
      // that scheme also has to be added to Info.plist at registration
      // time (docs/cloud-providers.md).
      redirectUri: Uri.parse('${_reverseDns(googleClientId)}:/oauth2redirect'),
      // appDataFolder only: Knot can see its own hidden app data, nothing
      // else in the user's Drive.
      scopes: const ['https://www.googleapis.com/auth/drive.appdata'],
    ),
    CloudProviderId.oneDrive => OAuthConfig(
      authorizationEndpoint: Uri.parse(
        'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
      ),
      tokenEndpoint: Uri.parse(
        'https://login.microsoftonline.com/common/oauth2/v2.0/token',
      ),
      clientId: microsoftClientId,
      redirectUri: Uri.parse(knotRedirect),
      // App-folder only + offline_access for refresh tokens.
      scopes: const ['Files.ReadWrite.AppFolder', 'offline_access'],
    ),
  };
}

/// `123-abc.apps.googleusercontent.com` → `com.googleusercontent.apps.123-abc`.
/// A placeholder keeps the Uri parseable while no client id is injected
/// (the row shows "setup required" and never reaches the browser).
String _reverseDns(String clientId) =>
    clientId.isEmpty ? 'unconfigured' : clientId.split('.').reversed.join('.');
