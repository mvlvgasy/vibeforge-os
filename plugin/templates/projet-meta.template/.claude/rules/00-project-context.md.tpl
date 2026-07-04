# Rule 00 — Context of project {{PROJET_NAME}}

> First file read after bootstrap by any agent in this meta-project.
> Gives the minimal context to the Lead and to delegated agents.

## What (1 sentence)
**{{PROJET_NAME}}** — project created on {{PROJET_CREATED}}.
> ☝ To be rephrased after the `/business-analyst` discovery.

## For whom (primary audience)
To be defined during discovery.

## Why (problem solved)
To be defined during discovery.

## V1 scope (must have)
- [ ] To be defined

## Out of V1 scope
- To be defined

## Stakeholders
- To be defined (sponsor, users, validators)

## Success criteria
- To be defined

## Constraints
- To be defined (technical, legal, business)

## Risks
- To be defined

## Deliverable / meta architecture

- **The deliverable code** lives in `{{LIVRABLE_PATH_RELATIVE}}/` (standalone git repo, pushable to a client GitHub).
- **The method + tracking** live HERE (`{{LAB_NAME}}/projets-meta/{{PROJET_NAME}}/`), versioned with the lab.
- When you write code, it goes in the deliverable. When you write meta docs (pre-final PRD, registers, meeting notes), it goes here.

## Affiliated lab
**{{LAB_NAME}}** — see `{{LAB_PATH_RELATIVE}}/CLAUDE.md` (loaded via additionalDirectories).

## Stack
To be locked after architecture, in `.claude/rules/01-stack-locked.md`.

## Workflow
To be standardized after a few sessions, in `.claude/rules/02-workflow.md`.
