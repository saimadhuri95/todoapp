# ADR 0002: Cloud provider accounts as a mailbox backend (iPhone-first)

- **Status:** accepted (user direction 2026-07-07)
- **Context:** PLAN.md "two transports" decision; extends, does not replace

## Decision

Add **storage-provider accounts** (Dropbox, Google Drive, OneDrive — plus
iCloud Drive via the existing ubiquity container) as a place the encrypted
sync mailbox can live, signed into from an in-app connect screen, and let a
**single un-paired device** use it.

Three parts:

1. **`MailboxStore` seam.** The mailbox protocol (per-device outboxes,
   HLC-sorted changeset files, `vector.bin`) was already storage-agnostic;
   `MailboxTransport` now runs over a small file-store interface.
   `FolderMailboxStore` keeps the original folder behavior (desktop
   pickers, iCloud Drive, Syncthing). Dropbox/Google Drive/OneDrive get
   REST implementations, because on iOS those providers expose **no
   filesystem folder** — their File Provider extensions don't materialize
   remote-only files for background reads, which a sync mailbox needs.
2. **OAuth 2.0 + PKCE (RFC 8252/7636), no SDKs.** Sign-in happens in the
   system browser against the provider the user chose; the custom-scheme
   redirect (`knot://oauth`, or Google's reversed-client-id scheme) comes
   back through an AppDelegate → method-channel hop. Tokens live in the
   keychain. Client ids are build-time `--dart-define`s
   (`KNOT_DROPBOX_CLIENT_ID`, `KNOT_GOOGLE_CLIENT_ID`, `KNOT_MS_CLIENT_ID`);
   without them a provider row shows "setup required"
   (docs/cloud-providers.md has the registration steps).
3. **Solo-device sync.** `buildOrchestrator` no longer requires pairing:
   a configured mailbox (cloud account or folder) creates the group key
   on this device. Pairing later distributes *that* key, so new devices
   join the same mailbox with full history — "connect cloud now, add
   devices whenever" costs nothing extra.

## Invariants check

- **No central server** — intact. The app talks only to the *user's own*
  storage account; there is no Knot-operated endpoint anywhere.
- **Local-first (1)** — intact. Connecting is optional (first-run sheet is
  skippable); everything works offline; disconnect deletes nothing.
- **Ciphertext only (3)** — intact. Stores handle sealed bytes; scopes are
  the narrowest each provider offers (Dropbox app folder, Drive
  `appdata`, Graph `Files.ReadWrite.AppFolder`), so even the token can't
  reach the rest of the user's files.

## Alternatives rejected

- **Provider SDKs / `googleapis` packages:** heavy deps, three different
  auth stacks; PKCE + a ~50-line HTTP wrapper covers all three uniformly
  and stays fake-testable.
- **iOS Files-app folder picking (File Provider) for these providers:**
  works for one-shot pick, but non-materialized files break unattended
  mailbox reads; REST is reliable in the background.
- **Cloud as primary store:** would break local-first; the cloud remains
  a replication target, the SQLite database stays the source of truth.

## Consequences

- OAuth end-to-end flows can't run until the app registrations exist
  (user action, free); everything up to the browser hop is unit-tested.
- Token refresh adds the only long-lived secret outside pairing keys;
  disconnect wipes it.
- LAN P2P and QR pairing are untouched; the "two transports" decision
  becomes "two transports, three mailbox backends".
