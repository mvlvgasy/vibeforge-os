---
name: recover-cadrage
description: Rebuilds a project's lost framing memory by re-reading a .jsonl session transcript, via deterministic condensation + Dynamic Workflow. Last-resort safety net when a framing session has "zero memory" after multiple compactions (R018). Token-efficient (condenses 10-15x before reading).
when_to_use: |
  When a long framing session has lost its context (multiple compactions, /clear) and no up-to-date
  MEMORY-cadrage.md exists to reload it. We then rebuild from the raw transcript.
  Requires the Workflow tool (Dynamic Workflows).
  If a MEMORY-cadrage.md exists and is up to date: no need, reading it is enough.
allowed-tools: Read, Write, Bash, Glob, Workflow
argument-hint: "<session-id or path to the .jsonl> [target project]"
---

You rebuild the **framing memory** of a project from a session transcript, when the live memory was lost to compactions. This is the last-resort safety net of R018.

## Principle

A `.jsonl` transcript of a long session often weighs 10+ MB (mostly tool_results). Reading it whole would blow up the token budget. So:
1. **Condense** the transcript deterministically (free): keep only user turns + assistant text/reflection + 1 line per tool_use. Typically 10-15x smaller.
2. **Dynamic Workflow**: several readers in parallel over slices of the condensed file extract (planned sessions, decisions, why, key facts), then a synthesis rebuilds the chronological roadmap.
3. **Write** the result into the project's `MEMORY-cadrage.md`.

## Method

### 1. Locate the transcript
If `$ARGUMENTS` gives a `.jsonl` path: use it. If it's a session-id, search:
```bash
find "$HOME/.claude/projects" -name "<session-id>*.jsonl" 2>/dev/null
```
(on Windows: `C:/Users/<user>/.claude/projects/`). Note the size (`ls -lh`) and line count (`wc -l`).

### 2. Condense
```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/condense-transcript.mjs" "<transcript.jsonl>" "<tmp>/condensed.md"
```
The script prints the condensed size and the number of user turns. Get the `wc -l` of the condensed file for slicing.

### 3. Dynamic Workflow extraction
Run a Workflow: slice the condensed file into ~5 equal slices (by line range), 1 reader agent per slice (Read with offset/limit) extracting JSON {planned_sessions, decisions, why_context, key_facts}, then 1 synthesis agent that dedups and rebuilds a structured Markdown (Why / Chronological roadmap / Decisions / Technical facts / Uncertainty zones).

Legitimate barrier here: the synthesis needs ALL slices. So `parallel()` (readers) then a synthesis `agent()`.

### 4. Write the memory
Write the synthesis into `<project>/MEMORY-cadrage.md` with the frontmatter (type: memoire-cadrage, source: the session-id, methode: recover-cadrage DW, status: active). If a file already exists, propose a merge rather than an overwrite.

### 5. Report to the operator
Present the synthesis + flag the uncertainty zones to reconfirm (the reconstruction is not gospel).

## Notes

- This is a **last resort**. The goal of R018 is to NEVER reach this point thanks to regular `/save-cadrage`. If you run `/recover-cadrage` often, the `/save-cadrage` discipline isn't being kept.
- The temporary condensed file can go in `_audit-tmp/` or a tmp folder; do NOT commit it.
- Typical cost: condensation is free; the DW distributes the reading across several agents (far cheaper than reading the raw .jsonl in the main context).

## Anti-patterns

- Reading the raw `.jsonl` whole in the main context (ruinous).
- Overwriting an up-to-date `MEMORY-cadrage.md` without a merge.
- Presenting the reconstruction as certain (always mark the uncertainty zones).

Target: $ARGUMENTS
