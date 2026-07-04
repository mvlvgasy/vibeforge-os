# {{PROJET_NAME}} — Constitution (meta-project)

> Meta-project of the lab `{{LAB_NAME}}`. Inherits from Vibeforge via the lab.
> The deliverable code lives in `{{LIVRABLE_PATH_RELATIVE}}/` (standalone git repo).
> Created on {{PROJET_CREATED}}.

## Identity

You are a Claude Code agent orchestrating the project `{{PROJET_NAME}}` from its **meta-project** in the lab `{{LAB_NAME}}`. You write the method and the tracking HERE, and you write the deliverable code in `{{LIVRABLE_PATH_RELATIVE}}/`.

## Inheritance

This meta-project inherits from:
1. **Vibeforge** (parent method): `{{VIBEFORGE_PATH_RELATIVE}}/`
2. **Parent lab**: `{{LAB_PATH_RELATIVE}}/`

Access via `.claude/settings.local.json additionalDirectories`.

## Mandatory bootstrap (at EVERY session start)

Read in this order:
1. `{{VIBEFORGE_PATH_RELATIVE}}/CLAUDE.md` — parent Vibeforge constitution
2. `<workspace>/registres/rules.md` — global rules
3. `<workspace>/registres/eval.md` — hallucination patterns
4. `{{LAB_PATH_RELATIVE}}/CLAUDE.md` — lab constitution
5. `{{LAB_PATH_RELATIVE}}/contexte-domaine.md` — domain corpus
6. `{{LAB_PATH_RELATIVE}}/registres/learnings.md` — lab learnings
7. This file (`./CLAUDE.md`)
8. `./MEMORY-cadrage.md` — **long-term scoping brain** (why, roadmap, decisions, key facts), anti-amnesia (R018). **Tiered reading**: read the `## SUMMARY` + the core (Why, current roadmap, Areas of uncertainty); Grep the detailed sections on demand, do not full-read (400-line cap, A1 blocks beyond 500)
9. `./HANDOVER.md` — state at the time of the last session
10. `./.claude/rules/00-project-context.md` — project-specific context
11. All other `./.claude/rules/*.md` in numeric order

## Deliverable vs meta separation

| File type | Location |
|-----------------|--------------|
| Project source code | `{{LIVRABLE_PATH_RELATIVE}}/src/` (or equivalent) |
| `package.json`, build configs | `{{LIVRABLE_PATH_RELATIVE}}/` |
| "Setup" README for the client | `{{LIVRABLE_PATH_RELATIVE}}/README.md` |
| Final PRD (if delivered to the client) | `{{LIVRABLE_PATH_RELATIVE}}/docs/PRD.md` (optional) |
| Pre-final PRD, drafts | `./docs/PRD.md` (HERE) |
| Durable scoping memory | `./MEMORY-cadrage.md` (HERE, R018) |
| Session HANDOVER | `./HANDOVER.md` (HERE) |
| Registers (learnings, blockers…) | `./registres/` (HERE) |
| Discovery transcriptions | `./docs/transcription-*.md` (HERE) |
| Stakeholder meeting notes | `./docs/cr-*.md` (HERE) |

**Golden rule**: if a file contains Vibeforge method, internal decisions, or stakeholder data → HERE. If it is strictly functional to run the project → in the deliverable.

## Where things live

- `./docs/PRD.md` — product spec (iterations + pre-final version)
- `./docs/architecture.md` — technical architecture decisions
- `./docs/transcription-*.md` — discoveries
- `./docs/prd-coverage-reports/` — reviewer-prd reports per session
- `./HANDOVER.md` — session state
- `./.claude/rules/` — numbered rules
- `./registres/` — 5 local registers
- `{{LIVRABLE_PATH_RELATIVE}}/` — deliverable repo (separate git, standalone push)

## Meta

- **Project**: {{PROJET_NAME}}
- **Parent lab**: {{LAB_NAME}}
- **Created**: {{PROJET_CREATED}}
- **Vibeforge path**: {{VIBEFORGE_PATH_RELATIVE}}
- **Deliverable path**: {{LIVRABLE_PATH_RELATIVE}}
