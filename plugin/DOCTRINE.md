# Vibeforge Doctrine — The 16 fundamental frames

> Operational synthesis. For the detail of each frame, see `doctrine/01-...md`
> through `doctrine/16-...md`.

## Overview

- **1-8**: discipline and memory (Constitution, Registers, Consolidation, Agents,
  Skills, Rules, Capitalization, Transposition)
- **9-12**: scalability and operations (Traffic, Self-improvement, Credentials &
  Secrets, Project workflow)
- **13-16**: emergent extensions (Memory scoping = extension of frame 4; Agent
  delivery architecture; Bounded autonomous execution; Standalone labs — the
  generator model)

## Frame 1 — Constitution

**Definition**: the root directive that states "who this project is" and "what we do in
it".

**Materialization**:
- `CLAUDE.md` (generic) + `SOUL.md` (stable identity)
- Each lab has its own `CLAUDE.md` that inherits + adds the domain context
- Each project lives in **2 physically separate folders** (R002):
  - **Deliverable** (`<workspace>/projets/<category>/<project>/`): pure code, a
    standalone git repo pushable to the client. **No Vibeforge files.**
  - **Meta-project** (`<lab>/projets-meta/<project>/`): `.claude/CLAUDE.md`,
    `HANDOVER.md`, registers, PRD drafts, transcripts, etc. Lives in the lab.
  - Claude Code sessions have their `cwd` in the meta-project; the code is written into
    the deliverable via `additionalDirectories`.

**Detail**: `doctrine/01-constitution.md`

## Frame 2 — Registers (living memory)

**Definition**: a set of `.md` files per level, indexed, that continuously capture the
project's experience.

**The registers**:
- `bdr.md`: Business Decision Record — structuring decisions
- `blockers.md`: frictions encountered (incompatibilities, failures)
- `learnings.md`: solutions tied to blockers
- `journal.md`: chronological log of all sessions
- `eval.md`: hallucination patterns, meta-analysis of the AI

**Format**: TOC index at the top (avoid loading everything) + entries with short IDs
(L001, B042) + frontmatter with metadata (severity, domain, related, promoted).

**Update**: automatic via PostToolUse hooks (detected blockers) + Stop (journal append)
+ manual via the `/cloture-session` skill.

**Detail**: `doctrine/02-registres.md`

## Frame 3 — Consolidation

**Definition**: a periodic process that maintains register quality (archive, merge,
promote, reindex).

**Mechanisms**:
- `/cloture-session` skill: invoked manually at the end of a session
- `SessionEnd` hook: automatic trigger if forgotten
- `traffic-controller` agent (frame 9): cross-lab consolidation

**Promotion chain**:
1. Appearance: a learning local to the project
2. Recurrence: seen in 2+ projects → promotion candidate
3. Promotion: copied into `registres/rules.md`, marked `[promoted]` in the source
4. Cleanup: the source can be archived after promotion (avoids double maintenance)

**Detail**: `doctrine/03-consolidation.md`

## Frame 4 — Agents

**Definition**: `.md` files in `agents/` that define specialized roles.

**The Vibeforge agents**:
- `lead`: orchestrator, never direct execution
- `architecte`: technical design
- `ux`: user experience, design
- `strategie-contenu`: content automation, marketing
- `business-analyst`: business-needs analysis, framing
- `prompt-engineer`: preparation of Claude Code session prompts
- `reviewer-prd`: PRD coverage audit
- `code-reviewer`: review before push
- `devil-advocate`: adversarial critique (on explicit request)
- `traffic-controller`: cross-lab consolidation (frame 9)
- `skill-curator`: validation of skill auto-creation (frame 10)
- `lab-architect`: creation of a new lab
- `dream-validator`: validates MEMORY consolidation proposals

**"Armed agents"**: each agent has an ARMED frontmatter:
- precise `tools` + `disallowedTools`
- dedicated `mcpServers`
- `memory: project` (native persistence)
- bounded `maxTurns`
- `permissionMode: default`
- preloaded `skills` (2-4 per agent)
- its own `hooks`
- its own `agent-contexts/<name>/{SOUL, USER, MEMORY, journal, skills/}`

**3 orchestration modes**:
- `/lead-auto`: fully autonomous
- `/lead` (default): semi-auto, proposes each delegation
- Direct slash: manual control

**Detail**: `doctrine/04-agents.md`

## Frame 5 — Skills

**Definition**: activatable specific competencies, in the standard Anthropic Agent
Skills format.

