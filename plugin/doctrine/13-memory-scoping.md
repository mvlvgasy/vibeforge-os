# Frame 13 — Memory scoping (extension of Frame 4 Agents)

> Operational frame extending **Frame 4 Agents**. Not a foundational frame — an extension.
> Governs how Vibeforge agents manage their MEMORY across **2 levels**: universal and lab.
>
> Key design decisions:
> - No project level (purely theoretical, redundant with the lab MEMORY.md)
> - Cross-agent shared memory (`<workspace>/agent-contexts/_shared/MEMORY.md`)
> - A `/dream` skill for automatic consolidation
> - A `dream-validator` between the consolidation proposal and apply (automatic quality checkpoint)
> - Auto cadence 1×/day via a session-start hook if >24h since the last dream
> - No user validation in auto mode (full trust + audits via `/metrics-report`)

## Problem solved

Before formalization, each core Vibeforge agent had a **single** `MEMORY.md` in `<workspace>/agent-contexts/<agent>/`. Empirically measured consequence:

- 11/12 core agents had their MEMORY **frozen at bootstrap date** (no update after intervention)
- The rare updates would have produced a cross-domain mess (an architect working on 5 projects across 3 different labs accumulates everything in the same place)
- At bootstrap, the agent loads 100% of the MEMORY but 80% is irrelevant to the current mission
- Bootstrap cost paid (~5-10k tokens), marginal learning benefit

**The R009 analysis** identified the real problem: the gap was not scoping (which is only an organization) but the **absence of an automatic post-session consolidation mechanism**. No equivalent of a background "sleeptime agent" / "dreaming" mechanism that would consolidate after each session.

## Solution — 2 scoped levels + shared memory + dreamer

```
<workspace>/
  agent-contexts/
    _shared/
      MEMORY.md            ← SHARED CROSS-AGENT — cross-cutting patterns shared by ALL agents
      README.md            ← writing convention + promotion criteria
    architecte/
      MEMORY.md            ← UNIVERSAL LEVEL — cross-cutting patterns specific to this agent
      journal.md
    dreamer/
      pending-updates.md   ← consolidation output awaiting validation via /dream

<workspace>/lab-<X>/
  agent-contexts/
    architecte/
      MEMORY.md            ← LAB LEVEL — patterns specific to the lab domain
      journal.md
```

### What to put at each level

| Level | Typical content | Target volume | Update frequency | Update mechanism |
|--------|--------------|--------------|------------------|------------------|
| **Shared (`_shared/MEMORY.md`)** | Shared technical stack (framework versions, runtime, path conventions), cross-cutting client constraints, cross-agent orchestration patterns | ≤300 words | Rare (1×/week max) | Consolidation proposes, you validate via `/dream` |
| **Universal agent (`<agent>/MEMORY.md`)** | Agent-specific preferences (the architect's style, the BA's conventions, prompt-engineer patterns), recurring anti-patterns of that agent | ≤200 words | Rare (1×/2 weeks) | Consolidation proposes, you validate |
| **Lab agent (`<lab>/agent-contexts/<agent>/MEMORY.md`)** | Domain constraints (compliance for a client lab, credibility tier for a research lab), the lab's canonical formats, lab-specific patterns of that agent | ≤300 words | Moderate (1×/sprint) | The agent itself at the end of a session OR the consolidation |

### Why 2 levels and not 3

The project level was **abandoned** because:
- In practice, 0 `<project>/agent-contexts/` files end up existing on disk
- The project scope is already covered by the meta-project's local MEMORY (HANDOVER, PRD coverage reports)
- Triple-load at bootstrap (universal + lab + project) costs tokens with no clear benefit
- Frame 12 (deliverable/meta-project split) already covers the project ADR/journal via the meta-project

Decision: **keep 2 levels + cross-agent shared memory**.

### Expected natural pyramid

```
        SHARED            10% of volume (cross-agent cross-cutting patterns)
         /  \
        /    \
   UNIVERSAL  UNIVERSAL   30% (per agent, rare)
    |          |
    LAB       LAB         60% (per agent per lab, moderate)
```

If we observe an INVERTED pyramid (a lot of universal/shared, little lab) → drift, `traffic-controller` intervention required.

## The central mechanism: `dreamer` (proposes) + `dream-validator` (filters) + `/dream` (applies)

### v2.1 architecture (inspired by Letta sleeptime + Anthropic dreaming + a validator agent)

**3-stage pipeline**:

```
[session-start hook if >24h]
        ↓
   [Skill /dream]
        ↓
  [Main Claude proposes]        ← writes proposals in pending-updates.md
        ↓
  [Agent dream-validator]       ← filters apply/reject/defer
        ↓
   [Skill /dream]               ← auto-applies the "apply"
                                   logs the "reject"
                                   preserves the "defer" for /dream manual
        ↓
   [metrics/events.jsonl]       ← kind:"dream_run" event logged
```

