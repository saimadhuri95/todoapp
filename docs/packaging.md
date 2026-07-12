# Packaging & distribution

## Release pipeline (working today)

Tag a version -> GitHub Actions builds and attaches artifacts to a **draft
release** (review, then publish):

```
git tag v0.1.0 && git push origin v0.1.0
```

Artifacts: `knot-linux-x64.tar.gz`, `knot-windows-x64.zip`,
`knot-macos.zip` (unsigned), `knot-android.apk` (debug-signed, sideload
only). iOS has no sideloadable artifact - it ships via TestFlight/App Store
only (below).

## Distribution policy

Knot is source-available, not open source. The source is public for reading,
evaluation, and contributions, but redistribution requires written permission
from `saimadhuri95`; see [ADR 0005](decisions/0005-license-and-distribution.md)
and [LICENSE](../LICENSE).

That means Flathub, winget, Microsoft Store, app-store, and package-manager
submissions are allowed only as owner-operated or explicitly authorized release
channels. Do not treat the Flatpak or future winget manifests as permission for
third-party mirrors or community package uploads.

## What each platform still needs from the account owner

### Android -> Play Store (4.2)

1. Generate an upload keystore (once, keep it safe - losing it means losing
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
3. Play Console account ($25 once) -> create app `com.sai.knot` -> upload
   `flutter build appbundle` output to the internal track.
   Use the Google Play title, short description, and full description from
   [docs/launch.md](launch.md).

### iOS -> TestFlight/App Store (4.3)

Requires Xcode (installed locally) + Apple Developer Program ($99/yr).

1. Xcode -> Runner target -> Signing: select your team; bundle id
   `com.sai.knot`.
2. Add the notification entitlements when the alarms phase lands.
3. `flutter build ipa` -> upload with Xcode Organizer or `xcrun altool`.

### iOS + macOS: enable the iCloud Drive sync container (3.12)

The app already ships the `com.sai.knot/cloud_folder` method channel and a
"Use iCloud Drive" option in Sync settings. Without the entitlement the
channel returns nil and the UI explains iCloud is unavailable - nothing
breaks. iCloud entitlements are *restricted*: they need a provisioning
profile from the paid Apple Developer account, and adding them to an
ad-hoc-signed local build stops the app launching. So flip them on only
once signing is real:

1. developer.apple.com -> Certificates, IDs & Profiles -> register iCloud
   container `iCloud.com.sai.knot`; attach it to the `com.sai.knot` app id.
2. Xcode -> Runner target -> Signing & Capabilities -> **+ iCloud** ->
   check **iCloud Documents** -> select `iCloud.com.sai.knot`. Do this in
   BOTH `ios/Runner.xcworkspace` and `macos/Runner.xcworkspace` (macOS: add
   to both DebugProfile.entitlements and Release.entitlements).
3. Optional (makes the folder visible in the Files app / Finder iCloud
   section): add `NSUbiquitousContainers` to Info.plist with
   `NSUbiquitousContainerIsDocumentScopePublic = YES`; bump the build number
   or the change is ignored.
4. Verify on a signed build: Sync settings -> Use iCloud Drive should set
   the mailbox path to `.../Mobile Documents/iCloud~com~sai~knot/Documents`.

While in there, also add **Keychain Sharing** (group `com.sai.knot`) to the
macOS target: it's restricted like iCloud, so today's ad-hoc builds keep the
device identity in a file store fallback instead (`FallbackKeyStore`,
TASKS.md 4.17); with the capability the keychain takes over automatically.

### macOS (4.4)

Same Apple account. Hardened runtime is already the Flutter default.

1. Developer ID Application certificate in Xcode.
2. `flutter build macos --release` -> sign -> `xcrun notarytool submit` ->
   staple -> wrap in a dmg (`create-dmg`).

Until then the release zip runs via right-click -> Open (Gatekeeper).

### Windows (4.5)

`msix` config can be added to pubspec once a code-signing certificate
exists; unsigned MSIX installs only in developer mode, so the release zip
is the practical channel until a cert is bought (or the app ships via
winget/Store).

### Linux (4.6)

Flatpak manifest in `packaging/flatpak/` (build steps in the manifest
header). Flathub submission is owner-controlled under the project license:
fork flathub/flathub, add the manifest, open PR - using the repo owner's
GitHub account or another account with written permission.

## App Store metadata (4.9-4.11, user decision 2026-07-06)

- **Name (30-char cap, highest search weight):** `Knot - Todo List & Sync`
  (23 chars). Covers "todo list" + "sync"; bare "Knot" would not index well.
- **Subtitle (30-char cap, second-highest; must not repeat name words):**
  `Collaborative Task Manager` (26 chars) - adds task/manager/collaborative.
- **Hidden keyword field (100-char cap, comma-separated, no spaces, no words
  already in name/subtitle; Apple auto-combines singles into phrases):**
  `shared,checklist,organizer,p2p,private,group,team,family,planner,grocery,reminders,productivity`
  (95 chars). Re-pruned against the final name/subtitle - no overlaps.
- Enter all three in App Store Connect once the account exists (4.3). The
  keyword field is updatable per release without review, but only alongside
  a new build (4.15).
- Google Play metadata, launch sequencing, and the per-release ASO loop live
  in [docs/launch.md](launch.md).
- **Disclaimer (TASKS.md 6.57):** Simple mode + nag reminders make Knot
  usable as a caregiver's reminder tool, but it is **not a medical device**
  and reminders are not a substitute for medical supervision. Both store
  listings' full descriptions carry this line verbatim so it isn't only
  in-app copy.

## Auto-update strategy (4.8)

- **Android/iOS/Mac App Store**: stores handle updates.
- **Windows/Linux/macOS-direct (v1)**: GitHub Releases is the channel;
  the app does not self-update. Revisit post-v1: an owner-submitted winget
  manifest + owner-submitted Flathub listing give effectively automatic
  updates; Sparkle for the macOS dmg.
