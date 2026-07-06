# 0001 — Hand-rolled per-field LWW CRDT (not cr-sqlite)

Date: 2026-07-05
Status: accepted

## Context

PLAN.md fixed the sync *semantics* (per-field last-writer-wins with HLC
timestamps and tombstones) but left the *implementation* open: cr-sqlite
(a native SQLite extension providing CRDT tables) vs building it ourselves
on plain SQLite. This spike resolves it.

## Findings

1. **No maintained cr-sqlite binding exists for Flutter/Dart** (pub.dev
   survey, 2026-07). Adopting it means bundling and updating its native
   loadable extension ourselves for five platforms.
2. **iOS is effectively a blocker for loadable extensions**: they must be
   statically linked into a custom sqlite3 build, forfeiting the stock
   `sqlite3_flutter_libs` binaries and owning a custom native build chain
   for at least iOS — high maintenance for a solo project.
3. The pure-Dart CRDT packages that do exist (`crdt`, `sqlite_crdt`,
   `drift_crdt`) implement **row-level** LWW, not the per-field merge our
   design calls for, and would replace our drift schema with their own.
4. Hand-rolling is small: with HLC (`lib/core/hlc.dart`) and the
   `field_clocks` table already in schema v1, a working LWW applier
   (`lib/data/sync/lww_applier.dart`) plus a 7-case two-database
   convergence test (`test/data/lww_applier_test.dart`) took well under a
   session. Convergence under reordering, duplication, ties, and
   tombstones is green.

## Decision

Hand-rolled per-field LWW on plain SQLite/drift. No native extensions, no
third-party CRDT dependency.

## Consequences

- We own correctness: the property-based convergence suite (task 3.3) is
  mandatory and remains the release gate for sync.
- Row create/delete changeset ops (beyond field writes) are ours to design
  in task 3.1.
- All platforms use stock `sqlite3_flutter_libs` binaries — no custom
  native build chain.
- Revisit only if requirements grow toward rich-text/sequence CRDTs, which
  LWW registers can't express.
