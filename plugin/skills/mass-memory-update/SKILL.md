---
name: mass-memory-update
description: Parallel update of the MEMORY.md files of amnesic agents (detected by /audit-memory-age) via Dynamic Workflow. Each agent re-reads its history and compresses its MEMORY (R016 <=500 words). Writes to distinct files = safe.
when_to_use: |
  After a /audit-memory-age listing several amnesic agents (>14d without update despite invocations).
  To catch up the MEMORY debt of several agents at once instead of one by one.
  Requires the Workflow tool (Claude Code runtime Opus 4.8+).
allowed-tools: Workflow Read
argument-hint: "<agents separated by spaces, e.g. 'architecte ux prompt-engineer'>"
---

You are going to refresh the MEMORY of several agents in parallel.

## Step 1 — Agent list

- Argument provided → use it (e.g. `architecte ux prompt-engineer`).
- Otherwise → run `/audit-memory-age` first, present the list of amnesic agents, ask for confirmation before spawning.

## Step 2 — Launch the Workflow

Invoke `Workflow` with this script. **Write the `agents` list directly in the script** (not via `args` — not bound to the inline script):

```javascript
export const meta = {
  name: 'mass-memory-update',
  description: 'Parallel MEMORY update, 1 real agent per MEMORY',
  phases: [{ title: 'Update' }]
}

// Write your list HERE (from step 1) — NOT via args:
const agents = ['architecte', 'ux', 'prompt-engineer'] // ← REPLACE with the detected amnesic agents

const results = await parallel(agents.map(a => () =>
  agent(
    `You are invoked for a MEMORY UPDATE only.\n` +
    `1. Minimal bootstrap: SOUL/USER/MEMORY + your journal.md (NOT the whole doctrine).\n` +
    `2. Re-read your recent interventions (journal + git log of your outputs).\n` +
    `3. Rewrite agent-contexts/${a}/MEMORY.md: compress to <=500 words (R016), keep durable patterns, archive the perishable into journal.md.\n` +
    `4. Touch ONLY your own MEMORY.md and journal.md. No other file.\n` +
    `Return: old word count → new word count + summary of changes.`,
    { agentType: `vibeforge:${a}`, label: `memory:${a}`, phase: 'Update' }
  )
))

return agents.map((a, i) => ({ agent: a, result: results[i] }))
```

## Step 3 — Report

For each agent: old→new word count + what changed. Flag failures (result `null`). Suggest a new `/audit-memory-age` to confirm the amnesic agents are resolved.

## Guardrails / parallelization safety

- **Safe**: each agent writes into ITS OWN `MEMORY.md`/`journal.md` (distinct files → no concurrent write conflict).
- NEVER include two agents that would write the same file in a single run.
- We use the **real agents** (no lightweight worker): each must reflect on ITS OWN history. Token cost ≈ sequential; the gain is **time** (xN).
- Do not include `_shared/MEMORY.md` here (writes reserved for `/dream`, conflict risk).
