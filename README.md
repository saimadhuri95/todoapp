# TodoApp (working title)

A local-first todo app for **Windows, macOS, Linux, iOS, and Android** with
cross-device sync and alarms — **no central server**.

## Why it's different

- **Your data stays yours.** Every device keeps the full dataset locally
  (SQLite). The app works 100% offline, forever.
- **Serverless sync.** Devices sync directly over your Wi-Fi (peer-to-peer),
  or through a folder on a cloud drive you already use (iCloud, Google Drive,
  Dropbox, Syncthing, …). Everything that leaves a device is end-to-end
  encrypted — the cloud provider only ever sees ciphertext.
- **No accounts.** Devices pair with a QR code, like a password manager.
- **Real alarms.** Exact alarms on Android, local notifications on iOS,
  opt-in OS-scheduled alarms on Windows/macOS that fire even with the app
  closed (Linux alarms planned).

## Status

🚧 **Planning stage — no code yet.** See [PLAN.md](PLAN.md) for the plan,
[TASKS.md](TASKS.md) for the task breakdown, and [docs/](docs/) for design docs:

- [docs/architecture.md](docs/architecture.md) — stack, data model, invariants
- [docs/sync.md](docs/sync.md) — CRDT merge, pairing, encryption, transports
- [docs/alarms.md](docs/alarms.md) — per-platform alarm behavior
- [docs/testing.md](docs/testing.md) — testing strategy

## Stack

Flutter · SQLite (drift) · CRDT sync (cr-sqlite or LWW/HLC, spike pending) ·
X25519 + XChaCha20-Poly1305 for device pairing and payload encryption.

## Building

Not yet — Phase 0 scaffolding hasn't started. This section will gain real
instructions once `flutter create` lands.
