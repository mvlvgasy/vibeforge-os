---
name: forge-worker
description: Create a custom DW worker in agents/_workers/ (lightweight, inlined context, cheap model). To grow the reusable fleet. Callable only AFTER a session restart (registration happens at startup).
when_to_use: |
  When a RECURRING DW task deserves a dedicated reusable worker the fleet does not have yet.
  NOT for a one-off "here and now" need in a running DW run -> use the INLINE pattern
  (see agents/_workers/README.md), because a freshly created worker only resolves on the next startup.
allowed-tools: Write Edit Read Bash
argument-hint: "<worker-name> : <what it must do>"
---

# Forge a DW worker

## Key constraint to announce BEFORE creating

A worker created now is **NOT callable in the current session**: `agentType` registration happens at Claude Code startup. -> This skill **grows the fleet for later**, it does NOT unblock a running DW run. For an immediate need -> **INLINE pattern** (`agents/_workers/README.md`).

## Step 1 — Frame the worker

From the argument, derive:
- **name** (kebab-case: `compliance-scanner`, `i18n-extractor`...)
- **role**: the single, precise task
- **minimal context to inline**: only the essentials (conventions, red flags) — NOT all of Vibeforge
- **model**: Haiku if mechanical, Sonnet if judgment. **Never Opus.**
- **tools**: read-only by default (`Read, Grep, Glob`, + `Bash` if a script). No `Edit/Write/Task` unless justified.

## Step 2 — Show the draft + confirm

Present the frontmatter + body to the operator. Wait for OK (this mutates the parent method).

## Step 3 — Write the file

`agents/_workers/<name>.md` modeled on `module-reviewer.md` / `transcript-analyzer.md`:
`## You do NOT bootstrap Vibeforge` -> `## Minimal context (inlined)` -> `## Your mission` -> `## Output` (schema-friendly) -> `## Guardrails` (low maxTurns, read-only).

## Step 4 — Register

1. A row in the "Current fleet" table of `agents/_workers/README.md`.
2. Run `${CLAUDE_PLUGIN_ROOT}/scripts/sync-plugin.ps1`.
3. **Tell the operator: restart Claude Code** so that `vibeforge:_workers:<name>` resolves.

## Anti-patterns
- Forging a worker to use it in the current DW run (it will not resolve -> inline pattern).
- A heavy worker (full Vibeforge bootstrap) — that would be a complete agent, not a worker.
- A worker on Opus.
- Writing without showing the draft (parent-method mutation).
