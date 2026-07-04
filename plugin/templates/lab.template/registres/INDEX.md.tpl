# Register index — {{LAB_NAME}}

> Table of contents of the lab's 5 local registers.
> Check first to get oriented before diving in.

## The local registers

| File | Role | Entry type |
|---------|------|---------------|
| [`bdr.md`](bdr.md) | Structuring decisions of the lab | `BDR<NN>` |
| [`blockers.md`](blockers.md) | Frictions encountered | `B<NN>` |
| [`learnings.md`](learnings.md) | Solutions linked to blockers | `L<NN>` |
| [`journal.md`](journal.md) | Chronological session log | per session |
| [`eval.md`](eval.md) | Observed hallucination patterns | `E<NN>` |

## Counters

- BDR: 0
- Blockers: 0 (resolved: 0)
- Learnings: 0
- Eval patterns: 0

## Conventions (inherited from the Vibeforge parent)

See `{{LAB_PARENT}}/registres/INDEX.md` for details on format, ID, frontmatter, and lifecycle conventions.

## Maintenance

- Automatic updates via hooks (`post-tool-use.ps1`, `stop.ps1`, `session-end.ps1`)
- Explicit audit via `/cloture-session`
- Cross-lab promotions via `/traffic-controller scan` (toward `{{LAB_PARENT}}/registres/`)
