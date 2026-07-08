# ADR 0004: Sharing groups — per-list sync scopes over multiple clouds

- **Status:** accepted (user direction 2026-07-08); subsumes TASKS.md 6.28
- **Builds on:** ADR 0003 (cloud provider accounts), docs/sync.md

## The user story this serves

> I have local todo lists. My wife and I both use iPhones — we share a
> "Family" list through iCloud. My friend isn't in the Apple ecosystem —
> we share a "Friends" list through Dropbox. All three live in my one app:
> Local, Family Group on iCloud, Friend Group on Dropbox.

## Decision

Introduce **sync groups**. A group binds together:

| Part | Meaning |
|---|---|
| `id`, `name` | uuid + display name ("Family", "Friends") |
| **backend** | where its mailbox lives: iCloud Drive folder, provider account (Dropbox/GDrive/OneDrive) + folder, or plain local folder |
| **group key** | per-group XChaCha20-Poly1305 key in the keychain — the real security boundary |
| **members** | devices that hold the key (joined via QR invite) |
| **lists** | the todo lists assigned to it |

Rules:

1. **Local is the default and needs nothing.** A list with no group syncs
   nowhere (until assigned); the app is fully usable with zero groups
   (invariant 1). "Local only" is not a mode — it's the absence of groups.
2. **A device can hold many groups at once**, each with its own backend,
   key, mailbox, and cursors. Family-on-iCloud and Friends-on-Dropbox
   coexist; sync passes visit every configured group.
3. **Scoped changesets (was 6.28):** a group's mailbox carries only writes
   for its lists (todos join via `listId`; the list row itself included).
   Version vectors and cursors are computed per group.
4. **Joining = becoming a peer of someone else's storage.** The invite QR
   (existing X25519 pairing handshake) carries `{groupId, name, groupKey,
   backend hint}`. Storage access itself is granted in the provider
   (iCloud shared folder / Dropbox shared folder) — the cloud ACL is
   coarse plumbing; the group key is the boundary. A member removed from
   the group triggers key rotation (existing flow, now per group); stale
   folder access sees only ciphertext.
5. **Members bring their own account.** For the Dropbox group, each member
   signs into *their own* Dropbox; the shared folder is mounted into both.
   Nobody shares credentials, ever.
6. **Multiple accounts per provider are allowed** (work + personal
   Dropbox): accounts are keyed `(provider, accountId)` with keychain
   tokens namespaced per account; a group references an account id.

## What changes where

- **Schema (v+1):** `sync_groups` table (synced *within* its own group,
  LWW like everything else); `todo_lists.groupId` nullable FK (null =
  local); `devices`/membership rows scoped per group; `sync_log` peer keys
  namespaced `group:<gid>:mailbox:<peer>`.
- **Engine:** `changesFor(vector, {groupId})` filters writes through
  rowId → list → group; the convergence property suite runs per scope and
  across group moves.
- **Moving a list between groups:** republished as a snapshot into the new
  group's mailbox. Removal is not retroactive — past members may retain
  history they already received (same truth as any share revocation;
  documented in UI copy).
- **Accounts:** `CloudAccountService` holds a *list* of accounts, not one.
- **Orchestrator:** one `MailboxTransport` per group per pass (own store,
  own key, own cursors); report and health aggregate per group.
- **Dropbox scopes:** personal mailbox keeps the app folder. Shared groups
  need the shared-folder mount, so creating/joining a Dropbox group asks
  for the broader file scopes via **incremental consent** — never up
  front.
- **iCloud sharing:** `UICloudSharingController` behind the existing
  cloud-folder channel; manual Files-app folder sharing is the documented
  fallback until the entitlement/dev-account work lands.

## UI (design)

- **Drawer:** lists grouped under headers — *On this iPhone*, then one
  header per group with a people icon + provider glyph. Shared lists wear
  a small badge.
- **Settings → Sharing & storage** (evolves the ADR 0003 connect screen):
  - *Your groups:* Local (always, first), then a card per group — name,
    provider chip, member count, list count; actions: invite (QR), manage
    lists, leave/delete.
  - *New group* wizard: name → pick backend → sign in if needed (or reuse
    an account) → pick/create lists → show invite QR.
  - *Join group:* scan invite → sign into the matching provider if needed
    → connected.
  - *Accounts:* every signed-in account (provider + label), add/remove.
- **List editor / new list:** a "Sync" selector — `Local only` (default) /
  each group by name.
- The first-run sheet keeps its two choices; "Also in my cloud" now lands
  on Sharing & storage.

## Invariants check

No central server (members talk to *their* providers only); local-first
(groups optional, local default); ciphertext-only mailboxes (per-group
keys; provider ACLs are not trusted); tombstone deletes unchanged; merge
idempotence must additionally hold *per scope* — that's the new gate.

## Alternatives rejected

- **One global group key covering everything (ADR 0003 status quo):**
  cannot express "wife sees Family but not my private lists".
- **Sharing by copying lists into the other person's store:** two sources
  of truth, merge hell; scoped changesets keep one CRDT history per list.
- **Provider-native collaboration APIs (CloudKit sharing, Dropbox Paper):**
  server-flavored, per-provider data models, breaks the one-mailbox-format
  design and the no-server rule.
