---
name: promote-decision-to-bdr
description: Detects committing strategic decisions in HANDOVER.md/journal.md/notes and proposes promotion to bdr.md (method root or lab). Active phase of BDR capitalization.
when_to_use: |
  When you suspect a structuring decision was made but not formalized as a BDR.
  Auto-suggested by /cloture-session if recent HANDOVER.md files contain decision markers.
  Monthly for a cleanliness audit.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
argument-hint: "[--scope <global|lab|projet>] [--lab <name>]"
---

## Purpose

This skill materializes the **active phase of BDR capitalization** (bdr.md was underused: structuring decisions exist but were not being captured).

It scans the sources where decisions are actually made (HANDOVER.md, journal.md, session notes, arbitrages-*.md) to detect committing decision markers, then proposes promotion to a formal `bdr.md` after operator validation.

**Semantic distinction**:
- **Learning** = "I learned X" (experience insight, reversible)
- **BDR** = "we decided X" (strategic commitment, changes trajectory, hard to revert without an explicit BDR02)

## When to use

- **Manual**: you notice a decision is not formalized
- **Auto-suggested** by `/cloture-session --full` if HANDOVER.md was modified recently with decision markers
- **Monthly**: preventive cleanliness audit
- **Post-meeting**: after a strategic meeting where decisions were made

**Do NOT invoke**:
- In the middle of a framing (disrupts the flow)
- On immature files (< 7 days) — let the decision settle

## Inputs

- `--scope <type>` (optional, default `all`): `global` | `lab` | `projet` | `all`
- `--lab <name>` (optional): restrict to the specified lab

## Methodology

### Step 1 — Inventory the sources to scan

List of files where decisions are made in practice:

```bash
# Priority sources (formal decisions)
- <workspace>/HANDOVER.md (method root)
- <lab>/HANDOVER.md (each lab)
- <lab>/projets-meta/<projet>/HANDOVER.md (meta-projects)
- <lab>/registres/journal.md (chronological)

# Secondary sources (contextualized arbitrations)
- <projet>/notes-cadrage*.md
- <projet>/arbitrages-*.md
- <projet>/DEPARTURE-NOTES-*.md

# Rare but critical sources
- <workspace>/backlog/*-analyse-*/rapport-*.md (sub-agent reports)
- <workspace>/doctrine/*.md (structural modifications)
```

Glob:
```
HANDOVER.md
**/registres/journal.md
**/arbitrages-*.md
**/notes-cadrage*.md
```

### Step 2 — Detect decision markers

Patterns to grep (keywords):

**Explicit decision markers**:
- `we decide(d) (to|that)`
- `decision (made|validated|locked)`
- `i will (choose|abandon|close)`
- `from now on`
- `we will no longer`

**Pivot markers**:
- `pivot (to|from)`
- `switch (to)`
- `abandon (of)`
- `we will not (do) anymore`

**Structural commitment markers**:
- `architecture (chosen|validated)`
- `stack (validated|final)`
- `(founding|guiding) principle`
- `golden rule`
- `non-negotiable`

Typical command:
```bash
grep -rn -E "(we decide|decision (made|locked|validated)|pivot to|from now on|founding principle|non-negotiable)" \
  <workspace>/HANDOVER.md \
  lab-*/HANDOVER.md \
  lab-*/projets-meta/*/HANDOVER.md \
  lab-*/registres/journal.md \
  --include="*.md"
```

### Step 3 — Filter candidates vs trivial comments

For each match, **inspect the context** (5 lines before + 5 lines after):

**BDR candidate** if:
- The decision is **committing** (closes an option, changes the trajectory)
- The context explains the **trade-off** (why X was chosen over Y)
- The consequences are mentioned or obvious
- Cross-session impact (not just a tactical decision of the current session)

**NOT a BDR candidate** if:
- Reversible tactical decision (e.g. "we decide to code this today")
- No trade-off identified (just a default choice)
- Decision already documented in an existing BDR
- Ambiguous / hypothetical phrasing ("we could decide")

### Step 4 — Cross-check with existing BDRs

Read `<workspace>/registres/bdr.md` (and `<lab>/registres/bdr.md` if scope lab) to:
- Identify existing BDRs (BDR01-BDR<N>)
- Detect potential duplicates (is the decision already capitalized?)
- Identify the right scope (global vs lab vs project)

If the decision is already a BDR: skip + signal that it is already done.

### Step 5 — Present each candidate to the operator

Compact format, one decision at a time:

```
BDR candidate detected

**Source**: `<lab>/projets-meta/<projet>/HANDOVER.md` line 437
**Date**: <YYYY-MM-DD>
**Verbatim**:
> "Decision made: 99% of needs are deterministic, AI is only relevant in
>  specific cases. We switch to a deterministic-first cascade before any LLM call."

**Analysis**:
- Committing decision (closes the single-shot LLM option)
- Explicit trade-off (deterministic vs LLM)
- Consequences: refactor to 4-step cascade + prompt-injection detector
- Cross-session impact (a security decision derived from this)

**BDR proposal**:
```yaml
---
id: BDR03  # (BDR01 exists, BDR02 empty template, so BDR03 is new)
type: bdr
created: <YYYY-MM-DD>  # original date
last_updated: <YYYY-MM-DD>  # formalization
severity: high
domain: classification-LLM / architecture
related: [L57, E03]
promoted_from: [<lab>/projets-meta/<projet>/HANDOVER.md#L437]
status: active
---
```

**Proposed title**: "BDR03 — Deterministic-first cascade BEFORE LLM for classification/routing apps"

→ Promote this BDR? [yes / no / edit title / show wider context]
```

**Always one decision at a time.** No batch.

### Step 6 — On OK: write the formal BDR

For each validated candidate:

#### 6.a — Choose the right scope
- If the decision touches the method root (architecture, doctrine, stack) → `<workspace>/registres/bdr.md`
- If the decision concerns a lab (lab architecture, cross-cutting tool choices) → `<lab>/registres/bdr.md`
- If a committing project-specific decision → `<projet>/.claude/registres/bdr.md` (rare)

#### 6.b — Allocate the ID

Read the target file. Count existing BDRs. Allocate `BDR<NN+1>` where NN = last used ID.

NEVER reuse an ID, even if an entry is deprecated.

#### 6.c — Write the entry

Template based on the current BDR01:

```markdown
## BDR<NN> — <short committing title>

```yaml
---
id: BDR<NN>
type: bdr
created: <original decision date>
last_updated: <YYYY-MM-DD formalization>
severity: <medium|high|critical>
domain: <archi|method|business|stack|...>
related: [<related>]
promoted_from: [<source path>]
status: active
---
```

### Context
<What problem / question called for this decision. Include the situation, the verbatim if relevant>

### Decision
<Clear, firm formulation, first person plural or impersonal>

### Why
<Justification, options considered, reasons for the choice, trade-off>

### Consequences
<What this decision implies for other choices, cross-session consequences>

### See also
- <derived rules>
- <related BDRs>
- <source learnings>
```

#### 6.d — Update the BDR file INDEX

Append to the `## Index` block:
```markdown
- [BDR<NN>](#bdr<nn>) — <title> *(<short source>, <date>)*
```

#### 6.e — Update counter

Update `<workspace>/registres/INDEX.md` "Counters" section: BDR count +1.

### Step 7 — Log in the traffic-journal

Append to `<workspace>/registres/traffic-journal.md`:

```markdown
## YYYY-MM-DD — BDR promotion by /promote-decision-to-bdr

- **BDR<NN>** created from `<source path>:L<line>`
- **Validated by**: the operator
- **Scope**: global / lab-<X> / projet-<X>
- **Related**: L<NN>, E<NN>, R<NN>
```

### Step 8 — Final confirmation

```
BDR promotion complete.
- BDRs created: <N>
- BDRs skipped (already existing): <M>
- BDRs rejected by the operator: <K>
- Files modified: <list>

Recommended: commit + push for git traceability.
```

## Quality criteria — when to REJECT a candidate

- Reversible tactical decision (can be undone at no cost)
- Implicit decision (not explicitly stated)
- Decision already a BDR (duplicate)
- Ambiguous verbatim ("we could", "maybe", "to be seen")
- No identifiable trade-off
- Inconsistent scope (project decision presented as a global BDR)

## Anti-patterns

- Forcing a BDR promotion to "fill" bdr.md → if not committing, it is not a BDR
- Batching 5 BDRs at once without individual review (each BDR is a commitment)
- Promoting a learning as a BDR if it is just an insight (a learning is not a decision)
- Renumbering an existing ID
- Deleting a BDR without status: deprecated + reason

## Verification

The skill ran correctly if:
1. At least one source was scanned (logged in the output)
2. The matched decision markers are **presented to the operator** (not auto-promoted)
3. Candidates rejected by the operator are **logged** (so they are not re-proposed)
4. Each created BDR has a unique ID, a complete frontmatter, and is referenced in the INDEX
5. traffic-journal.md is updated
6. `git status` shows coherent diffs

## Examples

### Example 1 — Monthly audit

```
User: /promote-decision-to-bdr --scope all
```

Skill:
1. Scans HANDOVER.md across the whole stack
2. Detects 4 candidates
3. Presents the 1st, operator validates → BDR03 created
4. Presents the 2nd, operator rejects (not committing)
5. Presents the 3rd, operator edits the title
6. ... etc.
7. Confirms with a recap.

### Example 2 — Specific lab scope

```
User: /promote-decision-to-bdr --scope lab --lab lab-client
```

Skill: scan limited to `lab-client/HANDOVER.md` + projets-meta + journal.

### Example 3 — Post-meeting

```
User: /promote-decision-to-bdr --scope global
```

After a strategic call, you want to formalize the accepted structuring decisions.

---

**Related rules**: R009 (MEMORY consolidation).
**Mirror skills**: `/promote-pattern-to-eval` (same but for LLM hallucination patterns → eval.md), `/traffic-controller scan` (L→R promotions).
