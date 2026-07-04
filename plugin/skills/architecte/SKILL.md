---
name: architecte
description: Launches the Architect. Specs, ADRs, locked decisions. Never writes code. Runs after BA framing, before prompt-engineer.
when_to_use: |
  Technical architecture design. Stack selection. ADRs to formalize. Architecture rework (addendum).
  Technical framing before a build session.
allowed-tools: Task
argument-hint: "<your design request>"
---

Use the Task tool to invoke the `architecte` subagent with:

- `subagent_type`: "architecte"
- `description`: "Architect design"
- `prompt`: $ARGUMENTS

The Architect sub-agent will bootstrap its own context (SOUL, USER, MEMORY, doctrine/04-agents, rules, eval, memory-sync-report) then run its workflow (bootstrap → brainstorming if new → pattern research → architecture proposal → cross-validation → specs deliverable → capitalization).

It NEVER writes code, it produces specs. Come back with its synthesis.
