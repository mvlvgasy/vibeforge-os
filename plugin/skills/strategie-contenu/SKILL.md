---
name: strategie-contenu
description: Launches the Content Strategist. Positioning, editorial calendar, narrative hooks, n8n/Make automations. Content, marketing, freelance labs.
when_to_use: |
  Positioning strategy. Editorial calendar. Hook templates.
  n8n/Make automations for content. Marketing.
allowed-tools: Task
argument-hint: "<your content/marketing request>"
---

Use the Task tool to invoke the `strategie-contenu` subagent with:

- `subagent_type`: "strategie-contenu"
- `description`: "Content strategy"
- `prompt`: $ARGUMENTS

The Content Strategist sub-agent will bootstrap its context (SOUL, USER, MEMORY, rules, memory-sync-report, lab context if applicable) then run its workflow (positioning brainstorming → audience + platforms → editorial calendar + hooks → operator validation → capitalization).

Come back with its synthesis.