**Step 1 — Consolidation proposal (Main Claude)**:
1. Reads the `journal.md` files modified since the last dream
2. Reads the `git log` of concrete changes
3. Reads the current state of the MEMORY (universal + lab + shared)
4. **Proposes** updates in `agent-contexts/dreamer/pending-updates.md`:
   - MEMORY updates (shared / universal / lab)
   - `suggestions_traffic_controller` section (signal-only)
   - Alerts (MEMORY frozen >30d despite activity)

**Step 2 — Dream-validator (judgment)**:
1. Reads `pending-updates.md`
2. For each proposal, applies 3 decision grids:
   - **Grid 1 (auto-reject)**: rule violation / out of scope / duplicate / exceeds 300 words / single source / shared anti-pattern
   - **Grid 2 (auto-apply)**: ≥3 distinct sources + clear scope + no rule violated
   - **Grid 3 (defer)**: gray area (2 sources, ambiguous scope, requests a convention change)
3. Writes `agent-contexts/dream-validator/decision-<ts>.md` in the strict format

**Step 3 — Skill `/dream` apply**:
1. Auto-applies proposals marked `apply` (Edit MEMORY)
2. Logs the `reject` in `agent-contexts/dreamer/rejected-log.md`
3. Preserves the `defer` in `agent-contexts/dreamer/deferred-queue.md` for a later `/dream manual`
4. Appends a `kind:"dream_run"` event in `metrics/events.jsonl`

**Nothing touches the MEMORY or the registers directly.** Main Claude proposes, the validator decides, `/dream` applies. The operator runs on "full trust" + periodic audits via `/metrics-report --focus=memory-consolidation`.

### Cadence

- **Auto**: 1×/day via the `session-start.ps1` hook at the first session of the day
- **Trigger condition**: >24h since `last-dream-ts.txt` AND ≥1 recent commit (7d)
- **Mechanism**: the hook drops `.claude/dream-auto-pending.md` → Main Claude reads it at bootstrap (CLAUDE.md step 9) → auto-invokes `/dream`
- **Manual**: `/dream manual` remains available for debug/audit/in-depth review of the deferred items

### Strict delimitation: dream consolidation ≠ traffic-controller

The dream consolidation scopes **agent MEMORY only**. It **does NOT touch** the `learnings.md`, `rules.md`, `bdr.md`, `eval.md` registers.

| Mechanism | Strict scope | Trigger | Target frequency |
|---|---|---|---|
| `/dream` consolidation | Agent MEMORY (shared/universal/lab) | `/dream` or nudge hook | 2-3×/week |
| `traffic-controller` | `learnings.md` → `rules.md`, `bdr.md`, `eval.md` (cross-lab promotions) | `/traffic-controller scan all` manual OR via `/cloture-session` if ≥3 projects | Rare (depending on material) |

**Why this separation**:
- Promoting a learning → rule requires **strategic judgment** (recurrence, severity, truly cross-lab?) — distinct from the mechanical MEMORY consolidation.
- Avoid **double validation** by the operator (1 /dream + 1 /traffic-controller scan all = 2 batches).
- The consolidation is **frequent** (2-3×/week), the traffic-controller is **rare** (triggered by material). Different cadences → different tools.
- Single Responsibility Principle: each one stays in its area of expertise.

**Coordination mechanism**: if the consolidation pass sees recurring patterns in the journals that could become learnings/rules, it lists them in `suggestions_traffic_controller` (the signal-only section of pending-updates.md). `/dream` shows the operator: *"You can also run /traffic-controller scan all afterwards if you want to formalize these patterns."* The consolidation touches nothing.

**If `traffic-controller` is under-invoked in practice** → that is a genuine signal of a human discipline problem, **not to be masked** by folding it into the consolidation. Possible future solution: a specific traffic-controller nudge hook.

### `/dream` workflow

```
The operator types: /dream  (or the hook nudges the prompt after N sessions without /dream)
  ↓
Skill /dream:
  1. Main Claude runs the consolidation pass
  2. Produces pending-updates.md (5-15 proposals typically)
  3. Skill presents the diff to the operator:
     ✅ Validated → apply
     ❌ Rejected → skip
     ⚠️ To reformulate → inline edit
  4. Apply the validated updates (Write/Edit on MEMORY + append registers)
  5. Updates last-dream-ts.txt to reset the nudge
  6. Appends an entry in agent-contexts/dreamer/journal.md
```

### Why separate the proposal from the validation?

- **Consolidation proposal = mechanical** (read, compare, propose) — Main Claude produces the draft from journals + git + current MEMORY.
- **Dream-validator = judgment**: validation requires deciding rules respected? correct scope? sufficient source? Keeping it a separate agent enforces a clean apply/reject/defer checkpoint before anything is written.
- **`/dream` skill = not an agent**: it is the glue that orchestrates + applies. No reasoning, just mechanical Edit/Write.
- **Context isolation**: the consolidation does not pollute the context of the lead that does the productive orchestration
- **Independent cadence**: runs automatically via a hook, not coupled to lead sessions

## Promotion mechanic

The consolidation **never writes directly at the shared level**. Workflow:

