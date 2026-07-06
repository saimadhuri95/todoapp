# Knot

A local-first todo app for **Windows, macOS, Linux, iOS, and Android** with
cross-device sync and alarms — **no central server**. Knot ties your devices
together directly: no account, no cloud backend, your data never leaves your
control. Source-available for noncommercial use under the PolyForm
Noncommercial License 1.0.0.

## Why it's different

- **Your data stays yours.** Every device keeps the full dataset locally
  (SQLite). The app works 100% offline, forever.
- **Serverless sync.** Devices sync directly over your Wi-Fi (peer-to-peer),
  or through a folder on a cloud drive you already use (iCloud, Google Drive,
  Dropbox, Syncthing, …). Everything that leaves a device is end-to-end
  encrypted — the cloud provider only ever sees ciphertext.
- **No accounts.** Devices pair with a QR code, like a password manager.
- **Real alarms.** Exact alarms on Android, local notifications on iOS,
  opt-in OS-scheduled alarms on macOS. Windows alarms fire in-app today
  (firing with the app closed needs MSIX packaging, pending); Linux alarms
  planned.

## Status

**v0.1 — feature-complete, locally verified.** Core app, sync engine
(LAN P2P + encrypted cloud-drive mailbox), alarms, and the release pipeline
are implemented, with 175 tests green in CI. Built and launched on macOS;
iOS builds clean (unsigned). Remaining: store distribution (needs developer
accounts), real-device testing, and a small polish tail — current state
lives in the `RESUME` section of [TASKS.md](TASKS.md).

See [PLAN.md](PLAN.md) for the plan and [docs/](docs/) for design docs:

- [docs/architecture.md](docs/architecture.md) — stack, data model, invariants
- [docs/sync.md](docs/sync.md) — CRDT merge, pairing, encryption, transports
- [docs/alarms.md](docs/alarms.md) — per-platform alarm behavior
- [docs/testing.md](docs/testing.md) — testing strategy
- [docs/packaging.md](docs/packaging.md) — signing, stores, release pipeline

## Stack

Flutter · Riverpod · SQLite (drift) · hand-rolled per-field LWW CRDT with
hybrid logical clocks ([ADR 0001](docs/decisions/0001-crdt-choice.md)) ·
X25519 + XChaCha20-Poly1305 for device pairing and payload encryption.

## Building

```sh
flutter pub get
flutter run     # -d macos / windows / linux, or a connected mobile device
flutter test    # full suite (175 tests)
```

Generated drift code is checked in; after schema changes run
`dart run build_runner build`. Release artifacts are produced by the
[release workflow](.github/workflows/release.yml) on `v*` tags; per-platform
signing and store steps are in [docs/packaging.md](docs/packaging.md).

## License

Knot is licensed under the PolyForm Noncommercial License 1.0.0. You may read,
study, modify, and share the software for noncommercial purposes under the
license terms in [LICENSE](LICENSE).

Commercial use, enterprise deployment, resale, hosted offerings, paid
redistribution, and commercial app-store distribution require a separate
written license from `saimadhuri95`. Contributions are welcome under the terms in
[CONTRIBUTING.md](CONTRIBUTING.md).
