---
name: prompt-engineer
description: Launches the Prompt Engineer. Compiles PRD+architecture+HANDOVER+rules into a build prompt. Audited by reviewer-prd (R001) before sending.
when_to_use: |
  Before EVERY build session. Compiling a complete prompt for Claude Code.
  Preparing S0/S1+/Sx of a project.
allowed-tools: Task
argument-hint: "<target project + session number>"
---

Use the Task tool to invoke the `prompt-engineer` subagent with:

- `subagent_type`: "prompt-engineer"
- `description`: "Prompt compilation"
- `prompt`: $ARGUMENTS

The Prompt Engineer sub-agent will FULLY bootstrap (R001) its context (SOUL, USER, MEMORY, rules, eval, memory-sync-report) then READ THE TARGET PROJECT IN FULL (PRD, architecture, addendum, transcripts, HANDOVER, project rules) before compiling the session prompt.

It then submits to the lead for reviewer-prd invocation. Come back with the candidate prompt + its self-audit.
