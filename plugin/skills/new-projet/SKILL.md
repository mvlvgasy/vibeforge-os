---
name: new-projet
description: Create a project split deliverable/meta (doctrine 12). Deliverable in projets/<category>/<name>/, meta in <lab>/projets-meta/<name>/. A single session with cwd=lab.
when_to_use: |
  When you start a new engagement that will have its own source code and
  its own S0->Sn Claude Code sessions.
  Examples: /new-projet name=acme-portal-v2 affiliated-lab=lab-client-acme,
              /new-projet name=health-checker affiliated-lab=lab-content --git-init
allowed-tools: Bash Read Write
argument-hint: "name=<name> affiliated-lab=<lab-xxx> [--git-init] [--github-repo=<url>] [--dry-run]"
---

## Purpose

Create a new project in Vibeforge while respecting the **deliverable / meta-project separation** (R002, doctrine 12). Pure code is isolated from the Vibeforge method; the deliverable is pushable as-is to a client repo with no pollution.

## When to use

- A new engagement that will have its own source code
- Will go through S0->Sn Claude Code sessions orchestrated by lead
- Deserves its own numbered rules, its PRD, its HANDOVER

DO NOT use it for:
- A new lab (use `/new-lab`)
- A simple session note (put it in `<lab>/projets-meta/` directly, no new project)
- A one-shot analysis (use existing lab skills)

## Target architecture (doctrine 12 v2)

```
<workspace>/
├── projets/
│   └── <category>/                          # category inherited from the affiliated lab
│       └── <project>/                       # <- DELIVERABLE (pure code, pushable to client)
│           ├── README.md
│           └── .gitignore
│
└── <affiliated-lab>/                        # <- CANONICAL cwd of Claude sessions
    ├── CLAUDE.md / SOUL.md / contexte-domaine.md
    ├── .claude/
    │   ├── agents/                          # lab-specific agents (auto-loaded)
    │   ├── skills/                          # lab-specific skills (auto-loaded)
    │   └── settings.local.json              # additionalDirectories: [../vibeforge, ../projets]
    └── projets-meta/
        └── <project>/                       # <- META-PROJECT (sub-folder of the lab, NOT cwd)
            ├── CLAUDE.md                    # project-specific context (read in "current project" mode)
            ├── HANDOVER.md
            ├── README.md
            ├── docs/
            │   ├── PRD.md
            │   └── prd-coverage-reports/
            ├── registres/                   # project local registers
            └── .claude/                     # fallback settings (rarely used)
```

**Claude Code sessions launch in the lab** (`cwd = <lab>/`). The meta-project is a **sub-folder accessible via a relative path** (`./projets-meta/<project>/`). Code is written in the deliverable via `../projets/<category>/<project>/`. The lead remembers the "current project" in `<lab>/agent-contexts/lead/MEMORY.md`.

**Why cwd = lab and not the meta-project**: you benefit from auto-loading of lab rules, lab-specific agents/skills, and the domain-context. See doctrine 12 v2 for the full rationale.

## Methodology

### Step 1 — Parse the arguments

- `name=<name>` (**required**): kebab-case alpha-num, 2-60 chars, starts with a letter
- `affiliated-lab=<lab-xxx>` (**required**): name of the parent lab (`lab-<name>` format). The lab must exist.
- `--git-init` (flag): initializes git in the **deliverable** + first commit
- `--github-repo=<url>` (optional): URL of the GitHub origin remote (implies `--git-init`)
- `--dry-run` (flag): preview without creating

### Step 2 — Check the prerequisites

Before running the script, check (relative to the current working directory, which holds the lab):
- The affiliated lab exists: `Test-Path <affiliated-lab>/`
- The lab has a readable `.vibeforge/category.txt` (otherwise fallback to `custom` with a warning)
- The deliverable and the meta-project do not already exist

### Step 3 — Run the PowerShell script

The script resolves paths relative to the current working directory (`-BaseDir`, default cwd). Pass `-BaseDir "<path>"` to operate on a workspace other than the current directory.

```powershell
powershell.exe -ExecutionPolicy Bypass `
    -File ${CLAUDE_PLUGIN_ROOT}/scripts/new-projet.ps1 `
    -Name "<name>" `
    -AffiliatedLab "<lab-xxx>" `
    -GitInit `
    -GithubRepo "<url>"
