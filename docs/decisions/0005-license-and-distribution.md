# 0005 - Source-Available License And Distribution Channels

Date: 2026-07-09
Status: accepted

## Context

Knot was relicensed from MIT to the Knot Source Available License 1.0 after the
project owner clarified the intended boundary: people may read the source,
evaluate it, and contribute back, but they may not redistribute the app or its
source mirrors without written permission. That includes free redistribution,
package-manager publication, app-store uploads, resale, and commercial use.

This creates an intentional tension with the earlier packaging plan for Flathub
and winget. Those channels are public redistribution mechanisms, so they cannot
be treated as community-submittable defaults under the current license.

## Decision

Knot remains source-available, not open source. The repository stays public for
reading, evaluation, issue discussion, and pull requests, but redistribution is
reserved to `saimadhuri95` or to parties with explicit written permission.

Official distribution channels are allowed because they are owner-controlled
publication, not third-party redistribution. That means GitHub Releases, the
mobile app stores, a future Microsoft Store or winget submission, and a future
Flathub submission are valid only when submitted or authorized by
`saimadhuri95`.

The "free-with-privacy" positioning means the app is intended to be usable
without subscriptions, tracking, or a central account. It does not mean anyone
else may repackage or redistribute the app for free.

## Consequences

- Store and launch copy should say "source-available for reading and
  contribution" rather than "open source."
- Flathub and winget remain possible auto-update channels, but they are
  owner-operated release channels. Community mirrors or package submissions
  need written permission first.
- Contributor docs and pull request review can stay friendly to outside
  contributions, while the license continues to block unauthorized mirrors,
  app-store listings, package-manager uploads, and resale.
