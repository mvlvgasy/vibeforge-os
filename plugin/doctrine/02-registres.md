# Frame 2 — Registers (living memory)

> 5 .md files per level that continuously capture the project's experience.
> The "game changer" of the method.

## Definition

Registers are the living memory of Vibeforge. They are where agents capitalize their learnings, frictions, decisions, sessions, and hallucinations. Without registers, every session starts from scratch.

## 🧭 Semantic mapping

> Reworked following an empirical audit: `bdr.md` and `eval.md` were under-used (3 and 1 entries respectively over 6 months) because the promotion criteria were unclear. This section clarifies them.

**The main flow** (already active and fluid):

```
blockers.md (concrete friction)
     │ resolution
     ▼
learnings.md (I learned X)
     │ promotion (recurrence ≥3 or critical impact)
     ▼
rules.md (mandatory cross-cutting rule)
```

**The 2 lateral registers** (parallel, not in the same queue):

```
                journal.md (chronological narrative)
                       │
                       ▼
   ┌──────────── learnings.md ────────────┐
   │                                       │
   │ (special cases)                       │ (recurrence)
   ▼                                       ▼
eval.md                                rules.md
(LLM hallucination/error pattern)      (cross-cutting rule)

   ┌──────────── strategic decisions ──────────────┐
                       │
                       ▼
                    bdr.md
              (durable commitment)
```

### Discrimination table — which register to choose?

| Question answered | Register | ID format | Reversibility |
|---|---|---|---|
| What is **blocking** me? | `blockers.md` | `B<NN>` | Resolved/not |
| What did I **learn**? | `learnings.md` | `L<NN>` | Reversible (better insight) |
| What must I **always do**? | `rules.md` | `R<NN>` | Quasi-stable (rare deprecation) |
| Where does the **LLM hallucinate/err**? | `eval.md` | `E<NN>` | Empirical (frequency tracked) |
| What did we **decide strategically**? | `bdr.md` | `BDR<NN>` | **Durable commitment** (BDR02 to revise) |
| What happened in the session? | `journal.md` | timestamped session | Append-only |

## The 5 registers

### 1. `bdr.md` — Business Decision Record

- **What**: **strategic decisions** that change the trajectory of Vibeforge or a project/lab. **Committing** decisions that are not reversed without an explicit reason (= BDR02).
- **Not**: not a learning, not a rule. A **decision** that has consequences for future choices.
- **Examples**:
  - "We use Vercel Hobby and not Cloud Run for internal apps" (infra commitment)
  - "Vibeforge = doctrine-first meta-discipline, NOT code-first" (current BDR01)
  - "We DO NOT build a daemon, we stick to one-off hooks"
  - "Vibeforge agents are dispatched by Main Claude, not by a custom orchestrator"
- **Promotion criteria**:
  - **Committing nature**: the decision modifies the architecture of the work, changes the cost of backtracking
  - **Explicit trade-off**: the decision closes off an option (Vercel ≠ Cloud Run)
  - **Cross-project consequences**: impacts at least 2 projects/labs or the root method
  - **Operator validation**: a BDR is **not** promoted automatically, it must be arbitrated
- **ID**: `BDR<NN>`
- **Living level**:
  - Root method (`<workspace>/registres/bdr.md`): global Vibeforge decisions
  - Lab: architectural decisions of the lab (e.g. "the client-acme lab uses Notion, not Airtable")
  - Project/meta-project: **rare**, only for a structuring project-specific decision. Otherwise leave empty.

### 2. `blockers.md` — Frictions encountered

- **What**: every obstacle encountered (incompatibilities, test failures, network errors)
- **Example**: "Slack Bolt v4 incompatible with Next.js 15 without waitUntil()"
- **Cycle**: created when blocking, marked `resolved` when resolved, linked to a learning
- **ID**: `B<NN>`
- **Living level**: **mainly lab/project** (global Vibeforge blockers are rare)

### 3. `learnings.md` — Learnings

- **What**: insights drawn from resolving blockers OR from spontaneous observations (monitoring, experience)
- **Cycle**: created after a resolution/observation, candidate for promotion to a rule IF recurrent
- **ID**: `L<NN>` (or `L-<scope>-<NN>` for specific sources)
- **Living level**: at all levels (method/lab/project)

### 4. `journal.md` — Chronological session log

- **What**: a narrative trace of every session, in temporal order
- **Example**: "Session <YYYY-MM-DD> — S1 project foundations. Resolved X, blocked on Y."
- **Cycle**: append-only, never modified
- **Format**: per session
- **Important note**: in practice, `HANDOVER.md` often plays the role of the "real detailed journal" at the project level. `journal.md` remains useful at the root method and lab levels to keep a structured chronological view.

### 5. `eval.md` — LLM hallucination patterns

- **What**: moments where the LLM (Claude Code, Sonnet, Haiku, etc.) hallucinated, misinterpreted, failed silently, or produced erroneous content reproducibly
- **Not**: not a learning about "I learned to do X". An eval = a **recurrent trap** that agents must know at bootstrap in order to avoid it.
- **Examples**:
  - "Claude invents Bolt v3 function names when working in v4" (invented api/lib)
  - "Cross-provider tool_use: downgrading Sonnet→Haiku silently breaks the palette" (SDK fallback)
  - "The LLM creates a `Date.now()` in a workflow when it actually throws" (invisible runtime context)
  - "Meta-recursion: an agent that codes agents loses the subject/medium ontology" (current E01)
