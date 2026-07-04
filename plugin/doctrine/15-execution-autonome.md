# Frame 15 — Bounded autonomous execution

> **Safety** operational frame: defines the conditions under which an agent (or the
> `lead-auto` mode) may chain actions WITHOUT a validation pause, and above all the
> STOP (HALT) conditions that force a return to the human. Formalizes what Vibeforge
> already enforced implicitly (anti-runaway Stop hook, per-agent `maxTurns`, semi-auto
> default) into an explicit contract.
>
> **Version 1.0** — Dedicated creation. Formalizes the existing behavior; does not change
> the default (which stays semi-auto / human-in-the-loop).
>
> **Related rules**: R4 (anti-runaway), R009 (HITL consolidation).

## Problem solved

Vibeforge already has autonomy guardrails (anti-runaway Stop hook, per-agent `maxTurns`,
`lead` semi-auto by default vs `lead-auto`). But they were **scattered and implicit**: no
document stated plainly *when an agent may continue on its own, and which quantified
thresholds force it to stop and escalate*. As a result, autonomous behavior depended on
each agent's discipline and on scattered settings rather than an explicit contract.

## Solution — autonomous execution contract

### 1. Two explicit regimes

| Regime | When | Validation pause |
|---|---|---|
| **Semi-auto (default)** | `/lead`, any non-trivial request | YES at each structuring step |
| **Autonomous** | `/lead-auto`, already-framed work, predictable steps | NO, but subject to the HALTs below |

The autonomous regime is only legitimate if the work is **already framed** (PRD + arch
validated, or a clear roadmap). Otherwise, semi-auto is mandatory.

### 2. STOP (HALT) conditions — non-negotiable

Even in autonomous mode, the agent STOPS and escalates the moment ANY of these is hit:

- **HALT-DECISION** — a non-reversible or unframed decision arises (structuring arch
  choice, data deletion, outward-facing action: sending mail / publishing / pushing to a
  third party).
- **HALT-SCOPE** — the action exceeds the framed scope (touching a file/module outside
  the plan, > ~10 production files changed at once).
- **HALT-LOOP** — a second failed fix attempt on the same problem (invoke systematic
  debugging BEFORE the second fix), or a detected loop.
- **HALT-COST** — abnormal token/time budget for the task (drift signal).
- **HALT-DOUBT** — the agent is unsure of a fact, of a skill/agent name (-> CATALOG.md),
  or of user intent. Doubt triggers a stop, not an invention.

### 3. Escalation format (at HALT)

On stop, the agent does not hand back vaguely. It presents:

```
HALT-<CODE>: <what blocks, in one line>
Options:
  A) <option 1 + consequence>
  B) <option 2 + consequence>
  C) <option 3 if relevant>
Recommendation: <A/B/C + why in one line>
```

One recommendation, not a catalog. The operator decides, the agent resumes.

## Articulation with the existing setup

- **Anti-runaway Stop hook (R4)** = the partial machine implementation of the HALTs
  (low-level net). This frame = the doctrine above it (what the agent must do on its own).
- **Per-agent `maxTurns`** = a coarse HALT-COST/LOOP guardrail, kept.
- **CATALOG.md** (frame 10) = the answer to HALT-DOUBT on skill/agent names.

## What this frame does NOT do

- It does not grant new autonomy: the default stays semi-auto / HITL.
- It adds no tooling (no script). It is a behavioral contract, enforced by the agents and
  backed by the existing hooks.