**Three sources**:
- **Vibeforge**: `skills/<name>/SKILL.md` (cross-cutting)
- **Agent-specific**: `agent-contexts/<agent>/skills/<name>.md` (internal use)
- **External**: Superpowers (obra) installed globally

**Auto-creation**: an agent can create a skill from its experiences, BUT validation by
`skill-curator` is mandatory (frame 10).

**Preloading**: an agent can have 2-4 "fundamental" skills preloaded via the `skills:`
frontmatter. Others are invocable on demand via the `Skill` tool.

**Detail**: `doctrine/05-skills.md`

## Frame 6 — Rules

**Definition**: cross-cutting rules that rise from learnings via consolidation.

**Location**:
- `registres/rules.md`: global rules (post-promotion)
- `<lab>/rules.md`: domain-specific rules
- `<project>/.claude/rules/00-XX.md`: project-specific rules (numbered pattern for
  priority)

**Life cycle**:
1. Birth: local observation → learning
2. Confirmation: recurrence across 2+ projects → BDR
3. Crystallization: promotion to a rule
4. Application: mandatory read at the start of each agent
5. Eventual death: if contradicted by a new learning, put up for debate then
   kept/modified/retired

**Detail**: `doctrine/06-rules.md`

## Frame 7 — Capitalization

**Definition**: the close-out process that prevents documentation debt.

**Mechanisms**:
- `/cloture-session` skill: explicit audit at the end of a session
- `SessionEnd` hook: forces the close if forgotten
- `reviewer-prd` agent: validates PRD coverage before any build session
- `skill-curator` agent: validates auto-created skills

**Close-out checklist**:
- [ ] Local registers up to date (at least journal.md)
- [ ] HANDOVER written for the next session
- [ ] New learnings captured
- [ ] Resolved blockers marked as such
- [ ] Auto-created skills validated by the curator
- [ ] Promotion candidates listed (to be arbitrated later by the traffic-controller)

**Detail**: `doctrine/07-capitalisation.md`

## Frame 8 — Transposition

**Definition**: the method's applicability to any kind of domain (dev, content,
marketing, business).

**Templates**:
- `templates/lab.template/`: skeleton of a new lab (method + domain-complementary
  agents + `.vibeforge/category.txt` to file its deliverables)
- `templates/projet.template/`: **minimalist deliverable** (README + .gitignore, a pure
  client repo)
- `templates/projet-meta.template/`: **rich meta-project** (CLAUDE, HANDOVER, registers,
  docs/PRD, .claude/rules, settings.local.json) — lives in
  `<lab>/projets-meta/<project>/`

**Lab categories** (to file deliverables): `client` / `freelance` / `perso` /
`content` / `custom`. Set at lab creation via `<lab>/.vibeforge/category.txt`. All of a
lab's deliverables go into `<workspace>/projets/<category>/<project>/`.

**Bootstrap skills**:
- `/new-lab -Name <domain> -Category <client|freelance|perso|content|custom>`: creates a
  new lab from `lab.template/`
- `/new-projet -Name <name> -AffiliatedLab lab-<X>`: creates **2 folders**
  simultaneously:
  - `<workspace>/projets/<category>/<name>/` from `projet.template/` (the deliverable)
  - `<lab>/projets-meta/<name>/` from `projet-meta.template/` (the meta)

**Why the project/meta split**: see R002 in `registres/rules.md`. Deliverables must be
pushable to client remotes without Vibeforge pollution.

**Detail**: `doctrine/08-transposition.md`

## Frame 9 — Traffic

**Definition**: cross-lab consolidation via the dedicated `traffic-controller` agent.

**Mechanisms**:
- Periodic scan of local registers (manual `/traffic-controller scan all` or scheduled)
- Decides promotions (learning → global rule, blocker → rule, local BDR → global BDR)
- Justifies each decision in `registres/traffic-journal.md`
- Asks for user validation before an effective promotion
- Demotion logic: a rule not read in 180 days → proposes downgrading

**Detail**: `doctrine/09-trafic.md`

## Frame 10 — Self-improvement

**Definition**: each agent's ability to write its own skills from its experiences.

**Workflow**:
1. An agent identifies a reusable pattern
2. Prepares a draft SKILL.md
3. Invokes `skill-curator` via the Task tool
4. The curator analyzes (duplicates, overlaps, granularity, format)
5. The curator decides: approve / merge / revise / reject
6. If approved: final user validation → write

**Anti-spam**:
- `skill-curator` is mandatory (an agent cannot `Write` directly to another agent's
  skills)
