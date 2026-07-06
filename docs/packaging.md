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

## Auto-update strategy (4.8)

- **Android/iOS/Mac App Store**: stores handle updates.
- **Windows/Linux/macOS-direct (v1)**: GitHub Releases is the channel;
  the app does not self-update. Revisit post-v1: winget manifest +
  Flathub give effectively automatic updates; Sparkle for the macOS dmg.
