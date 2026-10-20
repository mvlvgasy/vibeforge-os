# Frame 18: Traceable scoping

> Added 2026-10-20. Numbered 18 to stay aligned with the source method (frame 17, enforcement, is not ported to the OS yet).
> Concepts imported from VibeFlow 2.70 (unknowns register, question rules, requirement IDs, roadmap with exit criteria, judge distinct from author, adjustable rigor). No code copied, no GSD dependency.

## Why

The method scoped the **need** well (discovery, PRD, reasoned architecture) but tracked it poorly: open questions in prose, requirements without IDs, session plan buried in MEMORY-cadrage. Nobody could tell in one minute what is still undecided, what is promised, and what is proven.

Frame 18 keeps the depth of the discovery and adds a traceable backbone:

```
Question (Q-xx) → Decision → Requirement (REQ-xx) → Observable criterion (PRD §7) → Phase / Plan (ROADMAP) → Proof (verifier)
```

Each link quotes the ID of the previous one. A reader who does not know the method (manager, business sponsor) can follow the file without a guide.

## The 6 artefacts (in `projets-meta/<project>/docs/`)

| File | Role | Written by | Read by |
|---|---|---|---|
| `QUESTIONS.md` | Unknowns register: each question has an ID, a status, an owner, an answer and its impact | business-analyst, architecte | lead, `/cloture-cadrage` |
| `PRD.md` | Why and what (10 sections). §4 lists requirements by ID, §7 the observable criteria | business-analyst | everyone |
| `REQUIREMENTS.md` | Numbered requirements with source, priority, criterion, phase, proof | business-analyst, then verifier (proof column) | reviewer-prd, prompt-engineer, verifier |
| `ROADMAP.md` | Phases with goal, covered requirements, testable exit criterion, status | business-analyst + architecte | lead, prompt-engineer |
| `plans/PNN-MM.md` | One plan per build session: goal, covered REQs, tasks, verification, done criterion | prompt-engineer (before the session prompt) | builder, verifier |
| `VALIDATIONS.md` | Sign-off log: which version of which document, approved by whom, when, with which reservations | the operator | everyone |

Supporting templates (optional depending on rigor): `discovery-notes.md`, `stakeholder-map.md`, `ai-use-case-sheet.md`.

## Question rules (discovery)

1. **One round = the whole frontier.** Each round asks, numbered, every question whose prerequisites are settled. No drip-feeding.
2. **One recommended option per question**, with a one-line reason.
3. **Never ask a human for a fact.** What lives in files, code, docs or the web is looked up first. Only judgment, preference or tacit-knowledge questions are asked.
4. **Group by area** (user, need, scope, data, constraints, validation).
5. **Every assumption taken without an answer is written down** in `QUESTIONS.md` with status `assumption` and the person who must confirm it.
6. **Discovery ends when the frontier is empty**: no `blocking: yes` question left `open`.

## Closing gate

`/cloture-cadrage` refuses to close while `QUESTIONS.md` has a `blocking: yes` line with status `open`. Assumptions are allowed but listed in the synthesis with their expected validator.

Before the first build, `reviewer-prd` also checks that every `V1` REQ has an observable criterion and a phase, that every phase has a testable exit criterion, and (standard and full profiles) that `VALIDATIONS.md` holds a sign-off of the current PRD version.

## Rigor profiles

Chosen at project creation (`/new-projet -Profil`). **Never `full` by default.**

| Profile | For | Mandatory artefacts |
|---|---|---|
| `leger` (light) | POC, script, less than a week | `QUESTIONS.md`, `PRD.md` (sections 1 to 5 and 7), `ROADMAP.md` |
| `standard` | Internal tool used by a team | + `REQUIREMENTS.md`, `plans/`, `VALIDATIONS.md` |
| `complet` (full) | Sensitive data, critical production, external client | + `stakeholder-map.md`, `ai-use-case-sheet.md` if AI, devil-advocate offered |

## Judge distinct from author

Whoever writes does not validate. The BA writes the PRD, `reviewer-prd` judges it. The builder ships, `verifier` judges it. Every verdict is dated, quotes the judged version and counts its attempts (max 3).

## One next step

At the end of each scoping move, the lead proposes **one** next step drawn from `ROADMAP.md` and `QUESTIONS.md`, not a menu.

## Not imported from VibeFlow

GSD dependency, dozens of hooks, prose full of internal IDs, method installed inside the shipped repository.
