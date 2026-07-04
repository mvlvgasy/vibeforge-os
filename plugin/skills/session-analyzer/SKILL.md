---
name: session-analyzer
description: Analysis of .jsonl transcripts (cost, tokens, cache, compactions). Method 1 (default) = deterministic script analyze-transcript.mjs (reliable, instant, free). Method 2 = DW + worker to interpret N sessions in parallel. Correct Opus pricing ($5/$25).
when_to_use: |
  Audit of token/cost consumption on one or more sessions.
  Re-measurement of gains post-optimization.
  Method 2 (DW) requires the Workflow tool + registered workers (session restart required).
allowed-tools: Bash Glob Read Workflow
argument-hint: "(optional: glob/folder of .jsonl, or date range; default = current project)"
---

## Design lesson (read this first)

Metrics extraction is **deterministic** work -> a **script**, not an LLM. An agent that "estimates" costs by grepping a large `.jsonl` produces garbage (e.g. "$34 for 426 tokens").

- **Method 1 (default)**: you want the NUMBERS -> run the script. No DW needed.
- **Method 2 (DW)**: you want to INTERPRET many sessions in parallel (qualitative) -> DW + worker, where each worker runs the script THEN comments.

## Step 1 - List the transcripts

- `~/.claude/projects/<encoded-project>/*.jsonl` or the path/glob passed as argument. Filter by date if requested.

## Method 1 - Deterministic script (recommended)

The script accepts several files and outputs a recap + totals:

```powershell
$files = Get-ChildItem "<dir>" -Filter *.jsonl | Sort-Object Length | ForEach-Object FullName
node "${CLAUDE_PLUGIN_ROOT}/scripts/analyze-transcript.mjs" @files
```

JSON output: `{ sessions:[{ costUsd, inputTokens, outputTokens, cacheReadTokens, cacheWrite1hTokens, messages, toolUses, compactions, durationMin, runtime }], totals:{...} }`.
Present the recap table + total $. **Instant, free (no LLM), reliable.**

## Method 2 - DW + worker (parallel interpretation at scale)

When you want a qualitative COMMENT per session (not just the numbers) AND there are many sessions. Invoke `Workflow` with this script. **Write the `files` list directly in the script** (not via `args` - not bound to the inline script):

```javascript
export const meta = {
  name: 'session-analyzer',
  description: 'Parallel interpretation, 1 Haiku worker per session (numbers via deterministic script)',
  phases: [{ title: 'Analyze' }]
}

const SESSION_SCHEMA = {
  type: 'object',
  properties: {
    sessionFile: { type: 'string' },
    costUsd: { type: 'number' },
    inputTokens: { type: 'number' },
    outputTokens: { type: 'number' },
    cacheReadTokens: { type: 'number' },
    compactions: { type: 'number' },
    runtime: { type: 'string' },
    insight: { type: 'string' }
  },
  required: ['sessionFile', 'costUsd', 'insight']
}

// Write your absolute paths HERE (from step 1) - NOT via args. Forward slashes '/' OK on Windows:
const files = ['C:/Users/<you>/.claude/projects/<project>/<sessionA>.jsonl'] // <- REPLACE

const results = await parallel(files.map(f => () =>
  agent(
    `Run the analyze-transcript.mjs script on this file (deterministic numbers), take its JSON as-is, add an insight field (1-3 sentences on what cost the most). File: ${f}`,
    { agentType: 'vibeforge:_workers:transcript-analyzer', model: 'haiku', label: `analyze:${f.split(/[\\/]/).pop().slice(0,8)}`, phase: 'Analyze', schema: SESSION_SCHEMA }
  )
))

return results.filter(Boolean)
```

## Step 3 - Aggregate

Recap table + total $ (script numbers, reliable). Optional: write `${CLAUDE_PLUGIN_ROOT}/metrics/session-analysis-<date>.md` (date outside the script).

## Note
Replaces ad-hoc Python scripts (erroneous $15/$75 pricing -> ~3x overestimation). **Source of truth for the numbers = `scripts/analyze-transcript.mjs`** (deterministic). The LLM only interprets, never computes.
