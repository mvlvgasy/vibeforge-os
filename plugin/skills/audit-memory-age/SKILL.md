---
name: audit-memory-age
description: Scans the agents' MEMORY.md files (3 levels), computes age, detects amnesic agents (>14d without update despite invocations). Report + recommendations.
when_to_use: |
  Health diagnostic of the agents' learning system.
  Invoke weekly or when you suspect the agents are forgetting.
  Example: /audit-memory-age, /audit-memory-age --threshold 30
allowed-tools: Read Glob Bash
argument-hint: "[--threshold <days>]"
---

## Purpose

This skill materializes an **objective measurement** of how the agents' MEMORY system (R009) is working. It answers the question: *"Are my agents actually learning, or are they freezing their MEMORY at bootstrap?"*

It makes the learning debt visible — without it, agents can keep their MEMORY frozen at the initial bootstrap date while still being invoked.

## When to use

- Weekly diagnostic (recommendation: every Friday)
- When `/cloture-session` or another mechanism suggests that capitalization is lagging
- Before an R009 promotion or an agent rework: knowing the initial state
- When a sub-agent seems "amnesic" (repeats the same mistakes)

## Inputs

- `--threshold <days>` (optional, default 14): alert threshold. An agent whose MEMORY has not been updated in > threshold days is listed as a red alert.

## Methodology

### Step 1 — Scan the agent-contexts at 3 levels

Glob to find all MEMORY.md at the 3 R009 levels:

1. **Universal level**: `<workspace>/agent-contexts/*/MEMORY.md`
2. **Lab level**: `lab-*/agent-contexts/*/MEMORY.md`
3. **Project level**: `lab-*/projets-meta/*/agent-contexts/*/MEMORY.md` (may be empty if no project has yet created a specific agent-contexts)

### Step 2 — For each MEMORY.md found

Bash one-liner to retrieve metadata:
```bash
stat -c "%y" <path>  # file last-modified date (filesystem)
```

And search the content for any "Last update" / "Last updated" / "State as of YYYY-MM-DD" to get the date declared by the agent.

### Step 3 — Compute age

`age = today - max(filesystem_mtime, declared_last_update)`

### Step 4 — Cross-check with metrics

Read `<workspace>/metrics/events.jsonl` (Tier 1 metrics). For each agent, count the number of `kind=agent_delegated` invocations in the last `threshold` days.

**Alert heuristic**: an agent is "amnesic" if:
- MEMORY age > threshold AND
- Invocations > 3 over the same period

→ It was actively invoked but never updated its MEMORY. This is a signal of a doctrinal bug or agent-side friction.

### Step 5 — Detect pending R009 markers

Glob `<workspace>/agent-contexts/*/.memory-update-pending.md` (markers left by the post-tool-use hook for long sub-agents). List the agents with an unresolved pending marker.

### Step 6 — Output markdown report

Strict format:

```markdown
# MEMORY audit report — <YYYY-MM-DD HH:mm>

## Summary

- **Agents audited**: <N>
- **Healthy agents** (age <= <threshold>d): <X>
- **Amnesic agents** (age > <threshold>d AND >3 invocations): <Y>
- **Unresolved pending R009 markers**: <Z>

## Current MEMORY pyramid (R009 target: 5/15/80%)

- Universal: <N> MEMORY, last update <date>
- Lab: <N> MEMORY, last update <date>
- Project: <N> MEMORY, last update <date>

## Detail per agent

| Agent | Level | Age | Invocations (<threshold>d) | Status | Action |
|-------|-------|-----|----------------------------|--------|--------|
| lead | universal | 5d | 12 | OK | OK |
| architecte | universal | 30d | 8 | amnesic | invoke in update mode |
| business-analyst | universal | 1d | 0 | inactive | normal if no recent framing |
| ... |

## Pending markers detected

| Agent | Marker date | Sub-agent duration |
|-------|-------------|--------------------|
| lead | <YYYY-MM-DD HH:MM> | 387 sec |

## Recommendations

- For amnesic agents: invoke in explicit update mode — "<agent> re-read your recent interventions and update your MEMORY"
- For pending markers: invoke each concerned agent to handle its marker
- If the pyramid is inverted (lots of universal, few project): drift signal, dispatch traffic-controller
```

## Output path

Write the report into `<workspace>/metrics/memory-audit-<YYYY-MM-DD-HHmm>.md`.

Return to the caller: report path + a 5-line summary.

## Anti-patterns

- Blocking if an agent has no MEMORY.md (skip silently, log a warning)
- Modifying the MEMORY files directly — this skill is READ-ONLY (the audit reveals, it does not fix)
- Counting the initial bootstrap as "first update" — there must be an explicit "updated by <agent> at <date>" mark in the MEMORY to validate that it is a real update
- Alerting on never-invoked agents (false positive — a rarely used agent can legitimately have an old MEMORY)

## Verification

The skill ran correctly if:
1. The report exists at the expected path
2. At least the core agents are listed (or justification for absence)
3. Cross-check with metrics events.jsonl performed (see Step 4)
4. Actionable recommendations produced (not fluff)

## Examples

```
User: /audit-memory-age
```

Output: Report generated in `<workspace>/metrics/memory-audit-<YYYY-MM-DD-HHmm>.md`. 12 agents audited, 11 amnesic (>14d without update despite invocations), 1 pending marker.

```
User: /audit-memory-age --threshold 30
```

Output: threshold widened to 30d. Amnesic agents redefined. Useful for a less severe monthly audit.

---

**Related rules**: R009 (3-level scoped MEMORY), R008 (tri-layer cloture-session)
