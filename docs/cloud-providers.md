# Cloud provider setup (Dropbox / Google Drive / OneDrive)

Knot signs into storage providers with OAuth 2.0 + PKCE — no client
secret, no server, no SDKs (ADR 0003). Each provider needs a **free app
registration** owned by the developer; its *client id* (not a secret) is
baked into the build with `--dart-define`. Until then the provider's row
in Settings → Cloud storage shows "setup required".

iCloud Drive needs none of this — it uses the device's iCloud account and
the app's ubiquity container (requires the iCloud entitlement, see
docs/packaging.md).

What lands in the user's cloud is the standard sync mailbox: XChaCha20-
Poly1305 ciphertext only (CLAUDE.md invariant 3), inside an app-scoped
folder the token cannot escape.

## Build flags

```sh
flutter build ios \
  --dart-define=KNOT_DROPBOX_CLIENT_ID=... \
  --dart-define=KNOT_GOOGLE_CLIENT_ID=...apps.googleusercontent.com \
  --dart-define=KNOT_MS_CLIENT_ID=...
```

## Dropbox

1. <https://www.dropbox.com/developers/apps> → Create app → **Scoped
   access** → **App folder** (Knot only ever sees `Apps/Knot/`).
2. Permissions tab: enable `files.metadata.read`, `files.content.read`,
   `files.content.write`.
3. Settings tab → Redirect URIs: add `knot://oauth`.
4. The *App key* is `KNOT_DROPBOX_CLIENT_ID`.

## Google Drive

1. <https://console.cloud.google.com> → new project → enable the
   **Google Drive API**.
2. OAuth consent screen: external, scope
   `https://www.googleapis.com/auth/drive.appdata` (hidden app data only).
3. Credentials → OAuth client ID → type **iOS**, bundle id `com.sai.knot`.
4. The client id is `KNOT_GOOGLE_CLIENT_ID`. Google redirects to the
   *reversed* client id scheme, so also add it to
   `ios/Runner/Info.plist` under the existing `CFBundleURLTypes` entry:
   `com.googleusercontent.apps.<id-prefix>` (Knot derives the redirect
   URI automatically; only the plist entry is manual).

## OneDrive

1. <https://portal.azure.com> → Microsoft Entra ID → App registrations →
   New. Supported accounts: personal + work/school.
2. Authentication → Add platform → **Mobile and desktop applications** →
   custom redirect URI `knot://oauth`.
3. API permissions: Microsoft Graph → delegated →
   `Files.ReadWrite.AppFolder`, `offline_access`, `User.Read`.
4. The *Application (client) ID* is `KNOT_MS_CLIENT_ID`.

## How sign-in flows through the code

`CloudConnectScreen` → `CloudAccountService.connect` → `PkceFlow.begin`
(browser opens) → user approves → OS delivers `knot://oauth?...` →
`AppDelegate` forwards it over the `com.sai.knot/oauth_callback` channel →
`OAuthCallbackChannel.waitForRedirect` resumes → `PkceFlow.finish`
exchanges the code → tokens land in the keychain. Sync passes then use
`CloudAccountService.mailboxStore()` (a per-provider `MailboxStore`) with
transparent token refresh.

## Android and desktop redirects

- Android registers `knot://oauth` in `AndroidManifest.xml`; `MainActivity`
  forwards matching intents to `OAuthCallbackChannel`.
- iOS keeps the same custom-scheme channel via `AppDelegate`.
- macOS, Windows, and Linux use a local loopback receiver:
  `http://127.0.0.1:<ephemeral>/oauth`. This follows RFC 8252 and avoids
  unreliable desktop custom-scheme registration.

For provider consoles that require exact redirect entries, keep
`knot://oauth` for mobile and add the loopback pattern supported by that
provider for desktop/native app OAuth.

## Shared group folders

Dropbox personal sync should stay on the app-folder scope above. When a user
creates or joins a Dropbox-backed sharing group, request incremental consent
for the broader shared-folder file scopes, have the user mount the shared
folder in Dropbox, and store the device-local group ref as
`CloudAccountRef(accountId: "...", rootPath: "/Shared Folder/Knot").encode()`.
The Dropbox ACL only gets members to the same physical folder; the group key
remains the security boundary for todo contents.

iCloud-backed groups use the existing iCloud Drive folder backend. Knot can
open the platform sharing surface from Sync settings when a folder is
configured. If the OS refuses to present one, use the manual fallback: open
Files/Finder, long-press or right-click the group folder, and share it with
the other Apple ID.
