<div align="center">

# Vibeforge

**A generator of autonomous, self-governed Claude Code labs.**

Run one interview. Get a *lab* — a domain workspace with its own specialized agents, skills,
memory registers, and an embedded frozen copy of the whole governance method. The generated
lab runs on **plain Claude Code**: no plugin, no dependency on this repo, nothing to install
on the machine that uses it. Hand the folder to anyone.

[![Version](https://img.shields.io/badge/version-0.3.0-2563eb)](./plugin/.claude-plugin/plugin.json)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-d97757)](https://docs.claude.com/en/docs/claude-code)
[![Doctrine](https://img.shields.io/badge/doctrine-16%20frameworks-16a34a)](#-the-doctrine)
[![Platform](https://img.shields.io/badge/platform-Windows%20%2F%20PowerShell-5b8def)](#-platform)
[![License](https://img.shields.io/badge/license-source--available-64748b)](./LICENSE)

[Install](#-install) · [Generate a lab](#-generate-a-lab) · [What's inside](#-whats-inside) · [The doctrine](#-the-doctrine) · [How it works](#-how-it-works)

</div>

---

## ✨ What it is

Vibeforge is a **lab generator** built on Claude Code. This repo holds the method — 16
doctrine frames, armed agents, skills, templates. You use it once per domain: it interviews
you, then **stamps a standalone lab** that embeds a frozen copy of that method (`_method/`
socle + vendored agents + skills). From that point on, the lab is self-sufficient.

- **Standalone by design** (doctrine frame 16) — a generated lab has **zero external
  dependency**: no plugin install, no sibling clone, no reference back to this repo.
  Verifiably so — the generator greps its own output for leftover refs.
- **Governance, not a harness** — everything is `.md` agents/skills/rules + helper scripts.
  No LLM API calls, no chat loop, no custom runtime. OAuth-based: uses whatever Claude Code
  is logged into. No `ANTHROPIC_API_KEY`.
- **Each lab learns locally** — a full capitalization loop ships inside the lab (decisions,
  learnings, journal, evals). Your lab's experience stays yours; nothing syncs back.
- **Upgradeable socle (v0.3: full lifecycle)** — at generation, every vendored file is
  hashed into `_method/manifest.json`. From there: `check-drift.ps1` tells pristine from
  customized, and `upgrade-lab.ps1` applies journaled migrations (`migrations/`) DB-style —
  idempotent, backed up, rollback-able — **never overwriting a customized file** (conflicts
  are reported for human arbitration). Labs generated before v0.3: one-time
  `build-manifest.ps1 -Baseline`. See [`migrations/README.md`](./migrations/README.md).
  _Not in scope (v0.4 candidates): marketplace, inter-module dependency resolution — the
  socle stays monolithic._

---

## 🚀 Install

> ⚠️ **Pre-release (v0.3.0).** Active build. The doctrine and agents are stable; tooling and
> packaging are still maturing.
> Source-available: running the plugin requires written permission — see [License](#-license).

```bash
claude plugin marketplace add mvlvgasy/vibeforge-os
claude plugin install vibeforge
```

> The marketplace repo is `vibeforge-os`; the installed plugin is named `vibeforge`. That naming
> split is intentional, not a typo.
>
> **You only need the install to RUN the generator.** The labs it produces are standalone —
> they never require the plugin (nor this repo) on the machines that use them.

---

## 🧪 Generate a lab

After install (or from a clone of this repo):

```text
/new-lab-standalone
```

Claude interviews you about your domain — deliverables, agents, skills, connectors,
privacy constraints (a mandatory floor, adaptive depth beyond it) — then stamps a
tailored **standalone lab**:

```text
lab-<name>/
├── _method/            ← frozen copy of the whole method (socle) + VERSION stamp
├── .claude/agents/     ← 9 generic agents (lead, architecte, ux, BA…) + your custom experts
├── .claude/skills/     ← central skills + your custom skills
├── agent-contexts/     ← per-agent SOUL / USER / MEMORY
├── registres/          ← the lab's own living memory (decisions, learnings, journal…)
├── CLAUDE.md · SOUL.md · contexte-domaine.md
└── .vibeforge/method.txt  →  method = standalone
```

Open it in a plain Claude Code terminal — `/lead` works, the agents respond, the lab
learns. Push it to a git repo and hand it to a collaborator: **they need nothing but
Claude Code.**

What ships inside every generated lab (the full governance cycle, not just documents):

| Layer | What the lab gets |
|-------|-------------------|
| **Doctrine** | The 16 frames, frozen in `_method/` with a `VERSION` stamp |
| **Agents** | The whole fleet — orchestration (lead), framing (business-analyst, architecte, ux), quality (reviewer-prd, code-reviewer, devil-advocate), memory (dream-validator), curation (skill-curator, traffic-controller) — plus your custom experts |
| **Skills** | ~35 including the capitalization loop: `/cloture-session`, `/save-cadrage`, `/dream`, `/promote-learning`, `/promote-decision-to-bdr`, `/metrics-report` |
| **Hooks** | 8 lifecycle guards wired via `.claude/settings.json` — completion verification, anti-runaway, memory nudges, pre-compact protection |
| **Living registers** | `registres/rules.md` & `eval.md` seeded from the socle with a local-additions section on top: promotions land in the lab, the frozen socle stays pristine |
| **Indexing** | A real `CATALOG.md` (anti-hallucination: only what actually exists) + `tools/rebuild-catalog.ps1` to regenerate it |

---

## 🔄 Upgrades

Generated labs are **maintained, not throwaway**. When this method improves:

```text
/upgrade-socle lab=<path-to-lab>
```

The engine refreshes **only the method layer** (`_method/`, method agents/skills, hooks,
CATALOG) and never touches the lab's custom layer — domain agents, skills, register
content, accumulated learnings all survive. Custom detection is dynamic: anything not in
the socle inventory is protected. `_method/VERSION` tracks what each lab runs on.

**The separation rule: `_method/` is regenerable — everything else is yours.**

---

## 📦 What's inside

A single Claude Code plugin, organized as:

| Folder | What it holds |
|--------|---------------|
| **`doctrine/`** | 16 numbered frameworks — the constitution of the method (see below). |
| **`agents/`** | "Armed" `.md` agents (tools, model, memory, hooks declared in frontmatter) + lightweight `_workers/` for parallel fan-out. |
| **`agent-contexts/`** | Per-agent `SOUL` / `MEMORY` / `USER` split — each specialist keeps its own persistent context and learnings. |
| **`skills/`** | ~30 slash skills (`/lead`, `/new-lab`, `/cloture-session`, `/dream`, `/save-cadrage`…). |
| **`templates/`** | `lab.template` and `projet-meta.template` — the scaffolds `/new-lab` and `/new-projet` instantiate. |
| **`hooks/`** | Session lifecycle automation (PowerShell): anti-hallucination guards, completion verification, memory nudges. |
| **`registres/`** | The five memory registers (decisions, learnings, journal, evals, rules) — shipped blank, filled as you work. |

---

## 🧭 The doctrine

The backbone is **16 frameworks**, each a single numbered file in `doctrine/`:

| # | Framework | # | Framework |
|---|-----------|---|-----------|
| 01 | Constitution | 09 | Trafic (cross-lab promotion) |
| 02 | Registres (5 memory files) | 10 | Auto-amélioration |
| 03 | Consolidation | 11 | Credentials & secrets |
| 04 | Agents | 12 | Workflow projet (deliverable / meta split) |
| 05 | Skills | 13 | MEMORY scoping |
| 06 | Rules | 14 | Architecture de livraison agent |
| 07 | Capitalisation | 15 | Bounded autonomous execution |
| 08 | Transposition (any domain) | 16 | **Standalone labs (the generator model)** |

Frameworks 01–08 are the methodological core; 09–16 add cross-lab governance, credential hygiene,
a clean project workflow, scoped agent memory, delivery patterns, bounded autonomy (HALT codes),
and the standalone-lab generation model that makes the whole method **distributable**.

---

## 🛠 How it works

```text
You  ›  I want to start working on <a new domain>
        Vibeforge: interview (frame-16 floor) → stamps a STANDALONE lab → tailors it with you

Then, inside the generated lab (plain Claude Code, no plugin):

You  ›  scope this feature
        lab: business-analyst → architecte → prompt-engineer → build → review

You  ›  that worked well, remember it
        lab: capitalizes the pattern into its local registers
```

Inside a generated lab, a `lead` agent orchestrates and delegates to specialists (it never
writes code itself). Hooks and doctrine enforce guardrails — no completion claim without
evidence, no runaway loops, no lost framing memory. All of it ships **inside the lab**.

---

## 💻 Platform

Vibeforge's helper scripts and hooks are written in **PowerShell** and target **Windows**. The
agents, skills, doctrine, and templates are plain markdown and work anywhere Claude Code runs;
only the automation layer (hooks/scripts) is Windows-specific today. Cross-platform (bash) parity
is on the roadmap.

---

## 📄 License

**Source-available — not open source.** The code is public for reference and evaluation. Using,
installing, running, copying, or redistributing it requires prior written permission from the
author. Request access via [github.com/mvlvgasy](https://github.com/mvlvgasy). See [LICENSE](./LICENSE).
