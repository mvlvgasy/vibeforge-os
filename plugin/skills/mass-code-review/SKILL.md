---
name: mass-code-review
description: Parallel review of a large diff — 1 lightweight worker per module via Dynamic Workflow, adversarial verification of blockers, aggregation + global verdict. For changesets >5 files.
when_to_use: |
  End of a build session with a large diff (several modules / >5 files).
  When a sequential code-reviewer risks diluting the context module by module.
  Requires the Workflow tool (Claude Code runtime Opus 4.8+).
allowed-tools: Workflow Bash Read
argument-hint: "(optional: scope, e.g. 'HEAD~3' or 'src/lib/auth src/components')"
---

You are going to run a parallel review via Dynamic Workflow.

## Step 1 — Split the scope (inline, BEFORE the workflow)

Scope the work yourself:
- `git diff --name-only <base>` to list the changed files (base = argument, default `HEAD~1`).
- Group into coherent modules (by top-level folder, or by feature).
- Build the `modules` list (e.g. `['src/lib/auth', 'src/components/dashboard', 'src/app/api']`).
- If <3 modules: no point parallelizing, recommend the classic `/code-reviewer`.

## Step 2 — Launch the Workflow

Invoke the `Workflow` tool with this script. **Write the `modules` list (+ the `base`) directly in the script** — the `args` mechanism does NOT bind to the inline script in this runtime (verified empirically):

```javascript
export const meta = {
  name: 'mass-code-review',
  description: 'Parallel review 1 worker/module + blocker verification',
  phases: [{ title: 'Review' }, { title: 'Verify' }]
}

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    module: { type: 'string' },
    verdict: { type: 'string', enum: ['OK', 'MINOR', 'BLOCKER'] },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['BLOCKER', 'MINOR', 'INFO'] },
          file: { type: 'string' },
          line: { type: 'number' },
          title: { type: 'string' },
          why: { type: 'string' }
        },
        required: ['severity', 'file', 'title', 'why']
      }
    }
  },
  required: ['module', 'verdict', 'findings']
}

const VERIFY_SCHEMA = {
  type: 'object',
  properties: { confirmed: { type: 'boolean' }, reason: { type: 'string' } },
  required: ['confirmed']
}

// Write your list HERE (from step 1) — NOT via args (not bound to the inline script):
const modules = ['src/lib/auth', 'src/components/dashboard'] // <- REPLACE with your modules
const base = 'HEAD~1' // <- REPLACE (e.g. 'HEAD~3', a SHA, 'origin/main')

const reviews = await pipeline(
  modules,
  // Stage 1 — a lightweight worker reviews the module
  mod => agent(
    `Review this scope. First run \`git diff ${base} -- ${mod}\`, then review (bugs, security, data-privacy, quality).\nScope: ${mod}`,
    { agentType: 'vibeforge:_workers:module-reviewer', label: `review:${mod}`, phase: 'Review', schema: FINDINGS_SCHEMA }
  ),
  // Stage 2 — adversarial verification of ONLY the blockers (kills false positives)
  (review, mod) => {
    const blockers = (review?.findings || []).filter(f => f.severity === 'BLOCKER')
    if (!blockers.length) return review
    return parallel(blockers.map(b => () =>
      agent(
        `Try to REFUTE this BLOCKER finding. Module ${mod}, ${b.file}:${b.line || '?'} — ${b.title}. Stated reason: ${b.why}. Is it real? (default: confirmed=true if in doubt)`,
        { agentType: 'vibeforge:_workers:module-reviewer', label: `verify:${b.file}`, phase: 'Verify', schema: VERIFY_SCHEMA }
      ).then(v => ({ ...b, confirmed: v?.confirmed !== false, verifyReason: v?.reason }))
    )).then(verified => ({
      ...review,
      findings: [...review.findings.filter(f => f.severity !== 'BLOCKER'), ...verified]
    }))
  }
)

return reviews.filter(Boolean)
```

## Step 3 — Aggregate + report

When the workflow completes:
- Confirmed blockers = findings `severity === 'BLOCKER' && confirmed !== false`.
- Global verdict: `BLOCKER` if >=1 confirmed blocker, else `MINOR` if >=1 minor, else `OK`.
- Write the report in `<project>/docs/code-reviews/mass-review-<date>.md` (same convention as `/code-reviewer`). You add the date (outside the script — `Date.now()` is forbidden in the DW script).
- Present the synthesis to the operator: global verdict + confirmed blockers first.

## Anti-patterns
- Launching without having written the `modules` list in the script.
- Using `agentType: 'vibeforge:code-reviewer'` (33k bootstrap x N) instead of the lightweight worker — unless <3 modules (then use `/code-reviewer` directly).
- Presenting an unverified blocker — the Verify step exists for that.
- Forgetting that real concurrency = `CPU cores − 2` (modules beyond that run in waves).
