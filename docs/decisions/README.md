# Architecture Decision Records

One short markdown file per decision that changes PLAN.md or reverses something
in "Things already decided" (CLAUDE.md). Number sequentially.

Format:

```markdown
# NNNN — Title

Date: YYYY-MM-DD
Status: accepted | superseded by NNNN

## Context
## Decision
## Consequences
```

Planned first entry: `0001-crdt-choice.md` — outcome of the Phase 0 spike
(cr-sqlite vs hand-rolled LWW/HLC).
