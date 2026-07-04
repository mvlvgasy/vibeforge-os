---
name: new-lab
description: "DEPRECATED (2026-07-04, frame 16) — use /new-lab-standalone instead. Vibeforge OS now generates STANDALONE labs only (frozen socle embedded, zero dependency). This legacy skill created plugin-dependent labs."
when_to_use: |
  DO NOT use. Vibeforge OS is a generator of standalone labs (doctrine frame 16):
  every new lab is created via /new-lab-standalone, which embeds the method and
  removes any plugin/sibling dependency. This skill is kept for reference only.
allowed-tools: Bash Read Write
argument-hint: "DEPRECATED — use /new-lab-standalone"
---

> ⚠️ **DEPRECATED (2026-07-04).** Vibeforge OS creates **standalone labs only**
> (doctrine frame 16). Use **`/new-lab-standalone`** — it embeds a frozen copy of
> the method into the lab (`_method/` socle + vendored generic agents), so the
> generated lab needs neither this plugin nor a sibling clone.
>
> The content below describes the legacy plugin-dependent mode and is kept for
> reference only.

## Purpose

Create a new Vibeforge lab from the template, with variable-based customization. Standardizes the bootstrap of a new domain of work.

## When to use

When you need a new specialized workspace that:
- Concerns a domain or client distinct from existing labs
- Needs its own rules, context, registers
- Will host several projects (sub-projects / engagements)

DO NOT use it for:
- A single project with no shared-domain need (use `/new-projet` inside an existing lab instead)
- A simple client-management note (a sub-folder inside an existing lab)

## Methodology

### Step 1 — Parse the arguments

Expected arguments (aligned with `new-lab.ps1`):
- `name=<name>` (**required**): short domain name, without the `lab-` prefix. E.g. `client-acme`, `freelance-web`, `content`. Kebab-case, 2-40 chars. The script automatically prepends `lab-`. `type=<x>` is accepted as a backward-compatible alias.
- `category=<cat>` (optional): the category that determines where the **deliverables** of this lab's projects go (`<workspace>/projets/<category>/<project>/`). Common values: `client`, `freelance`, `perso`, `content`, `custom`. Format: kebab-case alpha-num. If omitted, defaults to `custom`.
- `client=<name>` (optional): client/context. Substituted into the template via `{{LAB_CLIENT}}`.
- `--git-init` (flag): automatic git init
- `--dry-run` (flag): preview without execution

### Step 2 — Check that `lab-<name>` does not already exist

If it does, ask the operator.

### Step 3 — Run the PowerShell automation script

The `new-lab.ps1` script does all the filesystem work:
- Copies the `lab.template/` shipped with the plugin
- Renames `.tpl -> .md` (and `.tpl -> .txt` for `.vibeforge/category.txt`)
- Substitutes the variables: `{{LAB_NAME}}`, `{{LAB_DOMAIN}}`, `{{LAB_CLIENT}}`, `{{LAB_CATEGORY}}`, `{{LAB_CREATED}}`, `{{LAB_PARENT}}`, `{{VIBEFORGE_PATH}}`
- Creates `.vibeforge/category.txt` with the resolved category — used later by `/new-projet`
- Optional git init
- Final check: is the `vibeforge@vibeforge-marketplace` plugin installed? (warning otherwise)

The lab is created in the **current working directory** by default. Pass `-TargetDir` to create it elsewhere.

**Command to run**:
```powershell
powershell.exe -ExecutionPolicy Bypass `
    -File ${CLAUDE_PLUGIN_ROOT}/scripts/new-lab.ps1 `
    -Name "<name>" `
    -Category "<category>" `
    -Client "<client>" `
    -GitInit
```

- `-Name` is primary; `-Type` is accepted as a backward-compatible alias
- `-Category` is optional — defaults to `custom`
- Add `-DryRun` for a preview without execution
- Add `-TargetDir "<path>"` to create the lab somewhere other than the current directory

### Step 4 — Propose customization

After creation, propose that the operator edit:
- `<lab>/SOUL.md`: lab identity
- `<lab>/contexte-domaine.md`: domain-context corpus (stack, stakeholders, PRD format)
- `<lab>/CLAUDE.md`: specific rules

You can propose an initial draft for each, based on the domain received.

### Step 5 — Propose complementary agents

Depending on the domain, propose 2-5 recommended complementary agents.

Examples:
- A client-software lab -> `compliance-checker`, `stakeholder-liaison`, `domain-specialist`
- A freelance-dev lab -> `frontend`, `backend`, `devops`, `qa`, `client-comm`
- A content lab -> `copywriter`, `video-editor`, `seo`, `community-manager`

For each complementary agent to create:
1. Ask the operator for confirmation
2. Create `<lab>/.claude/agents/<name>.md` with an armed frontmatter + a dense system prompt (same pattern as the generic agents)
3. Create `<lab>/agent-contexts/<name>/{SOUL,USER,MEMORY,journal,skills/INDEX}.md`

### Step 6 — Confirm

```
Lab created: <workspace>/lab-<name>/
Structure created with template substituted.
Recommended complementary agents: <list>
To customize: SOUL.md, contexte-domaine.md, CLAUDE.md
Start a session: cd <lab> && claude
```

## Anti-patterns

- Creating a lab without a clear domain
- Creating 2 labs for the same domain
- Creating a lab for a single project (use `/new-projet` instead)
- Substituting the variables by hand (use the script)
- Skipping the customization step (a generic lab is useless)
- Creating a lab during an active session on another lab (pollutes the context)

## Examples

### Client-software lab
```
/new-lab name=client-acme category=client client=acme --git-init

-> powershell.exe ... new-lab.ps1 -Name "client-acme" -Category "client" -Client "acme" -GitInit
-> Creates lab-client-acme/ with the template substituted
-> Writes "client" to .vibeforge/category.txt
-> Proposes complementary agents
-> Asks to customize SOUL/CLAUDE/contexte-domaine
```

### Content lab (category from the name)
```
/new-lab name=content --git-init

-> powershell.exe ... new-lab.ps1 -Name "content" -GitInit
-> Creates lab-content/ with .vibeforge/category.txt = "content"
-> Future deliverables will go to projets/content/
```

### Preview before creating
```
/new-lab name=freelance-web --dry-run

-> powershell.exe ... new-lab.ps1 -Name "freelance-web" -DryRun
-> Prints what would be done
-> No real execution
```

## Verification

After execution:
- [ ] The `lab-<name>` folder exists with the expected structure
- [ ] All `.tpl` files have been converted to `.md`
- [ ] All `{{...}}` variables have been replaced
- [ ] The local registers INDEX is correct
- [ ] (If --git-init) First commit created
- [ ] `.vibeforge/category.txt` contains the resolved category (NOT `{{LAB_CATEGORY}}`)
- [ ] The operator has customized SOUL.md and contexte-domaine.md

## See also

- Script `${CLAUDE_PLUGIN_ROOT}/scripts/new-lab.ps1`: implementation
- Skill `new-projet`: create a project inside a lab
