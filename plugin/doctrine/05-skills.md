# Frame 5 — Skills

> Specific, activatable capabilities. Standard Anthropic Agent Skills format.

## Definition

A skill is a **reusable procedure** that agents (or you) can invoke. It is what turns a "know-how" into a "tool mobilizable on demand".

## Three sources of skills

### 1. Vibeforge skills (cross-cutting)
- Location: `vibeforge/.claude/skills/<name>/SKILL.md`
- Scope: available in all labs/projects inheriting from Vibeforge
- Examples: `/new-lab`, `/new-projet`, `/cloture-session`, `/review-prd-coverage`, `/promote-learning`

### 2. Agent-specific skills (auto-created)
- Location: `agent-contexts/<agent>/skills/<name>.md`
- Scope: internal use by a specific agent
- Examples: `architecte/skills/deploy-vercel-bolt.md`, `lead/skills/cadrage-client-acme.md`

### 3. External skills (Superpowers + others)
- Source: the obra/superpowers plugin installed globally
- Scope: invocable by any agent that has Skill in its tools
- Examples: `superpowers:brainstorming`, `superpowers:test-driven-development`

## Standard Anthropic Agent Skills format

```yaml
---
name: <kebab-case-name>
description: <what the skill does and when to use it, 1-2 sentences>
when_to_use: <specific triggers, optional>
disable-model-invocation: <true if manual only>
allowed-tools: <pre-approve tools, optional>
---

## Purpose
<What this skill is for>

## When to use
<Explicit triggers>

## Methodology
<Numbered steps>

## Anti-patterns
<What NOT to do>

## Examples
<Concrete examples>

## Verification
<How to verify the skill worked>
```

Minimum required: 3 of the 5 sections (Purpose / Methodology / Anti-patterns / Examples / Verification).

## Preloading vs on-demand invocation

### Preloaded skills (`skills:` in agent frontmatter)
```yaml
skills:
  - superpowers:brainstorming
  - superpowers:writing-plans
  - vibeforge:promote-learning
```
- Loaded into the context window AT AGENT STARTUP
- Always available, no need to invoke
- Cost: tokens in permanent context (so 2-4 max per agent)
- For FUNDAMENTAL skills the agent uses almost systematically

### On-demand skills (via `Skill` in `tools:`)
- The agent invokes via `Skill("<name>")` when it needs it
- No permanent context cost
- Cost: 1 turn of a Skill tool call when used
- For situational skills (debugging, tests, refactoring, etc.)

Recommendation: 2-4 preloaded + an open Skill palette for the rest.

## Skill auto-creation (validated workflow)

1. **The agent identifies a reusable pattern** (at least 2 occurrences seen)
2. **The agent checks the INDEX** of existing skills (`agent-contexts/<self>/skills/INDEX.md` + `vibeforge/.claude/skills/`)
3. **The agent prepares a draft SKILL.md** (without writing it)
4. **The agent invokes skill-curator** via the Task tool with the draft
5. **The curator analyzes** (duplicates, overlaps, granularity, format, relevance)
6. **The curator decides**: approve / merge / revise / reject
7. **If approve**: the curator asks you for final validation
8. **If you validate**: the curator writes the file + updates the INDEX
9. **The requesting agent receives confirmation**

## Vibeforge V1 bootstrap skills

Created in S1 (minimalist V1, finalized in S3):

- **`/new-lab`**: bootstrap a new lab from the template
- **`/new-projet`**: bootstrap a new project in a lab
- **`/cloture-session`**: end-of-session audit, forced capitalization
- **`/review-prd-coverage`**: PRD coverage audit before a build session
- **`/promote-learning`**: used by the traffic-controller to formalize a promotion

## On-demand skills typically used

Via Superpowers (already installed):
- `/superpowers:brainstorming` — intent exploration before build
- `/superpowers:writing-plans` — decomposition into steps
- `/superpowers:test-driven-development` — enforced TDD
- `/superpowers:systematic-debugging` — structured debugging
- `/superpowers:verification-before-completion` — check before claiming "done"
- `/superpowers:requesting-code-review` — formal review
- `/superpowers:finishing-a-development-branch` — merge / PR / cleanup

## Anti-patterns

- ❌ Too many skills (>50 global in Vibeforge) → the INDEX becomes unreadable
- ❌ Skills too granular ("add-import-X-in-file-Y") → make it a learning instead
- ❌ Skills too broad ("how-to-code") → decompose or refuse
- ❌ Skills without a clear `description` → Claude does not know when to invoke them
- ❌ Skill auto-creation without going through skill-curator → spam and redundancy
- ❌ Skills that duplicate what Superpowers does → check what exists first
- ❌ Preloading 10+ skills on an agent → permanent context saturated

## See also

- Frame 4: Agents (who invokes the skills)
- Frame 10: Self-improvement (the auto-creation workflow)
- Official Claude Code docs: [Skills](https://code.claude.com/docs/en/skills)
