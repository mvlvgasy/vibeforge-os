---
name: lead
description: Launches the Lead (semi-auto mode). Multi-agent orchestration, project framing, synthesis. Default entry point for any complex request.
when_to_use: |
  Starting a new project. Continuing an existing project.
  Any request that requires several specialists. Prefer this over talking to Claude directly.
allowed-tools: Task
argument-hint: "<your request>"
---

Use the Task tool to invoke the `lead` subagent with:

- `subagent_type`: "lead"
- `description`: "Lead orchestration"
- `prompt`: $ARGUMENTS

The Lead sub-agent will bootstrap its own context (SOUL, USER, MEMORY, doctrine, registers, memory-sync-report) then run the mission per its standard workflow (understand → plan → execution mode → delegation → verification → synthesis + capitalization).

Come back with its synthesis once it has finished.
