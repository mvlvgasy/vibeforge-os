---
name: use-cases
description: Detects and prioritizes an organization's AI use cases BEFORE any project scoping (frame 18, step 0). Pain-point interviews, UC sheets, value / feasibility / risk / effort grid, prioritized portfolio, then launch of the chosen use case as a project (/new-projet). For a PO / Product Builder who must find what to build.
when_to_use: |
  When it is not yet known WHAT to build: joining a new organization, quarterly review,
  vague request such as "find where AI can help us", a list of ideas to sort, choosing between business requests.
  Also before a team interview (interview mode) and after it (note mode).
  Do NOT use when the project is already chosen: go straight to /new-projet then /lead.
allowed-tools: Read, Write, Edit, Glob, Grep, Task
argument-hint: "init | interview <team> | note <team> | add <idea> | prioritize | launch UC-xx"
---

# /use-cases: detection and prioritization (frame 18, step 0)

You help the operator find the right projects before scoping one. Doctrine: `doctrine/18-traceable-scoping.md`, "Step 0".

**Where files live**: `<lab>/use-cases/` (lab level: a use case is not a project yet).
**Templates**: `${CLAUDE_PLUGIN_ROOT}/templates/use-cases/` (or `_method/templates/use-cases/` in a standalone lab).

## Rules

- **Start from pain points, not technology.** Look for repetitive, slow, inconsistent or risky tasks. AI comes after.
- **Never ask for a fact**: volumes, tools, documented processes are looked up first.
- **No invented numbers.** An estimate (time spent, volume) is marked `estimate` with its source ("said by X in interview"). Otherwise: `unknown`.
- **One recommendation at each step**, never a menu.
- **The PO arbitrates, the sponsor validates**: the chosen top is recorded in `PORTFOLIO.md` with who validated it.

## Modes

### `init`
Create `<lab>/use-cases/` with `PORTFOLIO.md` (from `PORTFOLIO.md.tpl`) and `interviews/`. Ask in one round: organization and teams to cover, sponsor, known constraints (data, tools, GDPR, budget), horizon. Recommend an interview order (teams with the most repetitive work first).

### `interview <team>`
Produce `interviews/<team>-guide.md` from `interview-guide.md.tpl`, adapted to the team (what is already known is pre-filled so it is not asked again). 30 to 45 minutes, open questions on the typical week, painful tasks, frequent errors, tools.

### `note <team>`
From the operator's raw notes, produce `interviews/<team>-YYYY-MM-DD.md` and turn each usable pain point into a candidate: a `UC-xx.md` sheet (from `UC.md.tpl`) and a line in `PORTFOLIO.md`. Pain points without an AI angle go to "Non-AI pain points" (useful to the sponsor anyway).

### `add <idea>`
Add a candidate from elsewhere (direct request, watch). Same sheet, source recorded.

### `prioritize`
1. Fill the `PORTFOLIO.md` grid for each UC (1 to 3, one sentence of justification per score):
   - **Value**: frequency × people affected × severity of the pain.
   - **Feasibility**: data available and accessible, tool integration, maturity of the technology for this task.
   - **Risk** (inverted: 3 = low): personal data, cost of an error, dependence on a human decision.
   - **Effort** (inverted: 3 = small): size of the first useful deliverable.
2. Sort into four families: **quick win** (value ≥ 2, feasibility 3, effort 3), **strategic bet** (value 3, effort 1), **to dig** (an `unknown` that matters), **to drop** (value 1 or risk 1).
3. Propose **a top 3** with a recommendation: usually a quick win first to earn trust, then a bet.
4. List the questions that would change the ranking (they go to the project's `QUESTIONS.md`).
5. Offer a `devil-advocate` review if a strategic bet leads.

### `launch UC-xx`
1. Check that the UC is validated in `PORTFOLIO.md` (otherwise ask for sponsor validation first).
2. Recommend a rigor profile from the grid (risk 1 or 2 → at least standard).
3. Run `/new-projet` with that profile.
4. Seed the project: copy the UC context into `discovery-notes.md`, and each unknown of the sheet as a `QUESTIONS.md` line (ID Q-xx, source `UC-xx`).
5. Hand over to `/lead` for scoping (business-analyst).

## Output

Always end with the portfolio state in 3 lines (number of candidates, top 3, single next step).
