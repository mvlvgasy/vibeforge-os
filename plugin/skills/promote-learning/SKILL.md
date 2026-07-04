---
name: promote-learning
description: Promotes a local learning to the global registers (generic reformulation, [promoted] marking, traceability). Invoked by traffic-controller after operator validation.
when_to_use: |
  When a local learning has passed the promotion criteria (recurrence >=2 projects,
  stability >=30 days, operator validation) and must be copied to the global registers.
allowed-tools: Read Edit Write
argument-hint: "type=<learning|rule|bdr|eval> id=<global-id> sources=<path1>,<path2>"
---

## Purpose

Standardize the learning promotion operation. Guarantees:
- Generic formulation (no project-specific context)
- Traceability (sources marked `[promoted]`)
- Cross-register reference integrity
- Index updates

## When to use

Invoked by:
- `traffic-controller` during a scan that identified a validated promotion candidate
- The `lead` if the operator says "promote this learning"
- The operator directly via `/promote-learning ...`

## Methodology

### Step 1 — Receive the inputs

- `type=<learning|rule|bdr|eval>`: target type
- `id=<global-id>` (optional — computed from the target INDEX otherwise)
- `sources=<path1>,<path2>`: 1 to N paths to the source entries to promote
- (Optional) `force=true` to bypass certain checks (to avoid)

### Step 2 — Read each source

For each source path, read the entry (Grep on the ID in the source file).

### Step 3 — Verify the pre-conditions

- [ ] All sources exist and have a complete frontmatter
- [ ] No source is already marked `[promoted]` (otherwise stop, already promoted)
- [ ] Promotion criteria met (recurrence >=2 projects for learning→rule, etc.)
- [ ] Explicit operator validation OR `force=true`

If a pre-check fails → escalate, do not continue.

### Step 4 — Compute the target ID

Read the target register INDEX (`<workspace>/registres/rules.md`, `learnings.md`, `bdr.md`, or `eval.md`).
Find the largest existing ID + 1. Zero-padded format: `R001`, `R002`, ..., `R010`, `R011`.

### Step 5 — Reformulate to generic

The source content likely contains:
- Project names → remove or replace with "[client project]"
- Specific stack names → keep if generic, remove if project-specific
- Client identifiers → REMOVE (anonymization)
- Concrete examples → keep if pedagogical, anonymize

Rewrite into: a pattern applicable to ANY project of the same domain, with no contamination.

### Step 6 — Compose the target entry

Format:

```markdown
## <ID> — <short title>

\`\`\`yaml
---
id: <ID>
type: <type>
created: <YYYY-MM-DD>  (= today)
last_updated: <YYYY-MM-DD>
severity: <copied from sources, the highest>
domain: <copied, or consolidated>
related: [<related>]
promoted_from: [<source path 1>, <source path 2>]
status: active
---
\`\`\`

### Rule / Lesson / Decision
<generic formulation>

### Why
<consolidated justification>

### How to apply
- <Point 1>
- <Point 2>

### Limits / counter-examples
<if applicable>

### Anti-patterns
- ...

### See also
- Sources: <paths>
- Cross-references: <related rules>
```

### Step 7 — Add to the target

- Append to the right register (`<workspace>/registres/<type>.md`)
- Update the INDEX at the top of the target register (counters + table entry)

### Step 8 — Mark the sources `[promoted]`

For each source, Edit the entry's frontmatter:
```yaml
status: promoted    # instead of active
promoted_to: <target-ID>
promoted_at: <YYYY-MM-DD>
```

Do NOT delete the content — it stays for traceability.

### Step 9 — Update `traffic-journal.md`

Append to `<workspace>/registres/traffic-journal.md`:
```markdown
### Promotion done — <YYYY-MM-DD HH:mm>
- **Sources**: <list with paths>
- **Target**: `<workspace>/registres/<type>.md#<ID>`
- **Approved by**: the operator on <date>
- **Skill**: /promote-learning v2
- **Reformulation**: <yes/no + summary of anonymization changes>
```

### Step 10 — Confirm

```
Promotion done.
- Sources marked [promoted]: <N>
- Target: <workspace>/registres/<type>.md#<ID>
- Target INDEX updated
- Traffic-journal appended
```

## Anti-patterns

- Promoting without validating the generic formulation (the rule stays contaminated by project context)
- Deleting the source after promotion (loss of traceability)
- Promoting 5 entries at once without individual operator validation
- Promoting without updating the INDEX
- Promoting without updating the traffic-journal
- Reusing an already-used ID
- Keeping client names / identifiers in the global formulation

## Examples

### Promotion learning → rule
```
traffic-controller identified:
- lab-client/projets/onboarding-v2/registres/learnings.md#L01 (Slack Bolt + Vercel waitUntil)
- lab-client/projets/ats/registres/learnings.md#L03 (same pattern)

Operator validates.

/promote-learning type=rule sources=lab-client/projets/onboarding-v2/registres/learnings.md#L01,lab-client/projets/ats/registres/learnings.md#L03

Skill:
1. Reads the 2 sources
2. Reformulates: "Slack Bolt on Vercel serverless: always wrap processEvent in waitUntil()"
3. Composes R002 in <workspace>/registres/rules.md
4. Marks sources [promoted]
5. Appends traffic-journal
6. Confirms
```

## Verification

- [ ] Target added with complete frontmatter (validated)
- [ ] Target register INDEX updated (counter incremented, line added)
- [ ] Sources marked (status: promoted, promoted_to, promoted_at)
- [ ] Traffic-journal appended
- [ ] No broken reference (related: [...] point to existing entries)
- [ ] No client name/identifier in the global formulation

---

**Version**: 2.0
