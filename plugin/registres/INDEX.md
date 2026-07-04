# Index of Vibeforge global registers

> Table of contents for the organic registers + traffic-journal.
> Read this first to orient yourself before diving into a register.

## The registers

| File | Role | Entry type |
|------|------|------------|
| [`bdr.md`](bdr.md) | **Business Decision Record** — committing strategic decisions | `BDR<NN>` |
| [`learnings.md`](learnings.md) | Technical/business learnings (generalizable insights) | `L<NN>` |
| [`rules.md`](rules.md) | Cross-cutting rules after promotion (from recurring learnings) | `R<NN>` |
| [`eval.md`](eval.md) | **LLM hallucination/error patterns** (anti-patterns to know) | `E<NN>` |
| [`traffic-journal.md`](traffic-journal.md) | Journal of traffic-controller decisions | Timestamped sessions |

Note: `blockers.md` and `journal.md` live at the LOCAL level of labs/projects, not at the global level. Globally we keep only what deserves to be cross-cutting.

> 📖 **Full semantic map**: see `vibeforge/doctrine/02-registres.md`, section "Discrimination table", for the criteria to choose BDR vs Eval vs Learnings vs Rules.

## Counters

| Register | Counter |
|---|---|
| BDR | 0 |
| Learnings | 0 |
| Cross-cutting rules | 17 (R001–R018, R011 reserved) — see rules.md |
| Eval patterns | 0 |
| traffic-controller scans | 0 |

> The method ships with the cross-cutting rules pre-populated (they are part of the doctrine). The other registers start empty — you fill them as you work.

### Two distinct "rules" namespaces

Vibeforge has **two distinct sets of "rules"** (keep them apart):

| Source | ID format | Content | Role |
|---|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}/CLAUDE.md` | `R1`, `R2`, … (single digit) | **Constitutional rules** (mandatory agent behavior at startup) | Agent behavior |
| `<workspace>/registres/rules.md` | `R001`, `R002`, … (zero-padded) | **Cross-cutting rules** promoted from learnings | Empirical process/business rules |

No functional conflict (both coexist), but the overlapping numbering (R5 constitutional vs R005 cross-cutting) can confuse. Possible future refactor: rename constitutional rules to `C1-C10`.

## Conventions

### IDs
- Format: `<TYPE><NN>` (zero-padded to 3 digits: `R001`, `BDR007`, `L042`)
- Never reused (if an entry is deleted, its ID stays reserved)

### Per-entry frontmatter
```yaml
---
id: <type><nn>
type: <bdr|learning|rule|eval>
created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
severity: <low|medium|high|critical>
domain: <archi|security|rag|prd|...>
related: [<id1>, <id2>]
promoted_from: [<source path if applicable>]
status: <active|deprecated|under-review>
---
```

### Lifecycle
- A `learning` can be promoted to a `rule` by the traffic-controller (recurrence ≥ 3 OR critical)
- A `rule` can be demoted if not cited for 180 days or contradicted
- A `BDR` is engraved (rarely modified, only extended — a revision = an explicit new BDR)
- An `eval` pattern can become a preventive `rule`

### Telling learning, eval, BDR apart

- **Learning**: "I learned X" (experience insight, reversible with better understanding)
- **Eval**: "the LLM fails at X" (hallucination pattern, preventive anti-pattern)
- **BDR**: "we decided X" (strategic commitment, changes trajectory)
- **Rule**: "always do X" (cross-cutting obligation, post-promotion)

Explicit promotion skills:
- `/promote-decision-to-bdr` — detects structuring decisions in HANDOVER/journal → BDR
- `/promote-pattern-to-eval` — detects hallucination patterns in learnings → Eval
- `/traffic-controller scan` — scans cross-lab for L→R promotions

## Maintenance

- INDEX updated by the traffic-controller on each promotion
- Counters updated on each add/remove
- Renumbering: NEVER. IDs are stable.
