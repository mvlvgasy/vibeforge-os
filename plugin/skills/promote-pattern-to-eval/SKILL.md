---
name: promote-pattern-to-eval
description: Detects LLM hallucination/error patterns in learnings.md/journal.md and proposes promotion to eval.md. Active phase of Eval capitalization.
when_to_use: |
  When you suspect an LLM error pattern recurs but is not formalized in eval.md.
  Auto-suggested by /cloture-session if learnings.md contains un-promoted SDK/LLM error entries.
  Monthly for a cleanliness audit.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
argument-hint: "[--scope <global|lab>] [--source <learnings|journal|all>]"
---

## Purpose

This skill materializes the **active phase of Eval capitalization** (eval.md was underused while LLM hallucination patterns existed in learnings.md under other forms).

It scans `learnings.md` + `journal.md` to detect LLM error patterns (hallucinations, SDK fallback, schema drift, single-shot fail) that should be read at bootstrap by all agents to prevent recurrence.

**Semantic distinction**:
- **Learning** = "I learned X" (insight / resolution of a blocker, reversible)
- **Eval** = "the LLM fails on X" (meta-analysis of an LLM trap, preventive anti-pattern read at bootstrap)

## When to use

- **Manual**: you notice an LLM error pattern recurring (e.g. "another stale model_id silently falling back")
- **Auto-suggested** by `/cloture-session --full` after learning promotion (check whether an eval pattern should have been created)
- **Post-incident**: after a long debug caused by unexpected LLM behavior, check whether an eval can prevent the next incident
- **Monthly**: preventive cleanliness audit

**Do NOT invoke**:
- On tactical learnings (one-shot resolution of a specific bug) — not all bugs are eval patterns
- In the middle of an active debug (disrupts the flow)

## Inputs

- `--scope <type>` (optional, default `global`): `global` | `lab` | `all`
- `--source <type>` (optional, default `learnings`): `learnings` | `journal` | `all`

## Methodology

### Step 1 — Inventory the sources to scan

Priority sources (where LLM error patterns are described):

```
- <workspace>/registres/learnings.md (global)
- lab-*/registres/learnings.md (per lab)
- <workspace>/registres/journal.md (chronological)
- <workspace>/HANDOVER.md (meta-project)
- lab-*/HANDOVER.md (per lab)
```

Secondary sources (post-incident debug):

```
- <workspace>/backlog/*-debug-*/
- <projet>/notes-debug-*.md
```

### Step 2 — Detect LLM error pattern markers

Patterns to grep (keywords):

**Explicit hallucination markers**:
- `(Claude|LLM|the model) hallucinated`
- `(Claude|LLM) invents`
- `hallucination pattern`
- `LLM hallucinates`
- `confused`, `misinterpreted`

**Silent fallback markers**:
- `(silent|SDK) fallback`
- `silent (fail|failure)`
- `silent degradation`
- `(incorrect|wrong) behavior without error`

**Schema drift / tool_use markers**:
- `schema drift`
- `tool_use (fail|fragile|broken)`
- `MALFORMED_FUNCTION_CALL`
- `function calling failure`

**Single-shot / context loss markers**:
- `single-shot (fail|failure)`
- `context (lost|loss)`
- `forgets (the context|to)`
- `confusion (between|active|inactive)`

**Meta-confusion markers**:
- `meta-recursion`
- `subject/medium confusion`
- `agent coding agents`

Typical command:
```bash
grep -rn -E "(hallucin|silent fallback|silent (fail|fallback)|schema drift|tool_use (fail|broken)|MALFORMED_FUNCTION_CALL|single-shot (fail|failure)|meta-recursion)" \
  <workspace>/registres/learnings.md \
  lab-*/registres/learnings.md \
  <workspace>/HANDOVER.md \
  --include="*.md"
```

### Step 3 — Filter candidates vs trivial comments

For each match, **inspect the context** (10 lines before + 10 lines after):

**Eval candidate** if:
- The pattern is **reproducible** (observed >= 1 time, ideally >= 2)
- A **cause hypothesis** exists (training bias, SDK fallback, context loss, etc.)
- The **prevention is expressible** as an anti-pattern instruction readable at bootstrap
- The pattern is **meta-analysis** (not just a one-shot bug)

**NOT an Eval candidate** if:
- One-shot bug with no generic cause hypothesis
- The resolution explains HOW (= learning) without explaining WHY the LLM fails (= eval)
- Pattern already in eval.md (duplicate)
- Project-specific bug with no meta-LLM dimension

### Step 4 — Cross-check with existing Evals

Read `<workspace>/registres/eval.md` to:
- Identify existing E entries (E01, E02, E03...)
- Detect potential duplicates
- Identify the right scope (global vs lab)

If the pattern is already an eval: skip + signal it.

### Step 5 — Present each candidate to the operator

Compact format, one pattern at a time:

