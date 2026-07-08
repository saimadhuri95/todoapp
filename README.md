# Knot

A local-first todo app for **Windows, macOS, Linux, iOS, and Android** with
cross-device sync and alarms - **no central server**. Knot ties your devices
together directly: no account, no cloud backend, your data never leaves your
control. Source-available for reading, evaluation, and contribution;
redistribution requires written permission from `saimadhuri95`.

## Why it's different

- **Your data stays yours.** Every device keeps the full dataset locally
  (SQLite). The app works 100% offline, forever.
- **Serverless sync.** Devices sync directly over your Wi-Fi (peer-to-peer),
  or through a folder on a cloud drive you already use (iCloud, Google Drive,
  Dropbox, Syncthing, etc.). Everything that leaves a device is end-to-end
  encrypted - the cloud provider only ever sees ciphertext.
- **No accounts.** Devices pair with a QR code, like a password manager.
- **Real alarms.** Exact alarms on Android, local notifications on iOS,
  opt-in OS-scheduled alarms on macOS. Windows alarms fire in-app today
  (firing with the app closed needs MSIX packaging, pending); Linux alarms
  planned.

## Status

**v0.1 - feature-complete, locally verified.** Core app, sync engine
(LAN P2P + encrypted cloud-drive mailbox), alarms, and the release pipeline
are implemented, with 234 `flutter test` cases passing locally plus a Windows
`integration_test` smoke pass. CI now also runs the smoke flow on all five
platforms. Built and launched on macOS; iOS builds clean (unsigned).
Remaining: store distribution (needs developer accounts), real-device testing,
and a small polish tail - current state lives in the `RESUME` section of
[TASKS.md](TASKS.md).

See [PLAN.md](PLAN.md) for the plan and [docs/](docs/) for design docs:

- [docs/architecture.md](docs/architecture.md) - stack, data model, invariants
- [docs/sync.md](docs/sync.md) - CRDT merge, pairing, encryption, transports
- [docs/alarms.md](docs/alarms.md) - per-platform alarm behavior
- [docs/testing.md](docs/testing.md) - testing strategy
- [docs/packaging.md](docs/packaging.md) - signing, stores, release pipeline
- [docs/launch.md](docs/launch.md) - store copy, launch sequencing, ASO loop

## Stack

Flutter - Riverpod - SQLite (drift) - hand-rolled per-field LWW CRDT with
hybrid logical clocks ([ADR 0001](docs/decisions/0001-crdt-choice.md)) -
X25519 + XChaCha20-Poly1305 for device pairing and payload encryption.

## System requirements

Minimum supported platform versions (TASKS.md 6.39). These follow the pinned
Flutter toolchain's defaults and the project's deployment targets:

| Platform | Minimum | Set in |
|----------|---------|--------|
| Android  | 7.0 (API 24) | Flutter default `minSdkVersion` (`android/app/build.gradle.kts`) |
| iOS      | 13.0 | `IPHONEOS_DEPLOYMENT_TARGET` (`ios/Runner.xcodeproj`) |
| macOS    | 10.15 Catalina | `MACOSX_DEPLOYMENT_TARGET` (`macos/Runner.xcodeproj`) |
| Windows  | 10 (64-bit) | Flutter desktop baseline |
| Linux    | 64-bit with GTK 3 / glibc 2.28+ | Flutter desktop baseline |

**Old-hardware floor.** The app is local-first and does no background number
crunching, so the practical constraint is RAM for the SQLite working set and
the Flutter engine. The target floor is a ~2 GB-RAM Android device on the
oldest supported OS; the 5k-task performance guard
(`test/perf/large_dataset_test.dart`, see [docs/testing.md](docs/testing.md))
keeps the data layer within budget at that scale. Real-device verification on
low-RAM hardware and the oldest OS builds is still pending (tracked in the
`RESUME` section of [TASKS.md](TASKS.md)); raise these minimums only with an
ADR, since doing so drops users.

## Building

```sh
flutter pub get
flutter run     # -d macos / windows / linux, or a connected mobile device
flutter test --coverage
dart tool/check_coverage.dart --lcov coverage/lcov.info --min 80 --scope lib/data
flutter test integration_test/app_smoke_test.dart -d windows
```

Generated drift code is checked in; after schema changes run
`dart run build_runner build`. Release artifacts are produced by the
[release workflow](.github/workflows/release.yml) on `v*` tags; per-platform
signing and store steps are in [docs/packaging.md](docs/packaging.md).

## License

Knot is source-available under the Knot Source Available License 1.0. You may
read, study, clone, run locally for evaluation, and submit contributions under
the terms in [LICENSE](LICENSE).

Redistribution is not permitted without prior written permission from
`saimadhuri95`. This includes free redistribution, app-store distribution,
package-manager distribution, public mirrors, binaries, hosted offerings,
resale, paid redistribution, and enterprise or commercial use. Contributions
are welcome under the terms in [CONTRIBUTING.md](CONTRIBUTING.md).
