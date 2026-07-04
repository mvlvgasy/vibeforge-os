---
name: reviewer-prd
description: Launches the Reviewer PRD. Mandatory audit before build (R001). READ-ONLY, clear-cut decision OK/NOT OK/REVIEW. Invoked by the lead before each build session.
when_to_use: |
  Before EVERY build session (= one that modifies prod code). MANDATORILY invoked
  by the lead before delegating to prompt-engineer AND before the prompt is sent to the operator.
allowed-tools: Task
argument-hint: "<candidate prompt to audit + target project>"
---

Use the Task tool to invoke the `reviewer-prd` subagent with:

- `subagent_type`: "reviewer-prd"
- `description`: "PRD coverage audit"
- `prompt`: $ARGUMENTS

The Reviewer PRD sub-agent will bootstrap its context (SOUL, USER, MEMORY, rules R001, doctrine/07-capitalization, memory-sync-report) then run its strict workflow (scope identification → full reading of PRD+architecture+addendum+transcripts+HANDOVER+rules → criteria extraction → point-by-point audit → report → clear-cut decision OK / NOT OK / REVIEW).

It does NOT amend, it FLAGS. Come back with its clear-cut decision + report.