```

The script does:
1. Reads `<lab>/.vibeforge/category.txt` for the category (fallback `custom`)
2. Creates the deliverable `<workspace>/projets/<category>/<name>/` from the plugin's `projet.template/`
3. Creates the meta-project `<lab>/projets-meta/<name>/` from the plugin's `projet-meta.template/`
4. Substitutes the variables: `{{PROJET_NAME}}`, `{{PROJET_CREATED}}`, `{{LAB_NAME}}`, `{{LAB_CATEGORY}}`, `{{LAB_PATH_RELATIVE}}`, `{{VIBEFORGE_PATH_RELATIVE}}`, `{{LIVRABLE_PATH_RELATIVE}}`
5. Creates `docs/prd-coverage-reports/.gitkeep` in the meta-project
6. If `--git-init`: `git init` in the deliverable + first commit
7. If `--github-repo`: `git remote add origin <url>`

### Step 4 — Confirm and continue WITHOUT switching sessions

After creation, present to the operator:

```
Project '<name>' created:
   Deliverable : <workspace>/projets/<category>/<name>/
   Meta-project: <affiliated-lab>/projets-meta/<name>/  (sub-folder of the lab)

I continue in this conversation (cwd = <lab>). I record "current project: <name>"
in agent-contexts/lead/MEMORY.md.

Next steps (without switching sessions):
1. You validate the project context or specify it now
2. I run the framing chain: business-analyst -> ux -> architecte -> reviewer-prd
3. Code is written in ../projets/<category>/<name>/ via additionalDirectories
4. The HANDOVER, PRD, registers stay in ./projets-meta/<name>/

Shall we go?
```

**Important**: do NOT propose "open a session in the meta-project". The old workflow (doctrine 12 v1) did that — it is revised. cwd stays the lab throughout.

## Anti-patterns

- Launching a Claude Code session in the **deliverable** (loses the lab + meta-project context, forces a re-bootstrap)
- Launching a Claude Code session in the **meta-project** (loses the lab rules, lab-specific agents, the domain-context — doctrine 12 v2 fixes this v1 mistake)
- Putting HANDOVER / docs / registers in the deliverable (R002 — these files stay in the meta-project)
- Pushing the meta-project to the client repo (the client repo receives ONLY the deliverable)
- Creating a project without `affiliated-lab` (required — the lab provides domain rules, domain-context, complementary agents)
- Skipping `--git-init` for a production project (you can always do it later, but better up front)
- Creating 2 projects in the same meta-project (one meta-project = one deliverable = one project)

## Examples

### Client-software project

```
/new-projet name=onboarding-v2 affiliated-lab=lab-client-acme --git-init --github-repo=https://github.com/your-client/acme-onboarding
```

Result:
- Deliverable: `<workspace>/projets/client/onboarding-v2/` (git init + remote)
- Meta: `lab-client-acme/projets-meta/onboarding-v2/`
- `additionalDirectories` points to `../../../vibeforge` AND `../../../projets/client/onboarding-v2`

### Content project (workflow test)

```
/new-projet name=health-checker affiliated-lab=lab-content --git-init
```

Result:
- Deliverable: `<workspace>/projets/content/health-checker/` (local git init, no remote)
- Meta: `lab-content/projets-meta/health-checker/`

### Preview before creating

```
/new-projet name=test-thing affiliated-lab=lab-content --dry-run
```

Prints what would be done, paths, substituted variables. No execution.

## Verification

After execution:
- [ ] The deliverable exists with `README.md` and `.gitignore`
- [ ] The meta-project exists with `CLAUDE.md`, `HANDOVER.md`, `docs/PRD.md`, `registres/`, `.claude/`
- [ ] All `{{...}}` variables have been replaced (check `CLAUDE.md`, `settings.local.json`)
- [ ] `<lab>/.claude/settings.local.json` contains `additionalDirectories` pointing to `../vibeforge` AND `../projets`
- [ ] (If `--git-init`) First commit created in the deliverable
- [ ] The lab conversation (cwd = `<lab>/`) can read `./projets-meta/<project>/` AND `../projets/<category>/<project>/` without a prompt

## See also

- Doctrine 12: full project workflow (framing -> dev -> prod)
- R002: deliverable / meta-project split
- Skill `new-lab`: create a parent lab before creating a project
- Script `${CLAUDE_PLUGIN_ROOT}/scripts/new-projet.ps1`: implementation