- **Promotion criteria**:
  - **Reproducibility**: pattern observed at least twice, ideally with a hypothesized cause (training bias / SDK fallback / context loss)
  - **Possible prevention**: an anti-pattern instruction can be written into the bootstrap
  - **Different from a learning**: a learning explains HOW we resolved it, an eval explains WHY the LLM fails in this way (meta-analysis)
- **ID**: `E<NN>`
- **Living level**: **mainly the root method** (hallucination patterns are rarely project-specific). At the lab/project level: rare, except for a domain-specific pattern.
- **Reading at bootstrap**: all agents read `eval.md` at startup to internalize the traps.

## Format of a register

Each register starts with an INDEX (TOC) then lists the entries:

```markdown
# Learnings <scope>

## Index
- [L001](#L001) — Slack Bolt + Vercel waitUntil pattern
- [L002](#L002) — RAG cosine threshold 0.65 too strict
- [L003](#L003) — ...

## L001

```yaml
---
id: L001
type: learning
created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
severity: critical
domain: slack-bolt-hosting
related: [B042, BDR007]
project: acme-onboarding
status: active
---
```

### Context
...

### Lesson
...

### How to apply
...
```

The INDEX at the top allows the agent to **NOT load the entire register**: it reads the index, identifies the relevant IDs, and reads only the sections concerned (via Grep or offset-based Read).

## Multi-level hierarchy

Registers exist at 3 levels but **NOT all 5 registers at every level**:

| Level | Registers active in practice | Optional |
|--------|------------------------------|-----------|
| **Root method** (`<workspace>/registres/`) | `learnings.md`, `rules.md`, `bdr.md`, `eval.md`, `traffic-journal.md` | — |
| **Lab** (`<lab>/registres/`) | `learnings.md`, `blockers.md` | `bdr.md`, `eval.md` (if the lab is mature enough) |
| **Project/meta-project** (`<project>/.claude/registres/`) | `journal.md`, `blockers.md` (+ `HANDOVER.md`) | `bdr.md`, `eval.md`, `learnings.md` (rare — otherwise leave empty) |

**Empirical doctrine**: a meta-project generally **DOES NOT NEED** local `bdr.md`, `eval.md`, or `learnings.md`. These levels let `HANDOVER.md` + `journal.md` + `blockers.md` live and **promote upward** to the lab (then to global) whatever deserves to be captured. Project-specific `bdr.md` / `eval.md` / `learnings.md` are created **on demand only** when the need emerges.

Entries are promoted upward via promotion (Frame 9 — Traffic Controller).

## Automatic updates

Three mechanisms:

### A. `PostToolUse` hook
When an agent encounters an error (exit code ≠ 0 on Bash, failed API call, etc.), the hook can automatically append a candidate blocker into the local register.

### B. `Stop` hook
At the end of each session, the hook appends the journal and proposes an update to the agent's MEMORY.

### C. `/cloture-session` skill
Explicit audit: reviews the registers, proposes missing entries, validates completeness.

### D. Explicit promotion skills
- `/promote-decision-to-bdr`: scans HANDOVER.md + journal.md to detect structuring decisions ("we decide", "from now on", "pivot") → proposes a formal BDR
- `/promote-pattern-to-eval`: scans learnings.md + journal.md for LLM hallucination patterns ("Claude hallucinated", "tool_use fail", "silent fallback") → proposes a formal E<NN>
- `/traffic-controller scan`: scans cross-lab, proposes cross-project L→R promotions

## How an agent CONSULTS the registers

Recommended pattern in each agent's system prompt:

```markdown
## Mandatory bootstrap
Before any task, read:
1. registres/INDEX.md (all relevant registers)
2. registres/rules.md (global rules)
3. registres/eval.md (hallucination patterns to avoid)
4. For your specific task, read the corresponding entries by domain
```

Optimization: use `Grep` on the frontmatter (`domain: <X>`) rather than loading the entire register.

## Anti-patterns

- ❌ Register without an INDEX at the top → the agent loads everything, context saturated
- ❌ Register without frontmatter per entry → impossible to filter programmatically
- ❌ Register where entries are deleted → loss of traceability, breaks cross-register references
- ❌ Register where IDs are renumbered → breaks all links, an absolute anti-pattern
- ❌ Register where info is duplicated locally + globally → only the global one should be canonical after promotion (mark the source `[promoted]`)
- ❌ Register that becomes an unstructured "box of thoughts" → strict format or nothing
- ❌ **bdr.md** used as a vague "definitions of success" log → always use **"Business Decision Record"** (strategic commitment)
- ❌ Confusing **learning** and **eval**: a learning explains "how I resolved it", an eval explains "where the LLM fails" (meta-analysis)
- ❌ Forcing the creation of `bdr.md`/`eval.md` at the project/meta-project level when it naturally promotes up to the lab/global → leaving these levels empty is legitimate

## See also

- Frame 3: Consolidation (the process that maintains register quality)
- Frame 9: Traffic (cross-lab consolidation via traffic-controller)
