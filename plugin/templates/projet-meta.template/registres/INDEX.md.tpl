# Local registers — {{PROJET_NAME}}

> Local registers for capitalization at the meta-project level.
> Cross-cutting learnings bubble up to the lab then to the parent method via the `traffic-controller`.

## Usage doctrine

**Empirically**: at the meta-project level, only `journal.md` + `blockers.md` (+ HANDOVER.md) are actively used. The other registers stay empty most of the time — and **that is normal**.

| Register | Role | Expected use in a meta-project |
|----------|------|------------------------------|
| `journal.md` | Append-only chronology of sessions | 🟢 Used continuously |
| `blockers.md` | Problems encountered and resolutions | 🟢 Used when a blocker appears |
| `learnings.md` | Project-specific learnings | 🟡 Used occasionally (otherwise bubble up to lab/global) |
| `bdr.md` | **Committing strategic decisions** | 🔴 Rare at the project level (leave empty unless an own decision) |
| `eval.md` | **LLM hallucination patterns** | 🔴 Rare at the project level (bubble up to global) |

**The HANDOVER.md** (at the root of the meta-project, not in `registres/`) plays the role of the **real detailed journal**: tracking decisions, features, bugs, architecture choices during the session. Far more used than `journal.md` in practice.

## Format

All registers follow the Vibeforge pattern:
- Mandatory reading at bootstrap (by the agents that need it)
- Append-only except `bdr.md` and `rules.md` which can be reorganized
- YAML frontmatter format per entry (cf. `<workspace>/registres/INDEX.md`)

## Promotion

- **Learning → Rule** (parent method): recurrence ≥ 3 over 30 days OR critical impact. Via `/traffic-controller scan` or manual operator validation.
- **Project decision → BDR**: if the decision impacts ≥ 2 projects/sessions AND closes a committing option. Via `/promote-decision-to-bdr` or manual.
- **Error pattern → Eval**: if an LLM pattern recurs and is expressible as an anti-pattern instruction. Via `/promote-pattern-to-eval` or manual.

## See also

- `${CLAUDE_PLUGIN_ROOT}/doctrine/02-registres.md` — full mapping and promotion criteria
- `<workspace>/registres/INDEX.md` — table of global registers
