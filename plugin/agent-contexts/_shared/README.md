# Cross-agent shared memory — Convention

> File `_shared/MEMORY.md` loaded by ALL Vibeforge agents at bootstrap.
> Cross-cutting shared patterns (vs `<agent>/MEMORY.md` which is agent-specific).
>
> **Anti-junk-drawer**: the writing discipline is strict. If it is ignored,
> the shared file becomes unreadable and loading it costs tokens for nothing.

## Why `_shared`

Introduced in R009 v2. A solution to the problem "genuinely cross-cutting patterns are duplicated in every agent MEMORY" (e.g. shared technical stack, path conventions, global compliance constraints).

Without `_shared`: if the shared stack moves from one framework version to the next, you would have to update the MEMORY of the architecte, the ux, the prompt-engineer, the code-reviewer, etc. With `_shared`: a single update.

## Strict criteria for writing into `_shared`

An insight goes into `_shared` ONLY if **all 3 conditions are true**:

1. **Cross-agent**: relevant to ≥2 different Vibeforge agents
2. **Cross-lab**: applicable independently of the lab (or applicable to all labs)
3. **Stable**: does not change every day (frozen stack versions, path conventions, etc.)

If a single condition is missing → the insight goes into `<agent>/MEMORY.md` (agent-universal) or `<lab>/agent-contexts/<agent>/MEMORY.md` (lab-scoped).

## Writing mechanism

**No agent writes directly into `_shared/MEMORY.md`.** Writing happens via:

1. The agent **observes** a pattern in its session
2. The agent **appends** to its `journal.md` (chronological)
3. The **dreamer** (`vibeforge-dreamer`) scans the journals on the next `/dream`
4. The dreamer **detects** that the pattern appears in ≥2 different agents
5. The dreamer **proposes** the promotion to `_shared` in `pending-updates.md`
6. **The operator validates** via `/dream`
7. The `/dream` skill **applies** the update (Edit `_shared/MEMORY.md`)

So: no direct Write, ever. Always via dreamer + validation.

## Delimited sections (target structure)

To avoid the junk drawer, `_shared/MEMORY.md` has a FROZEN structure:

```markdown
# Shared MEMORY — Vibeforge cross-agent

## Shared technical stack
<framework versions, target PowerShell, etc.>

## Path conventions
<where things live: repos, labs, projects, workspace root>

## Cross-cutting compliance constraints
<global GDPR rules, mail format, etc. — genuinely cross-cutting, not lab-specific>

## Cross-agent orchestration patterns
<how agents collaborate, typical invocation order, contract patterns>

## Cross-cutting anti-patterns
<what no agent should do, regardless of specialty>

## Meta (Vibeforge versions, Claude Code plugin constraints)
<active Vibeforge version, minimum Claude Code version, etc.>
```

**Every dreamer proposal MUST map to one of these 6 sections.** If it does not map → the insight probably does not belong in `_shared`. The dreamer must push it back to `<agent>/MEMORY.md` or `<lab>/agent-contexts/<agent>/MEMORY.md`.

## Strict limit: ≤300 words total

`_shared/MEMORY.md` NEVER exceeds 300 words. This is the counterweight to "loaded by all agents at bootstrap" — if you let it explode, you pay the cost × all agents × hundreds of sessions/month.

If a new addition exceeds 300 words:
- Either consolidate (shorten an existing section)
- Or push the addition back to a less-shared level

The `/dream` skill checks this limit before Edit. If there is an overflow, it flags it to the operator.

## Anti-patterns

- ❌ Writing a 1-agent insight into `_shared` ("it's important anyway") → that's agent-universal, not shared
- ❌ Writing a lab-specific insight into `_shared` ("it could be useful everywhere") → that's lab, not shared
- ❌ Doing a direct Write (without dreamer + validation) → circumventing R009 v2
- ❌ Exceeding 300 words ("we'll consolidate later") → consolidate NOW, otherwise it never happens
- ❌ Adding sections beyond the 6 frozen ones → dilution, loss of structure
- ❌ Putting secrets / PII into `_shared` (committed to Git) → R3 is sacred

## Health audit

Target metrics:
- Volume ≤300 words (HARD)
- Update frequency: 1×/week maximum (otherwise you touch too often a file that must stay stable)
- Sections: 6 frozen (never more)
- Acceptance rate of dreamer proposals toward `_shared`: <30% (if more, the dreamer over-proposes at the shared level)

## See also

- `MEMORY.md` (alongside) — the current state
- `doctrine/13-memory-scoping.md` — the doctrine v2
- `registres/rules.md#R009` — the rule
- `agents/dreamer.md` — the agent that proposes the updates
- `skills/dream/SKILL.md` — the application workflow
