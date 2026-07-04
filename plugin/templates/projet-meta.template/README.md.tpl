# {{PROJET_NAME}}

> Vibeforge project — created on {{PROJET_CREATED}}
> Affiliated lab: `{{LAB_NAME}}`

## Getting started

1. Open Claude Code with the lab as the working directory
2. Type `/lead discovery and scoping of {{PROJET_NAME}}` to start

## Structure

- `CLAUDE.md` — project constitution (inherits from the lab + parent Vibeforge)
- `HANDOVER.md` — current state passed between sessions
- `docs/` — PRD, architecture, transcriptions, reviewer-prd reports
- `registres/` — local bdr / blockers / learnings / journal / eval
- `.claude/rules/` — numbered project-specific rules
- `.claude/settings.local.json` — additionalDirectories toward the lab + Vibeforge (gitignored)
- `.vibeforge/lab.txt` — explicit lab affiliation convention
- `src/` (or equivalent) — the code, created via the build session

## Vibeforge hierarchy

```
vibeforge/                  ← parent method
{{LAB_NAME}}/               ← methodological lab (a client domain, freelance, content, …)
{{PROJET_NAME}}/            ← this project (standalone git repo, pushable separately)
```

## Pushing to GitHub

```bash
git init
git add .
git commit -m "feat: bootstrap {{PROJET_NAME}}"
git remote add origin <github-repo-url>
git push -u origin main
```

## Meta

- **Project**: {{PROJET_NAME}}
- **Affiliated lab**: {{LAB_NAME}}
- **Created**: {{PROJET_CREATED}}
