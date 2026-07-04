---
name: lab-architect
description: Launches the Lab Architect. Creates a new lab: discovery, naming, complementary agents, SOUL/CLAUDE.md drafts, /new-lab invocation.
when_to_use: |
  When you want to create a new specialized lab (research, freelance, content, business, etc.).
  NOT for creating a project (use /new-projet directly instead, inside an existing lab).
allowed-tools: Task
argument-hint: "<new lab domain>"
---

Use the Task tool to invoke the `lab-architect` subagent with:

- `subagent_type`: "lab-architect"
- `description`: "New lab orchestration"
- `prompt`: $ARGUMENTS

The Lab Architect sub-agent will bootstrap its context (SOUL, USER, MEMORY, doctrine/04-agents, doctrine/08-transposition, templates/lab.template, memory-sync-report) then run its full workflow (domain discovery → naming → complementary agent selection → initial drafts → /new-lab invocation → customization → verification → handoff to lead).

Come back with its report + created lab.
