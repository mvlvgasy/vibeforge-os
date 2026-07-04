---
name: parallel-cadrage
description: Parallel challenge of a PRD draft via Dynamic Workflow - devil-advocate + architecte (feasibility) + reviewer-prd (coverage R001) simultaneously, then synthesis. Speeds up framing VALIDATION (not discovery).
when_to_use: |
  When a PRD draft exists (from an interactive BA discovery) and you want to challenge it from 3 angles at once.
  BEFORE freezing the framing / moving to build.
  Does NOT replace the BA discovery (which stays interactive with the operator).
  Requires the Workflow tool.
allowed-tools: Workflow Read
argument-hint: "<path to the PRD draft, e.g. lab-x/projets-meta/y/docs/PRD.md>"
---

## Why this precise split

- **Discovery** (BA asking the operator questions) is intrinsically interactive -> **NOT parallelizable**. Stay on `/business-analyst`.
- **Validation** of a draft (critique + feasibility + coverage) = 3 agents reading the SAME document without talking to each other -> **perfectly parallelizable**. THIS is the phase we speed up.

## Step 1 - Verify the draft

Read the PRD draft passed as argument. If it does not exist -> stop, propose `/business-analyst` first.

## Step 2 - Run the Workflow

Invoke `Workflow` with this script. **Write the `prdPath` directly in the script** (not via `args` - not bound to the inline script):

```javascript
export const meta = {
  name: 'parallel-cadrage',
  description: 'Challenge PRD from 3 angles in parallel',
  phases: [{ title: 'Challenge' }]
}

const prdPath = 'lab-x/projets-meta/y/docs/PRD.md' // <- REPLACE with the real PRD draft path

const [devil, feasibility, coverage] = await parallel([
  () => agent(
    `Adversarial critique of the PRD ${prdPath}: unverified assumptions, blind spots, analyst bias, risks. 4 sections. You neither block nor validate - you flag.`,
    { agentType: 'vibeforge:devil-advocate', label: 'devil-advocate', phase: 'Challenge' }
  ),
  () => agent(
    `Assess the technical FEASIBILITY of the PRD ${prdPath}: stack, architecture risks, dependencies, hard points. You do NOT produce the final architecture - just a feasibility opinion.`,
    { agentType: 'vibeforge:architecte', label: 'feasibility', phase: 'Challenge' }
  ),
  () => agent(
    `COVERAGE audit of the PRD ${prdPath} (R001): clear scope? measurable success criteria? explicit stakeholders? Decisive verdict OK / NOT OK / REVIEW.`,
    { agentType: 'vibeforge:reviewer-prd', label: 'coverage-R001', phase: 'Challenge' }
  )
])

return { devil, feasibility, coverage }
```

## Step 3 - Synthesis (you, Lead / Main Claude)

You receive the 3 opinions. Synthesize for the operator:
- **reviewer-prd verdict** (R001 - blocking if NOT OK; nothing goes to build without an OK).
- **Top risks** (devil-advocate).
- **Hard technical points** (architecte).
- **Recommendation**: freeze the PRD / iterate / clarify with a stakeholder.

## Anti-patterns
- Using this for the initial discovery (interactive -> `/business-analyst`).
- Ignoring a `NOT OK` from reviewer-prd (R001 sacred; R005 for non-reversible domains: mail/contract).
- Letting the architecte produce the full architecture here (it's just a feasibility opinion - the architecture comes after, once the PRD is frozen).
