# Frame 1 — Constitution

> The root directive that states "who this project is" and "what we do in it".

## Definition

The constitution is the mandatory starting point for every agent. Before any action, an agent reads the constitution of the current context (root method, lab, or project) to align with the applicable identity and rules.

## Where it lives

### Root-method level (Vibeforge)
- `vibeforge/CLAUDE.md` — generic operational rules (what we do, how)
- `vibeforge/SOUL.md` — stable identity (what we are, why)
- `vibeforge/DOCTRINE.md` — synthesis of the frames
- `vibeforge/registers/rules.md` — non-negotiable cross-cutting rules

### Lab level
- `<lab>/CLAUDE.md` — inherits from Vibeforge + adds the domain context (a client, content, freelance...)
- `<lab>/SOUL.md` — the lab's specific identity
- `<lab>/domain-context.md` — the domain corpus (stack, compliance, PRD format...)

### Project level (deliverable / meta split)

A project is in fact **TWO folders**:

1. **The deliverable** (`<workspace>/<project>/`):
   - Standalone git repo, pushable to the client's remote (e.g. `github.com/your-org/<project>/`)
   - **Pure code only**: `src/`, `package.json`, `README.md`, `.gitignore` — nothing of Vibeforge inside
   - No Claude Code session has its cwd here (no local method)

2. **The meta-project** (`<lab>/projects-meta/<project>/`):
   - Lives inside the lab (versioned with the lab, private)
   - Contains: `CLAUDE.md`, `HANDOVER.md`, `docs/PRD.md`, `docs/architecture.md`, `docs/transcription-*.md`, `docs/prd-coverage-reports/`, `registers/`, `.claude/rules/00-project-context.md`, `.claude/settings.local.json`
   - **This is WHERE the Claude Code session runs** (cwd = meta-project)
   - Agents read the method here and write code into `../../../<project>/` (the deliverable) via `additionalDirectories`

**Why this split**: it lets you push the deliverable to a client repo without polluting it with the Vibeforge method, PRD drafts, stakeholder notes, etc. The client gets a clean repo, the team keeps the method private.

**`.claude/rules/00-project-context.md`** lives in the meta-project, not in the deliverable.

## Vibeforge innovation: SOUL ↔ CLAUDE separation

Inspired by autonomous-agent identity patterns. The distinction:

| SOUL.md | CLAUDE.md |
|---------|-----------|
| Stable identity | Operational rules |
| "Who I am" | "What I do" |
| Rarely modified | Evolves with usage |
| Personality, values, reason to exist | Workflows, conventions, constraints |

Benefit: the entity's personality (lab, project, agent) stays stable even when the technical rules move. This is what gives the feeling of cross-session "continuity".

## Inheritance hierarchy

```
Vibeforge (root method)
    │ inherits
    ▼
Lab (specialized domain)
    │ inherits
    ▼
Project (code work)
```

Inheritance rules:
1. The local **extends** the global
2. The local may **specialize** a global rule (e.g. "stack: TypeScript strict" locally for a TS project)
3. The local MUST NOT **contradict** a global rule (R001, R002...) without signaling the traffic-controller for arbitration

## Minimal format of a CLAUDE.md

```markdown
# <Context name> — Constitution

## Identity
You are a Claude Code agent operating in <context>. You inherit from <parent>.

## Mandatory bootstrap
1. <parent>/CLAUDE.md
2. <parent>/registers/rules.md
3. This file
4. The local registers

## Non-negotiable local rules
- R-local-1: ...
- R-local-2: ...

## Where things live
<inventory of folders and their role>

## Meta
- Version
- Creation date
- Builder
```

## Minimal format of a SOUL.md

```markdown
# SOUL — <Name>

## I am <X>
<Description in 1-2 paragraphs>

## My personality
- <Trait 1>
- <Trait 2>

## What I never do
- <Forbidden action>

## My reason to exist
<Why this entity exists>

## My communication style
<Tone, language, level of formality>
```

## When to modify the constitution

- **CLAUDE.md**: at each significant capitalization session that reveals a new operational need
- **SOUL.md**: only if the fundamental identity changes (rare — maybe once a year)
- **DOCTRINE.md**: only if a new frame is added (unlikely beyond the current set)

## Anti-patterns

- Constitution too long (>200 lines for CLAUDE.md, >100 for SOUL.md) — becomes unreadable and nobody follows it
- Constitution too generic (copy-paste between projects) — loses its framing usefulness
- Constitution with no explicit bootstrap — agents don't know where to start
- Constitution that contradicts the root method — open a debate record instead

## See also

- Frame 2: Registers (living memory referenced by the constitution)
- Frame 6: Rules (crystallized rules called by the constitution)
