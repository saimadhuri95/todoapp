# Beta distribution

How beta builds reach real testers' own devices for the five-platform beta
round (#29). A device cloud (Firebase Test Lab, see
`docs/decisions/0006-device-testing-cloud.md`) runs *our* tests on rented
hardware; it does **not** put the app in front of human testers. That is what
these channels are for.

All channels here are **owner-operated release channels**, consistent with the
source-available license (ADR 0005): the owner publishes builds, testers
receive them; this is not third-party redistribution.

## Channels

| Platform | Channel | Account needed | Status |
|---|---|---|---|
| Android | Firebase App Distribution | Firebase project + service account | wired (`beta-distribute.yml`), owner-gated |
| Android | Google Play internal testing | Play Console (one-time $25) | future; needs the account |
| iOS | TestFlight internal | Apple Developer Program | blocked on #21 |
| Windows / macOS / Linux | GitHub Releases (draft) artifacts | none | already shipped by `release.yml` |

The recommended starting point needs no store accounts: **Firebase App
Distribution** for Android + **GitHub Releases** for the three desktop targets.
iOS and Play internal come online once the accounts in #21 / #103 exist.

## Android — Firebase App Distribution

`.github/workflows/beta-distribute.yml` builds a release APK and uploads it to
App Distribution. It is `workflow_dispatch`-only and stays inert until these
repository secrets are set:

- `FIREBASE_APP_ID` — the Android app id from the Firebase console
  (e.g. `1:1234567890:android:abc123`).
- `FIREBASE_SA_KEY` — a service-account JSON key with the **Firebase App
  Distribution Admin** role.

To ship a beta: Actions tab -> *Beta distribute* -> Run workflow, choosing the
tester `groups` and release `notes`. Create tester groups (e.g. `internal`) in
the Firebase console first.

Until the secrets exist the job logs a skip notice and no-ops, so it never
blocks other CI.

## Desktop — GitHub Releases

`release.yml` already builds Linux/Windows/macOS bundles on a `v*` tag and
attaches them to a **draft** GitHub Release. For a beta, tag a pre-release
(e.g. `v0.1.0-beta.1`), let the workflow attach the artifacts, then publish the
draft as a pre-release and share the link with testers.

## iOS — TestFlight (blocked)

TestFlight needs an Apple Developer Program membership and an App Store Connect
record — tracked in #21. Once that exists, add a `distribute-ios` job that
builds a signed `.ipa` and uploads via `xcrun altool` / `upload-testflight`.
Until then, iOS beta coverage comes from Firebase Test Lab device runs, not from
testers' own iPhones.