1. **Insight detection**: at the end of an intervention, a reusable pattern is identified
2. **Initial writing**: always at the **lab** level (the most local of the 2 levels)
3. **Validation by recurrence**: if the pattern appears in a 2nd lab → the consolidation or `traffic-controller` proposes promotion to the agent's **universal** level
4. **Shared promotion**: if the pattern appears in ≥2 different agents (regardless of lab) → the consolidation proposes promotion to `_shared/MEMORY.md`

This recurrence mechanic remains the same as for learnings → global rules (Frame 9 Traffic). It is the application of the same principle to agent memory, automated by the consolidation pass.

## Agent bootstrap (pattern to implement)

Each agent must load in parallel:

```markdown
## Scoped MEMORY bootstrap (R009 v2)

At each startup, load in parallel (multiple Read tool calls):

1. **SHARED**: `<workspace>/agent-contexts/_shared/MEMORY.md` (always present)
2. **UNIVERSAL**: `<workspace>/agent-contexts/<self>/MEMORY.md` (always present)
3. **LAB** (if cwd is in a lab): `<lab-root>/agent-contexts/<self>/MEMORY.md` (skip silently if absent)

Automatic scope detection via the cwd:
- workspace root (no lab) → shared + universal only
- `<workspace>/lab-<X>/` → shared + universal + lab
- `<workspace>/lab-<X>/projets-meta/<Y>/` → shared + universal + lab (the project is in the lab → same loading)
```

## Post-intervention update (scope decision)

At the end of a significant intervention, the agent decides where to write based on **3 test questions**:

1. **"Is this insight a pattern cross-cutting across MULTIPLE agents (not just me)?"**
   → If YES and observed in ≥2 agents: shared candidate (via the dreamer)
   → Otherwise: continue to the next questions

2. **"Does this insight hold for ALL my future labs, regardless of domain?"**
   → If YES across ≥2 observed labs: universal agent (via the consolidation)
   → If YES but on the 1st lab: lab (awaiting recurrence)

3. **"Is this insight specific to this lab/domain?"**
   → lab only

By default: **always lab first**. Promotion only via recurrence validated by the consolidation.

## Implementation

R009 v2 is composed of the following pieces:

### Doctrine + R009
- Doctrine 13 (this file)
- R009 in `registres/rules.md` (2 levels + shared)
- Global CLAUDE.md (mention of `_shared/MEMORY.md`)

### Consolidation pass
- `skills/dream/SKILL.md`: Main Claude produces the proposals, the `dream-validator` agent filters, the skill applies
- State folder `agent-contexts/dreamer/` (pending-updates, rejected-log, deferred-queue, archive)

### Nudge hook
- `hooks/session-end.ps1`: if N sessions without /dream → `dream-reminder.md`

### Shared memory
- `agent-contexts/_shared/MEMORY.md` (initially empty or minimal seed)
- `agent-contexts/_shared/README.md` (convention + promotion criteria)

### Agent bootstrap
- `agents/lead.md`: the bootstrap step includes `_shared/MEMORY.md`
- Same note in doctrine/04 for the other agents

## Anti-patterns

- ❌ Writing everything at the shared level by default → the shared MEMORY becomes a mess (agent forgets to scope, the dreamer has to consolidate)
- ❌ Writing everything at the universal level by default → universal polluted with domain constraints
- ❌ Massive refactor "we migrate all agents in one session" → breaks the method (see R005 — draft state for irreversible). Progressive migration via the consolidation.
- ❌ Skipping the consolidation to write directly at the shared level → R009 v2 bypass
- ❌ Running `/dream` every session → costly and noisy (target cadence: 1×/day or 1×/3 sessions)
- ❌ Treating pending-updates.md as "to be applied as-is" without going through the validator → these are suggestions, not truths

## R009 v2 health metrics (Frame 10)

- Shared/universal/lab ratio (target ~10/30/60%)
- Average `last_update` age per level (shared >14d expected, universal >7d expected, lab <7d expected if active)
- Number of lab→universal→shared promotions per month (signal of active capitalization)
- Acceptance rate of consolidation proposals (target >50% — otherwise the consolidation is poorly calibrated)
- `/dream` frequency (target 2-3×/week)

## Reference

- Frame 4 (Agents) — agent definition + agent-contexts
- Frame 7 (Capitalization) — capitalization mechanisms
- Frame 9 (Traffic) — traffic-controller, cross-project promotions
- Frame 10 (Self-improvement) — metrics and self-correction
- R009 in `registres/rules.md` — the executable rule
- `agents/dream-validator.md` — the validator agent
- `skills/dream/SKILL.md` — the skill
- `agent-contexts/_shared/README.md` — shared memory convention

## External inspiration

- **Letta** (formerly MemGPT) — sleeptime agent that consolidates in the background, memory blocks "core in-context = RAM" + "archival = searchable Disk"
- **File-based memory** — structured note-taking pattern that Vibeforge already follows
- **Mem0** — 4 scopes (user/agent/session/custom), extraction-consolidation
- **A-Mem** — agentic Zettelkasten with dynamic linking (future inspiration if scaling)
- **Zep** — temporal knowledge graph with validity windows (future inspiration)

R009 v2 mainly reuses the Letta pattern (sleeptime agent that consolidates), adapting it to a file-based architecture.
