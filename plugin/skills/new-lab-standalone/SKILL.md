---
name: new-lab-standalone
description: Generate a STANDALONE lab (doctrine frame 16) — frozen method embedded (_method/ socle + vendored generic agents), zero plugin/sibling dependency, ready to hand to anyone. Via scripts/new-lab-standalone.ps1. This is THE lab-creation path in Vibeforge OS.
when_to_use: |
  Whenever a new lab is needed. Vibeforge OS generates standalone labs only: the lab
  embeds its own frozen method and runs on plain Claude Code (no plugin, no sibling clone).
  Perfect for client work, shared repos, or any lab you may hand to someone else.
  Examples: /new-lab-standalone name=acme-marketing category=client client=acme,
            /new-lab-standalone name=video-studio category=content --git-init
allowed-tools: Bash Read Write Edit
argument-hint: "name=<name> [category=<cat>] [client=<client>] [socle=<path>] [dest=<path>] [--git-init] [--dry-run]"
---

## Purpose

Generate a **standalone lab**: a lab that embeds a **frozen copy of the governance
socle** (this repo's own content — self-vendoring) plus the vendored generic agents,
and depends on **nothing external**. Once generated, the lab no longer needs this
repo or the plugin. Doctrine: frame 16.

## When to use

Whenever you create a lab with Vibeforge OS — this is the only creation mode here.
The generated lab:
- runs on plain Claude Code (a terminal and a login),
- can be pushed to a git repo and handed to a collaborator or client as-is,
- keeps learning locally (own registers, own capitalization loop).

NOT for:
- converting an EXISTING lab to standalone → manual vendoring operation, not this skill.

## Methodology

### Step 1 — The creation interview (mandatory floor, frame 16)

Before any stamp, cover the floor (adapt depth beyond it):
- domain + the lab's objective
- expected deliverables
- agents needed (are the 9 generic ones enough? which custom experts?)
- skills needed
- connectors / APIs / MCP servers required
- privacy / security constraints (GDPR or equivalent)

Usually **lab-architect** runs this interview and then invokes this skill. If invoked
directly with an already-clear need, validate the floor with 2-3 quick questions.

### Step 2 — Parse arguments

- `name=<name>` (**required**): kebab-case, without the `lab-` prefix.
- `category=<cat>` (optional, default `custom`).
- `client=<name>` (optional).
- `socle=<path>` (optional): another vibeforge-os checkout as socle source.
  Default: **this repo itself** (self-vendoring).
- `dest=<path>` (optional): destination root. Default: current directory.
- `--git-init`, `--dry-run`: flags.

### Step 3 — Run the engine

```powershell
powershell.exe -ExecutionPolicy Bypass `
    -File "<socle-root>/scripts/new-lab-standalone.ps1" `
    -Name "<name>" -Category "<cat>" -Client "<client>" -GitInit
```

`-DryRun` first to validate the plan, then the real run.

What the engine does (deterministic):
1. Lab template + variable substitution (`{{LAB_PARENT}}` → `_method`, never a sibling)
2. `_method/`: CLAUDE, DOCTRINE, registers, doctrine, templates, scripts,
   agent-contexts seeds + `README.md` (frozen socle) + **`VERSION`** (source, commit, date)
3. 9 generic agents → `.claude/agents/`
4. 3 central skills → `.claude/skills/` (new-projet, traffic-controller, review-prd-coverage)
5. Ref rewriting: plugin-root and sibling refs → embedded socle, plugin namespace →
   plain skill names, plugin prerequisite → standalone note
6. `.vibeforge/method.txt` = `standalone` + standalone note appended to CLAUDE.md
7. **Dependency-free verification**: zero sibling-folder, plugin-root-variable, or
   plugin-marketplace references outside the embedded socle (the engine warns otherwise)

### Step 4 — Domain customization

SOUL.md, contexte-domaine.md, CLAUDE.md, then the **custom agents/skills** from the
interview (armed frontmatter + full agent-contexts). This is the tailored layer —
the whole point of the interview.

### Step 5 — Final verification

- [ ] Engine output: "OK - zero external reference outside _method/"
- [ ] `_method/VERSION` present (source + commit + date)
- [ ] `method.txt` = `standalone`
- [ ] Real test: `cd <lab>` then `claude` → agents respond (bootstrap smoke test)
- [ ] If shared: git repo created + pushed + collaborator invited

## Anti-patterns

- ❌ Stamping before the interview floor is covered (generic lab = useless).
- ❌ Hand-editing `_method/` files in the generated lab (lost at socle upgrade).
- ❌ Re-wiring the lab to the plugin or a sibling clone afterwards.
- ❌ Shipping without the bootstrap smoke test (Step 5).

## Examples

### Client lab (collaborator only has Claude Code)
```
/new-lab-standalone name=acme-video category=content client=acme --git-init
→ lab-acme-video, 100% autonomous, frozen socle, ready to push to a shared repo.
```

### Preview
```
/new-lab-standalone name=acme-marketing --dry-run
→ Shows the plan (resolved socle, agents, skills, variables) without creating anything.
```

## Verification

See Step 5. The ultimate acceptance criterion (frame 16): the lab opens in a plain
Claude Code terminal, on a machine without vibeforge, and `/lead` works.

---

**Created**: "standalone labs" project, step 2 (2026-07-04)
**Version**: 1.0
