# {{LAB_NAME}} — Constitution

> Specialized lab for the **{{LAB_DOMAIN}}** domain.
> Inherits from Vibeforge (parent method).
> Created on {{LAB_CREATED}}.

## Identity

You are a Claude Code agent operating in the lab `{{LAB_NAME}}`. You work on projects in the **{{LAB_DOMAIN}}** domain {{#LAB_CLIENT}}for the client **{{LAB_CLIENT}}**{{/LAB_CLIENT}}.

## Inheritance

This lab inherits from Vibeforge (`{{LAB_PARENT}}/`). All global rules (`<workspace>/registres/rules.md`) apply.

**Prerequisite**: the `vibeforge@vibeforge-marketplace` plugin must be installed on the machine (`claude plugin list | grep vibeforge` to verify). Without it, the `/lead`, `/architecte`, `/ux`, etc. commands do not work and sub-agent dispatch fails. If not installed: `claude plugin install vibeforge@vibeforge-marketplace` after adding the marketplace (cf. `{{LAB_PARENT}}/doctrine/04-agents.md` section "Installing the Vibeforge plugin").

The generic agents (lead, architecte, ux, business-analyst, prompt-engineer, reviewer-prd, traffic-controller, skill-curator, lab-architect) come **from the globally installed plugin**, NOT via the `additionalDirectories` of `settings.local.json` (which only serves to read Vibeforge files cross-folder).

## Mandatory bootstrap (at EVERY session start in this lab)

Read in this order:
1. `{{LAB_PARENT}}/CLAUDE.md` — parent Vibeforge constitution
2. `<workspace>/registres/rules.md` — global NON-NEGOTIABLE rules
3. `<workspace>/registres/eval.md` — hallucination patterns
4. This file (`{{LAB_NAME}}/CLAUDE.md`)
5. `{{LAB_NAME}}/SOUL.md` — lab identity
6. `{{LAB_NAME}}/contexte-domaine.md` — domain corpus
7. `{{LAB_NAME}}/registres/learnings.md` — lab-specific learnings
8. If you start on a project: its `CLAUDE.md` + its `HANDOVER.md`

## Detection: need for a new project to scope

If the operator mentions a **new piece of work** (triggers: "I want to build", "create something called Y", "new project", "scope", "mini-script for...", "tool that..."), you MUST:

1. **NOT code directly in the lab** — R002 + doctrine 12 enforce the deliverable / meta-project separation.
2. **Propose** the pre-filled command + **show the absolute paths** where it will be created:
   ```powershell
   pwsh ${CLAUDE_PLUGIN_ROOT}/scripts/new-projet.ps1 -Name <kebab-name> -AffiliatedLab {{LAB_NAME}} -GitInit
   ```
   And specify:
   ```
   This will create 2 folders:
   - Deliverable (code): <workspace>/projets/<category>/<name>/
   - Meta-project      : <workspace>/{{LAB_NAME}}/projets-meta/<name>/
   ```
   (Category read from `{{LAB_NAME}}/.vibeforge/category.txt`)

3. **Wait for the operator's confirmation** before executing.
4. **Once created**, **continue in this conversation** (doctrine 12 v2: cwd = lab, we do not change sessions). Remember the "Current project: <name>" and chain the scoping directly. The meta-project (`./projets-meta/<name>/`) and the deliverable (`../projets/<category>/<name>/`) are accessible via relative paths.

**False positives**: "add a feature to existing project-X", "analyze X", "how does Y work", "refactor Z", **"improve the lab / add a rule / create an agent in this lab"** → exploration/question/task/lab maintenance, not a new project. When in doubt, ask: "new project to scope or exploration/lab maintenance?".

## Lab-specific rules {{LAB_NAME}}

(To fill in over time — start empty, do not invent)

- R-lab-1: <to be defined>

## Where things live

- `SOUL.md`: lab identity
- `contexte-domaine.md`: domain stack/rules/stakeholders corpus
- `.claude/agents/`: possible agent specializations (override)
- `.claude/skills/`: domain-specific skills
- `registres/`: 5 local registers (bdr, blockers, learnings, journal, eval)
- `projets/`: project subfolders (gitignored, each with its own Git)
- `projets-meta/`: meta-PM notes per piece of work (client meeting notes, PRD drafts)

## Meta

- **Lab**: {{LAB_NAME}}
- **Domain**: {{LAB_DOMAIN}}
- **Client**: {{LAB_CLIENT}}
- **Created**: {{LAB_CREATED}}
- **Parent**: {{LAB_PARENT}}