- Controlled granularity (neither too broad nor too narrow)
- Index maintained by the curator for navigation

**Detail**: `doctrine/10-auto-amelioration.md`

## Frame 11 — Credentials & Secrets

**Definition**: a 3-level credentials-management pattern (vibeforge global / lab domain
/ project-specific). Identifies the optimal recording timing at each step of the
workflow.

**Materialization**:
- 3 levels of `.env` files (gitignored) + `.env.example` (committed, templates)
- Strict Zod validation at runtime on the application-code side
- No credentials in registers or agent-contexts
- A pre-commit hook for automatic secret-pattern auditing

**When to record**:
- Lab creation → `lab-architect` writes the domain's `.env.example`
- Project discovery → `business-analyst` identifies the services
- Project architecture → `architecte` specifies the precise variables
- Before build → `prompt-engineer` + `reviewer-prd` validate
- During a build session → the agent creates a Zod `env.ts` and tells you what to put in
  `.env`

**Special case**: Claude Code in OAuth (team account) → no `ANTHROPIC_API_KEY` needed for
the Vibeforge agents. Only needed for the projects' application code.

**Detail**: `doctrine/11-credentials-secrets.md`

## Frame 12 — Project workflow

**Definition**: how to go from an idea to a feature in production via Vibeforge. The 6
phases (creation → framing → PRD validation → S0 → S1..Sn → review → push → deploy) with
who talks to whom, who validates what, where the code lives.

**Guiding principle**: **a single Claude Code session per project** (cwd =
meta-project). Code is written into the deliverable via `additionalDirectories`. No more
session switching between framing and build — everything in the same session.

**Materialization**:
- `agent-contexts/lead/` (frame 4): the lead orchestrates all phases in the same session
- SendMessage pattern (R007): the lead stays wakeable during long framing
- `code-reviewer` agent: systematic phase 5 before push
- `/cloture-cadrage` skill: transition between framing and build

**Detail**: `doctrine/12-workflow-projet.md`

## Frame 13 — Memory scoping (extension of frame 4)

**Definition**: governs how Vibeforge agents manage their MEMORY across 2 levels
(universal + lab) + a cross-agent shared memory. **An extension of frame 4 Agents**, not
a fundamental frame.

**Materialization**:
- `agent-contexts/_shared/MEMORY.md` (≤300 words, loaded by ALL agents —
  cross-cutting stack/paths/IO constraints)
- `agent-contexts/<agent>/MEMORY.md` (universal agent level, ≤200 words)
- `<lab>/agent-contexts/<agent>/MEMORY.md` (lab level, ≤300 words)
- Project level **dropped** (redundant with lab MEMORY / meta-project HANDOVER)

**Mechanism (R009)**: pipeline — a consolidation pass proposes → `dream-validator`
filters apply/reject/defer → `/dream` applies automatically. Cadence 1×/day via the
session-start hook if >24h without a pass.

**Modes**: `/dream` (auto), `/dream manual` (debug), `/dream global` (workspace-wide,
cross-lab).

**Detail**: `doctrine/13-memory-scoping.md`

## Frame 14 — Agent delivery architecture

**Definition**: a **fundamental** frame that materializes the "how to deliver" decision
for a project with an AI-agent component. Forces an explicit comparison of architecture
options in the framing phase (instead of defaulting to a "custom app" out of habit).

**Materialization**: any project with an agent component MUST document in its PRD:
1. The chosen pattern among the options (deterministic custom app / managed agent
   service / self-hosted multi-agent / hybrid)
2. Why the others are rejected (comparative table, 5 criteria)
3. The integration pattern per external service (direct API / MCP tunnel / etc.)

**Pattern 0 (prerequisite)**: "Is there a mature OSS (80%+, MIT/Apache) that covers the
runtime need?" If yes → compose on top of it, don't reimplement.

**Who**: `business-analyst` discovers the criteria, `architecte` synthesizes the table,
`reviewer-prd` checks in the framing phase.

**Detail**: `doctrine/14-architecture-livraison-agent.md`

## Frame 15 — Bounded autonomous execution

**Definition**: a **safety** frame that defines when an agent / the `lead-auto` mode may
chain actions without a validation pause, and above all the STOP (HALT) conditions that
force a return to the human. Formalizes the existing behavior (anti-runaway Stop hook R4,
`maxTurns`, semi-auto default) into an explicit contract.

**Two regimes**: semi-auto (default, HITL) vs autonomous (`/lead-auto`, already-framed
work only).