```
Eval candidate detected

**Source**: `<workspace>/registres/learnings.md` line 3044 (L52)
**Original date**: <YYYY-MM-DD>
**Verbatim lesson**:
> "When the Anthropic Agent SDK receives a model_id it does not recognize, it
>  seems to silently fall back to a degraded mode where the tool palette is NOT
>  correctly injected. No explicit error — behaviorally silent fallback."

**Analysis**:
- Reproducible (observed on 2 distinct agents)
- Strong cause hypothesis (SDK fuzzy model_id tolerance)
- Expressible prevention (model_id whitelist at bootstrap)
- Meta-analysis (not just a bug, a PATTERN of silent SDK error)

**Suggested verdict**:
- PROMOTE: this is the archetype of the eval pattern (functional hallucination on
  the SDK side, expressible prevention, usefully read at bootstrap by all agents).

**Eval proposal**:
```yaml
---
id: E0X  # (E01 exists, so EX = E02 or next)
type: eval
created: <YYYY-MM-DD>  # original date
last_updated: <YYYY-MM-DD>  # formalization
severity: high
domain: agent-architecture / SDK / model-id-validation
related: [L52, L44, R012]
promoted_from: [<workspace>/registres/learnings.md#l52]
status: active
frequency: observed once + 1 confirmation
---
```

→ Promote this eval pattern? [yes / no / edit / show wider context]
```

**Always one pattern at a time.** No batch.

### Step 6 — On OK: write the formal Eval entry

#### 6.a — Choose the right scope
- Generic Claude/SDK hallucination pattern → `<workspace>/registres/eval.md`
- Domain-specific pattern of a lab → `<lab>/registres/eval.md`
- Project level: rare (evals naturally bubble up)

#### 6.b — Allocate the ID

Read the target file. Count existing E entries. Allocate `E<NN+1>`.

#### 6.c — Write the entry

Template based on the current E01:

```markdown
## E<NN> — <short pattern title>

```yaml
---
id: E<NN>
type: eval
created: <original date>
last_updated: <YYYY-MM-DD formalization>
severity: <low|medium|high|critical>
domain: <archi|prompt|context|search|...>
related: [<related>]
promoted_from: [<source path>]
status: active
frequency: <observed N times>
---
```

### Pattern description
<How Claude/LLM goes wrong precisely. Meta-analysis, not just the bug>

### Symptoms
- <How to recognize this pattern is happening>
- <Visible signal in the output>

### Probable cause
<Hypothesis on the mechanism: training data, prompt ambiguity, lack of context, SDK fallback, etc.>

### Prevention (what agents must do)
- <Action 1>
- <Action 2>

### Post-hoc detection
- <How to spot afterwards that the pattern occurred>
- <Test or check to apply>

### See also
- <source learning(s)>
- <derived preventive rule if promoted>
```

#### 6.d — Update the eval file INDEX

Append to the `## Index` block:
```markdown
- [E<NN>](#e<nn>) — <title> *(promoted from L<NN>, <date>)*
```

#### 6.e — Update the source learning

In the original learning entry, add to the frontmatter:
```yaml
promoted_to: E<NN> (formalization YYYY-MM-DD — hallucination pattern, eval archetype)
```

And add at the top of the learning body, right after the title:
```markdown
> **Note**: this learning was promoted to eval `E<NN>` in `<workspace>/registres/eval.md`.
> The "L<NN>" form stays here for historical traceability. The canonical prevention form is now E<NN>.
```

#### 6.f — Update counters

Update `<workspace>/registres/INDEX.md` "Counters" section: Eval count +1.

### Step 7 — Log in the traffic-journal

Append to `<workspace>/registres/traffic-journal.md`:

```markdown
## YYYY-MM-DD — Eval promotion by /promote-pattern-to-eval

- **E<NN>** created from `<source path>:L<line>` (learning L<NN>)
- **Validated by**: the operator
- **Scope**: global / lab-<X>
- **Related**: L<NN>, R<NN>
```

### Step 8 — Final confirmation

```
Eval promotion complete.
- Eval patterns created: <N>
- Eval patterns skipped (already existing): <M>
- Eval patterns rejected by the operator: <K>
- Source learnings updated (promoted_to note): <N>
- Files modified: <list>

Recommended: commit + push for git traceability.
```

## Quality criteria — when to REJECT a candidate

- One-shot bug with no meta-LLM dimension (= stays a learning)
- The resolution explains HOW without explaining WHY the LLM fails
- Pattern already in eval.md (duplicate)
- No expressible cause hypothesis
- No prevention expressible as an anti-pattern instruction
- Project-specific pattern with no generic transposition

## Anti-patterns

- Promoting all error learnings to eval (eval != debug learning)
- Forcing an eval promotion to "fill" eval.md → if not a meta-analysis, it is not an eval
- Batching 5 evals at once without individual review (each eval deserves precision)
- Erasing the source learning after promotion (always `promoted_to: E<NN>` + historical note)
- Renumbering an existing ID

## Verification

The skill ran correctly if:
1. At least one source was scanned
2. The matched patterns are **presented to the operator** (not auto-promoted)
3. Rejected candidates are **logged** (traceability)
4. Each created eval has a unique ID, a complete frontmatter, and is referenced in the INDEX
5. Each source learning has its frontmatter updated with `promoted_to`
6. traffic-journal.md is updated
7. `git status` shows coherent diffs

## Examples

### Example 1 — Audit

```
User: /promote-pattern-to-eval --scope global
```

Skill:
1. Scans `<workspace>/registres/learnings.md`
2. Detects several candidates: a cross-provider tool_use one (borderline), a model_id silent fallback one (clear), a single-shot routing one (borderline)
3. Presents the clear one → operator validates → E02 created
4. Presents the single-shot one → operator validates partially → E03 created
5. Presents the borderline one → operator rejects
6. Confirms with a recap.

### Example 2 — Specific lab scope

```
User: /promote-pattern-to-eval --scope lab --lab lab-client
```

Skill: scan limited to `lab-client/registres/learnings.md` + journal.

### Example 3 — Post-incident

```
User: /promote-pattern-to-eval --source journal
```

You just debugged a weird LLM behavior → want to check whether an eval pattern emerges.

---

**Mirror skills**: `/promote-decision-to-bdr` (same for strategic decisions → bdr.md), `/traffic-controller scan` (L→R promotions).
**Related rules**: R009 (MEMORY consolidation).
