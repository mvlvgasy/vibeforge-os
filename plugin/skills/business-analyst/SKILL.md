---
name: business-analyst
description: Launches the Business Analyst. Discovery, framing, PRD writing, stakeholders, success criteria. First agent invoked on a new project.
when_to_use: |
  Starting a new project. Discovery. Initial PRD writing.
  Stakeholder identification and success criteria. Project framing.
allowed-tools: Task
argument-hint: "<the need to frame>"
---

Use the Task tool to invoke the `business-analyst` subagent with:

- `subagent_type`: "business-analyst"
- `description`: "BA discovery"
- `prompt`: $ARGUMENTS

The Business Analyst sub-agent will bootstrap its own context (SOUL, USER, MEMORY, rules, eval, memory-sync-report, lab/project context if applicable) then run its workflow (discovery via brainstorming → PRD writing → stakeholder questions → handoff to architect).

Come back with its synthesis + initial PRD.