**5 HALT codes**: DECISION (irreversible / outward-facing), SCOPE (out of scope / >~10
production files), LOOP (second failed fix -> systematic debugging), COST (token/time
drift), DOUBT (uncertain fact/name/intent -> CATALOG.md, never an invention).

**Escalation format**: `HALT-<CODE>` + options A/B/C + a recommendation. The operator
decides.

**Does not change the default behavior** (stays HITL). Backed by the existing hooks, no
new tooling.

**Detail**: `doctrine/15-execution-autonome.md`

## Frame 16 — Standalone labs (the generator model)

**Definition**: what Vibeforge OS *produces*. A **standalone lab** embeds a frozen copy
of the governance socle (`_method/`) plus the vendored generic agents and central skills,
and depends on **nothing external** — no plugin, no sibling clone. It runs on plain
Claude Code and can be handed to anyone as a folder or a git repo.

**Founding principle**: every standalone lab embeds a frozen copy of the SAME socle,
generated from a single source. Governance is designed centrally, distributed frozen —
a lab never rewrites its own doctrine by hand.

**Anatomy**: `_method/` socle (frozen, versioned via `_method/VERSION`) + 9 vendored
generic agents + 3 vendored central skills + the custom domain layer from the creation
interview + a full LOCAL capitalization loop (the lab learns in its own scope; nothing
syncs back).

**Creation interview**: adaptive depth with a mandatory floor — domain, deliverables,
agents, skills, connectors/APIs, privacy/security — covered before any stamp.

**Upgrades**: regenerate `_method/` (and only `_method/`) from a newer source. The
custom layer is never touched. `_method/` is regenerable; everything else is yours.

**Engine**: `/new-lab-standalone` + `scripts/new-lab-standalone.ps1` (deterministic).

**Detail**: `doctrine/16-labs-independants.md`

## Synthesis

Frames 1-8 ensure **discipline and memory**. Frames 9-12 ensure **scalability,
self-improvement, operational security, and an end-to-end project workflow**: what works
in one project rises automatically to the others (Traffic), the method enriches itself
(Self-improvement), credentials follow a strict 3-level pattern (Credentials & Secrets),
and each project follows a deterministic workflow from framing to production (Project
workflow). The extensions (13-16) add **automatic MEMORY consolidation** (Memory
scoping), **explicit framing of the delivery architecture** (Agent delivery
architecture), **bounded autonomous execution** (HALT conditions), and **standalone
lab generation** (frozen socle, zero-dependency labs you can hand to anyone). Together,
the **16 frames** make Vibeforge an **organic meta-method** ready for real production —
and **distributable**.

## Operational instrumentation layers

> Extensions that fit within existing frames — they add no new doctrinal concept but
> tool the existing frames so the method becomes observable, self-verifying, and
> scalable.

### Layer 1 — Empirical metrics (extension of frame 2)

**What**: `metrics/events.jsonl`, append-only, written by the PostToolUse + SessionEnd +
Stop hooks. Typed events (`tool`, `tool_error`, `agent_delegated`, `skill_invoked`,
`completion_claim`, `session_end`). The `/metrics-report` skill aggregates (top usage,
dormant items, archival candidates).

**Why**: without measurement, it is impossible to know whether a rule fired 0 or 50
times. Metrics turn the doctrine into empirical science → keep what pays, prune what
sleeps.

**Guardrail**: all metric writes are in silent try/catch. A metric NEVER breaks a
session.

### Layer 2 — Anti-hallucination verification (extension of frame 7)

**What**: the Stop hook parses the `.jsonl` transcript to match completion-claim patterns
(EN+FR). On a match → writes `<cwd>/.claude/verification-required.md`. The
`/verify-completion` skill checks each claim with concrete evidence (file exists, diff
non-empty, tests exit 0).

**Why**: an agent can say "I implemented X" or "tests pass" without it being true. The
hook flags it, the skill demands proof, the session does not close on thin air.

**Bootstrap**: CLAUDE.md step 6 — if the flag is present and recent → invoke
`/verify-completion` BEFORE any action.

### Layer 3 — Semantic embeddings (extension of frame 10)

**What**: `skills-index.embeddings.json` (generated by `scripts/embed-skills.mjs`). Query
via `scripts/embed-query.mjs`. `skill-curator` uses this retrieval for the
semantic-overlap check instead of a manual grep.

**Why**: at a handful of skills a manual scan suffices; at 50+ it becomes a bottleneck.
The infra is in place early, ready for growth.

**Fallback**: if the embeddings provider key is absent or rate-limited, `skill-curator`
falls back to a classic grep without breaking anything.
