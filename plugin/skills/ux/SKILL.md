---
name: ux
description: Launches the UX Designer. Flows, textual wireframes, tone guide, persona, a11y. Upstream of or in parallel with the architect.
when_to_use: |
  User flow design. Text wireframes. Tone guide for LLM outputs.
  Persona. Accessibility. User-facing feature.
allowed-tools: Task
argument-hint: "<your UX request>"
---

Use the Task tool to invoke the `ux` subagent with:

- `subagent_type`: "ux"
- `description`: "UX design"
- `prompt`: $ARGUMENTS

The UX sub-agent will bootstrap its own context (SOUL, USER, MEMORY, rules, eval, memory-sync-report) then run its workflow (intent brainstorming → existing UX patterns → flows + wireframes + tone guide → operator validation → capitalization).

Come back with its synthesis.
