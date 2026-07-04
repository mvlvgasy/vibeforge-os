---
name: dedup-registres
description: Detects and merges similar BDR/learnings via semantic embeddings. Dedup phase of the consolidation cycle (R009). Invoke periodically (monthly) or when an audit detected a duplicate.
when_to_use: |
  When you suspect or detect duplicates in the registers
  (e.g. the same learning capitalized twice by two different agents).
  Auto-suggested by /cloture-session full mode if last dedup >30d.
allowed-tools: Read, Bash, Edit, Write
argument-hint: "[--threshold N | --registre <learnings|bdr|both>]"
---

## Purpose

This skill materializes the **phase 2 (Merge) of the 4-step consolidation cycle**. It detects potential duplicates in the global registers (`learnings.md`, `bdr.md`) via semantic embeddings, proposes merges, and applies the validated merges.

Goal: avoid the debt that accumulates at 100+ entries (the same learning capitalized twice is empirical proof of the need).

## When to use

- **Auto-suggested** by `/cloture-session --full` if last dedup > 30d
- **Manual**: you spot a duplicate or want a cleanliness audit before promotion
- **Periodic**: monthly recommendation (or bi-weekly at 100+ entries)
- **Post-promotion**: after a wave of cross-lab promotions (R009), check whether it created overlaps

**False positives to avoid**:
- Do NOT invoke in the middle of an active framing / project (disrupts the flow)
- Do NOT invoke right after a recent dedup (< 7d) unless there is a specific reason

## Inputs

All arguments are passed to the script `${CLAUDE_PLUGIN_ROOT}/scripts/dedup-registres.mjs`:

- `--threshold N` (optional, default 0.70): cosine similarity threshold. Range ]0, 1].
- `--registre <type>` (optional, default both): `learnings` | `bdr` | `both`
- `--verbose` (optional): detailed log during the scan

## Methodology

### Step 1 — Run the scan in dry-run

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/dedup-registres.mjs" --dry-run $ARGUMENTS
```

The script:
- Parses `registres/learnings.md` and/or `registres/bdr.md`
- Computes embeddings (512 dim) — falls back to mock if no key
- Computes cosine similarity between all pairs of the same type (learning vs learning, bdr vs bdr)
- Writes a report into `<workspace>/audits/dedup-registres-<YYYY-MM-DD-HH-mm>.md`

### Step 2 — Read the audit report

Retrieve the report path from the console output (last line). Read the file.

Expected structure:
- **Summary**: MERGE / REVIEW / KEEP counters
- **Candidates table**: sim, ID1, ID2, titles
- **Per-pair detail**: side-by-side preview of each entry's body

### Step 3 — Verify scan quality

Pre-checks before presenting:

- [ ] Provider = the embeddings provider (NOT `mock`). If mock → explicit warning: non-semantic embeddings, probable false positives. Suggest setting the embeddings provider key then re-running.
- [ ] At least 1 candidate detected (otherwise: signal that no duplicate was found at the current threshold, suggest a lower threshold)

### Step 4 — Present the MERGE candidates (sim >= 0.85)

For each `MERGE` pair:

```
MERGE candidate — sim=0.XX
  - Entry A : L01 (line 3137) "..."
  - Entry B : L01 (line 3662) "..."
  - Status A : active
  - Status B : active

  Merge proposal:
    - Keep: A (lowest ID / lowest line)
    - Append to A: unique sections of B
    - Mark B: status=deprecated + note "Merged into A (line 3137) on YYYY-MM-DD"

  → Apply the merge? [yes/no/show full diff]
