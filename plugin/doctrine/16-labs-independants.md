# Frame 16 — Standalone labs (the generator model)

> Added 2026-07-04. This frame defines what Vibeforge OS *produces*: autonomous,
> self-contained labs. It is the reason the generator exists.

## Definition

A **standalone lab** is a lab that embeds a **frozen copy of the governance socle**
and therefore depends on **nothing external**:

- no plugin installation required on the machine that uses it,
- no sibling `../vibeforge/` clone,
- runs on plain Claude Code (a terminal and a login — that's it).

**Vibeforge OS creates standalone labs only.** The generator interviews you, then
stamps a lab that carries its own method. Once generated, the lab no longer needs
this repo or the plugin: you can hand the folder (or its git repo) to anyone.

## Founding principle

> Every standalone lab embeds a frozen copy of the SAME socle, generated from a
> single source.

Governance is *designed* centrally (this repo), *distributed* frozen. A lab never
rewrites its own doctrine by hand — that would fork the method into N divergent
copies. Upgrades happen by regenerating the socle (see Versioning below).

## Anatomy of a standalone lab

1. **Frozen socle `_method/`** — constitution, DOCTRINE + frames, reference
   registers (rules, eval, CATALOG...), templates, scripts. Copied verbatim from
   this repo at generation time.
2. **Vendored generic agents** in `.claude/agents/` — lead, architecte, ux,
   business-analyst, prompt-engineer, reviewer-prd, traffic-controller,
   skill-curator, lab-architect — plus their `agent-contexts/` seeds.
3. **Vendored central skills** in `.claude/skills/` — new-projet,
   traffic-controller, review-prd-coverage.
4. **Custom domain agents/skills** — the tailored part, produced from the
   creation interview. This is where the lab becomes *yours*.
5. **A full local capitalization loop** — registers + INDEX + living discipline
   (learnings, decisions, journal). The lab LEARNS in its own scope; nothing
   syncs back to this repo. Your lab's experience stays yours.
6. **Socle version stamp** — `_method/VERSION` (source, commit, date). Enables a
   future socle upgrade without touching the lab's custom layer.
7. **Zero external references** — no `../vibeforge/`, no plugin namespace, no
   install prerequisite. Verifiable by grep; the generator checks it for you.

## The creation interview

Depth is **adaptive with a mandatory floor**. The generator never stamps before
these are covered:

- domain + the lab's objective
- expected deliverables
- agents needed (are the generic nine enough? which custom experts?)
- skills needed
- connectors / APIs / MCP servers required
- privacy / security constraints (GDPR or equivalent)

## Versioning and upgrades

Each generated lab records its socle origin in `_method/VERSION`. When this repo
improves, a lab can be upgraded by regenerating `_method/` (and only `_method/`)
from the newer source. The custom layer — domain agents, skills, registers,
accumulated learnings — is never touched by an upgrade.

Rule of separation: **`_method/` is regenerable, everything else is yours.**
Do not hand-edit `_method/` files; changes there are lost at the next upgrade.

## What this frame is NOT

- ❌ A sync protocol — nothing flows back from a lab to this repo.
- ❌ A per-lab doctrine — the socle is the same for every lab, frozen per version.
- ❌ A runtime — the lab runs on Claude Code alone, like everything in Vibeforge.

## Anti-patterns

- ❌ Hand-editing `_method/` files inside a generated lab (lost at upgrade).
- ❌ Re-wiring a generated lab to depend on this repo or the plugin again.
- ❌ Stamping a lab before the interview floor is covered (generic lab = useless).
- ❌ Upgrading the socle by hand-merging files — regenerate instead.

## See also

- `skills/new-lab-standalone/SKILL.md` — the orchestration
- `scripts/new-lab-standalone.ps1` — the deterministic engine
- `doctrine/08-transposition.md` — the lab pattern (domain transposition)
