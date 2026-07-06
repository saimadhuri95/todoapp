# Packaging & distribution

## Release pipeline (working today)

Tag a version → GitHub Actions builds and attaches artifacts to a **draft
release** (review, then publish):

```
git tag v0.1.0 && git push origin v0.1.0
```

Artifacts: `knot-linux-x64.tar.gz`, `knot-windows-x64.zip`,
`knot-macos.zip` (unsigned), `knot-android.apk` (debug-signed, sideload
only). iOS has no sideloadable artifact — it ships via TestFlight/App Store
only (below).

## What each platform still needs from the account owner

### Android → Play Store (4.2)
1. Generate an upload keystore (once, keep it safe — losing it means losing
   the Play listing):
   `keytool -genkey -v -keystore ~/knot-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias knot`
2. Create `android/key.properties` (gitignored):
   ```
   storeFile=/Users/<you>/knot-upload.jks
   storePassword=...
   keyAlias=knot
   keyPassword=...
   ```
   Gradle picks it up automatically; without it release builds use the
   debug key.
3. Play Console account ($25 once) → create app `com.sai.knot` → upload
   `flutter build appbundle` output to the internal track.

### iOS → TestFlight/App Store (4.3)
Requires Xcode (installed locally) + Apple Developer Program ($99/yr).
1. Xcode → Runner target → Signing: select your team; bundle id
   `com.sai.knot`.
2. Add the notification entitlements when the alarms phase lands.
3. `flutter build ipa` → upload with Xcode Organizer or `xcrun altool`.

### iOS + macOS: enable the iCloud Drive sync container (3.12)

The app already ships the `com.sai.knot/cloud_folder` method channel and a
"Use iCloud Drive" option in Sync settings. Without the entitlement the
channel returns nil and the UI explains iCloud is unavailable — nothing
breaks. iCloud entitlements are *restricted*: they need a provisioning
profile from the paid Apple Developer account, and adding them to an
ad-hoc-signed local build stops the app launching. So flip them on only
once signing is real:

1. developer.apple.com → Certificates, IDs & Profiles → register iCloud
   container `iCloud.com.sai.knot`; attach it to the `com.sai.knot` app id.
2. Xcode → Runner target → Signing & Capabilities → **+ iCloud** →
   check **iCloud Documents** → select `iCloud.com.sai.knot`. Do this in
   BOTH `ios/Runner.xcworkspace` and `macos/Runner.xcworkspace` (macOS: add
   to both DebugProfile.entitlements and Release.entitlements).
3. Optional (makes the folder visible in the Files app / Finder iCloud
   section): add `NSUbiquitousContainers` to Info.plist with
   `NSUbiquitousContainerIsDocumentScopePublic = YES`; bump the build number
   or the change is ignored.
4. Verify on a signed build: Sync settings → Use iCloud Drive should set
   the mailbox path to `…/Mobile Documents/iCloud~com~sai~knot/Documents`.

While in there, also add **Keychain Sharing** (group `com.sai.knot`) to the
macOS target: it's restricted like iCloud, so today's ad-hoc builds keep the
device identity in a file store fallback instead (`FallbackKeyStore`,
TASKS.md 4.17); with the capability the keychain takes over automatically.

### macOS (4.4)
Same Apple account. Hardened runtime is already the Flutter default.
1. Developer ID Application certificate in Xcode.
2. `flutter build macos --release` → sign → `xcrun notarytool submit` →
   staple → wrap in a dmg (`create-dmg`).
Until then the release zip runs via right-click → Open (Gatekeeper).

### Windows (4.5)
`msix` config can be added to pubspec once a code-signing certificate
exists; unsigned MSIX installs only in developer mode, so the release zip
is the practical channel until a cert is bought (or the app ships via
winget/Store).

### Linux (4.6)
Flatpak manifest in `packaging/flatpak/` (build steps in the manifest
header). Flathub submission: fork flathub/flathub, add the manifest,
open PR — needs the repo owner's GitHub account.

## App Store metadata (4.9–4.11, user decision 2026-07-06)

- **Name (30-char cap, highest search weight):** `Knot – Todo List & Sync`
  (23 chars). Covers "todo list" + "sync"; bare "Knot" wouldn't index.
- **Subtitle (30-char cap, second-highest; must not repeat name words):**
  `Collaborative Task Manager` (26 chars) — adds task/manager/collaborative.
- **Hidden keyword field (100-char cap, comma-separated, no spaces, no words
  already in name/subtitle; Apple auto-combines singles into phrases):**
  `shared,checklist,organizer,p2p,private,group,team,family,planner,grocery,reminders,productivity`
  (95 chars). Re-pruned against the final name/subtitle — no overlaps.
- Enter all three in App Store Connect once the account exists (4.3). The
  keyword field is updatable per release without review, but only alongside
  a new build (4.15).

## Auto-update strategy (4.8)

- **Android/iOS/Mac App Store**: stores handle updates.
- **Windows/Linux/macOS-direct (v1)**: GitHub Releases is the channel;
  the app does not self-update. Revisit post-v1: winget manifest +
  Flathub give effectively automatic updates; Sparkle for the macOS dmg.