```

Present **one pair at a time**. Do NOT batch (each merge deserves individual review).

### Step 5 — On OK: apply the merge

For each validated pair:

#### 5.a — Identify the entry to keep

Default rule: keep the entry with the **lowest ID** (or the **lowest line** if IDs are identical).

#### 5.b — Append the unique sections

Read both entries fully. Compare the sections (Context, Lesson, Symptom, Why, How to apply, Anti-patterns, etc.). For each section of B that:
- does not exist in A → append to A
- exists in A but with different content → append as a sub-section "Additions from B (merged on YYYY-MM-DD)" or ask how to merge

Keep A's frontmatter. Add to A's frontmatter:
```yaml
merged_from: [<ID_B>]
last_updated: <YYYY-MM-DD>  # merge date
```

And update A's `related: [...]` with B's `related` (union).

#### 5.c — Mark entry B

**Default option (least disruptive)**: Edit B's frontmatter:
```yaml
status: deprecated
deprecated_at: <YYYY-MM-DD>
deprecated_reason: "Merged into <ID_A> (line XXXX) — duplicate detected by /dedup-registres"
merged_into: <ID_A>
```

And add at the top of B's body (right after the title):
```markdown
> **DEPRECATED — Merged into [<ID_A>](#<id-a-anchor>) on YYYY-MM-DD**
> This entry is kept for traceability. The canonical content is in <ID_A>.
```

**Alternative option (move to _archived/)**: only if explicitly requested, create `<workspace>/registres/_archived/learnings-archived.md` and move the full entry there.

#### 5.d — Update INDEX (TOC at the top of the file)

The `## Index` block at the start of `learnings.md` or `bdr.md` lists all entries. Update:
- For entry A: optionally note in the TOC line that it was enriched
- For entry B: mark in the TOC line `(deprecated, merged into <ID_A>)` or remove it if moved to `_archived/`

### Step 6 — Traceability log

Append to `<workspace>/audits/dedup-applied-<YYYY-MM-DD-HH-mm>.md` (1 file per merge run):

```markdown
# Merge(s) applied — <YYYY-MM-DD HH:mm>

## Metadata
- Skill: /dedup-registres v1
- Source report: `<workspace>/audits/dedup-registres-<source-ts>.md`
- Operator validated: yes

## Merges applied

### Merge 1: L01(line 3662) → L01(line 3137)
- **Kept**: L01 line 3137 (`learnings.md`)
- **Merged from**: L01 line 3662
- **Appended sections**: ...
- **Frontmatter A updated**: `merged_from: [...]`, `last_updated: ...`
- **Frontmatter B updated**: `status: deprecated`, `merged_into: L01`
```

### Step 7 — Present REVIEW (sim 0.70-0.85) as a summary

For each `REVIEW` pair, **do not auto-apply**. Present as a compact list:

```
REVIEW candidates (grey zone, manual arbitration):
  - sim=0.78  L24 ↔ L42  | "..." ⟷ "..."
  - sim=0.74  L51 ↔ L56  | "..." ⟷ "..."
  ...

→ Want me to handle one of these pairs? [ID1-ID2 / no / skip]
```

The operator arbitrates. If yes on a pair → handle as MERGE (steps 4-5).

### Step 8 — Final confirmation

```
Dedup complete.
- MERGE pairs handled: <N>
- REVIEW pairs arbitrated: <M>
- KEEP pairs (info only): <K>
- Audit report: <path>
- Merge log: <path> (if merges applied)
- Affected entries: <list IDs>

Recommended: commit + push for git traceability.
```

## Anti-patterns

- Applying a MERGE without operator validation (each merge changes the learnings history, it is sensitive)
- Deleting the merged entry — always `status: deprecated` + redirect note (git traceability)
- Batching several MERGE without individual review (false positives possible even at sim > 0.85)
- Running with the MOCK provider without flagging it explicitly (non-semantic results)
- Re-scanning entries already `status: deprecated` (the script should skip them — verify this behavior)
- Modifying the head INDEX without an explicit Edit (risk of TOC/entries desync)
- Forgetting to update `related: [...]` (loss of cross-references after merge)

## Verification

The skill ran correctly if:
1. Report generated in `<workspace>/audits/dedup-registres-<ts>.md`
2. Provider = the embeddings provider (otherwise explicit warning)
3. For each applied MERGE: entry A enriched, entry B `deprecated`, INDEX updated, application log created
4. No entry lost (the `deprecated` ones are still in the file)
5. `git status` shows coherent diffs (learnings.md / bdr.md modified)

## Examples

### Example 1 — Standard monthly run

```
User: /dedup-registres
```

Skill:
1. Runs `node "${CLAUDE_PLUGIN_ROOT}/scripts/dedup-registres.mjs" --dry-run`
2. Report generated, 3 MERGE detected
3. Presents the 1st pair
4. Operator validates
5. Applies: first entry enriched, second deprecated, INDEX updated
6. Presents the 2nd MERGE pair, etc.
7. Lists the REVIEW pairs for manual arbitration
8. Confirms

### Example 2 — Tight audit for cleanliness

```
User: /dedup-registres --threshold 0.60 --registre learnings
```

Skill: threshold 0.60 on learnings only (wide audit). Many KEEP / REVIEW pairs to arbitrate.

### Example 3 — Quick BDR-only re-scan

```
User: /dedup-registres --registre bdr
```

Skill: scan BDR only (fast, few entries).

---

**Related rules**: R009 (MEMORY consolidation), R010 (register capitalization).
**Dependencies**: `scripts/dedup-registres.mjs` (reuses the `embed-skills.mjs` / `embed-query.mjs` pattern via the embeddings provider).
