---
name: skill-curator
description: Launches the Skill Curator. Validates proposed skills (5 checks). Auto-validation if 4 criteria pass, otherwise operator validation required.
when_to_use: |
  When an agent proposes an auto-created skill draft. Invoked by the requesting agent or by the lead.
  Also for manual audit of the skill base.
allowed-tools: Task
argument-hint: "<skill draft OR 'audit'>"
---

Use the Task tool to invoke the `skill-curator` subagent with:

- `subagent_type`: "skill-curator"
- `description`: "Skill validation"
- `prompt`: $ARGUMENTS

The Skill Curator sub-agent will bootstrap its context (SOUL, USER, MEMORY, doctrine/05-skills, doctrine/10-auto-improvement, full index of existing skills, memory-sync-report) then run its strict workflow (5 checks: duplicate, overlap, granularity, format, relevance → decision APPROVE/MERGE/REVISE/REJECT).

Auto-validation possible if 4 criteria pass. Come back with its decision.
