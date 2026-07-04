---
name: scan-obsoletes
description: Detects obsolete register entries (status=active but last_updated >180d + 0 recent citation). Archive phase of the consolidation cycle (doctrine frame 3). Invoke monthly.
when_to_use: |
  Monthly for register hygiene. Or if /metrics-report reveals
  entries un-cited for >6 months. Auto-suggested by /cloture-session full mode.
allowed-tools: Read Bash Edit Write
argument-hint: "[--threshold-days N | --apply]"
---

## Purpose

This skill materializes **step 4 of doctrine frame 3 "Consolidation"** (Archiving), making it automatic and auditable. It answers: *"Which register entries are obsolete and candidates for archiving?"*

Without this skill, the doctrinal criterion "not read/cited for 180 days" stays theoretical. The skill makes the obsolescence debt visible and proposes an atomic action (mark `status: archived` in the frontmatter, no deletion).

## When to use

- **Monthly**: register hygiene audit (recommendation: 1st Monday of the month)
- When `/metrics-report` or `/audit-memory-age` reveals entries un-cited for >6 months
- Auto-suggested by `/cloture-session full` when it detects accumulation
- Before a large register rework (consolidation by merge, promotion)

## Inputs

- `--threshold-days N` (optional, default 180): threshold in days to declare an entry an archive candidate
- `--apply` (optional, default absent): switches to WRITE mode that marks `status: archived` in the frontmatter of ARCHIVE candidates (interactive: per-entry confirmation recommended)

## Methodology

### Step 1 — Run the scan (detection mode)

Run the supporting PowerShell script:

```powershell
pwsh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-obsoletes.ps1" [-ThresholdDays N]
```

The script:
1. Parses the 4 global registers (`<workspace>/registres/rules.md`, `learnings.md`, `bdr.md`, `eval.md`)
2. Parses the local registers of each `lab-*/registres/*.md`
3. For each entry `## L-XX` / `## R-XX` / `## BDR-XX` / `## E-XX`:
   - Extracts `last_updated` from the YAML frontmatter (if present)
   - Fallback: `**Date** : YYYY-MM-DD` (legacy format)
   - Fallback: `git log -L` for the header line → last commit date
   - Ultimate fallback: file `mtime`
4. For each `status: active` entry with `days_since > threshold`:
   - Cross-check `<workspace>/metrics/events.jsonl`: number of citations of the ID in the last 30 days of events
   - Cross-check `git grep -l <ID>` in the workspace (excluding `registres/`, `_archived/`, `backlog/`, `audits/`): active references
5. Recommendation:
   - **ARCHIVE**: 180d+ AND 0 citation in 30d AND 0 active git ref → truly obsolete
   - **REVIEW**: 180d+ BUT citations/refs still present → manual consolidation (reformulate? promote? merge?)
   - **KEEP**: <180d
   - **SKIP**: already `status: archived` or `deprecated`
6. Writes the report into `<workspace>/audits/scan-obsoletes-<YYYY-MM-DD-HHmm>.md`

### Step 2 — Read the produced report

Read the generated report. Present the summary:
- Number of ARCHIVE / REVIEW / KEEP / SKIP entries
- If ARCHIVE > 0: list the IDs
- If REVIEW > 0: list the IDs, suggesting a manual review (or a merge skill) would be relevant

### Step 3 — Interactive mode (if ARCHIVE candidates detected)

For each ARCHIVE candidate:
1. **Read** the full entry block (header `## ID` up to the next `## ` or end of file) to understand the content
2. Propose 3 options:
   - **ARCHIVE**: mark `status: archived` + `archived_at: <date>` in the entry's frontmatter
   - **KEEP**: do nothing (false positive, entry still relevant even if un-cited)
   - **SKIP**: defer the decision to a later audit (useful if unsure)
3. If more than 10 candidates: propose a batch mode with a recap of titles only

### Step 4 — Apply the decisions

If at least 1 **ARCHIVE** decision:

```powershell
pwsh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-obsoletes.ps1" -ThresholdDays <N> -Apply
```

**OR** targeted manual Edit of each entry's frontmatter (equivalent):

```yaml
---
id: L-XX
...
status: archived        # replaces "active"
archived_at: 2026-XX-XX # new field
---
```

The script in `-Apply` mode is idempotent and only touches the entries explicitly ARCHIVE in this audit.

### Step 5 — Optional: physical move to _archived/

If desired (to declutter the main register), move the archived entry block to:

```
<workspace>/_archived/<YYYY>/<register>.md
```

or

```
<lab>/_archived/<YYYY>/<register>.md
```

(create if absent). Keep a mention in the source register: `## L-XX [ARCHIVED → _archived/2026/learnings.md]` for traceability, OR remove the mention from the head INDEX TOC.

**Note**: this step is optional because the `status: archived` marker in the frontmatter is enough to filter entries at runtime. The physical move is cosmetic cleanup.

### Step 6 — Update INDEX TOC

If you remove entries from the register (move in step 5), update the head INDEX TOC (section `## Index` or `## Table of Contents`).

If you keep the entry in place with just the `status: archived` marker, you can either:
- Leave the INDEX unchanged (the YAML marker is enough)
- Add a `*(archived 2026-XX-XX)*` suffix to the INDEX item

### Step 7 — Log into audits/

Write a log file of the applied actions:

```
<workspace>/audits/archive-applied-<YYYY-MM-DD-HHmm>.md
```

Format:

```markdown
# Archive applied -- <YYYY-MM-DD HH:mm>

**Mode**: <interactive | batch>
**Threshold used**: <N> days
**Source report**: `audits/scan-obsoletes-<...>.md`

## Archived entries

| ID | Register | last_updated | Operator decision |
|----|----------|--------------|-------------------|
| L-XX | <workspace>/registres/learnings.md | 2025-XX-XX | ARCHIVE confirmed |
| ... |

## KEEP entries (false positives)

- L-YY : reason "still relevant for <project>"

## SKIP entries (deferred)

- L-ZZ : to re-check at the next audit
```

## Output path

- Main report: `<workspace>/audits/scan-obsoletes-<YYYY-MM-DD-HHmm>.md`
- Application log: `<workspace>/audits/archive-applied-<YYYY-MM-DD-HHmm>.md`

Return to the caller: report path + counters summary + (if applied) number archived.

## Anti-patterns

- **NEVER delete** an entry from the register — only mark `status: archived` or move to `_archived/`. Doctrine frame 3 requires traceability.
- Do not confuse **ARCHIVE** and **REVIEW**: if an entry is REVIEW (cited or referenced), it may need merging with another (`/dedup-registres`) or promoting, not archiving.
- Do not apply in batch without human review on the first runs: for phase 1, require per-entry confirmation. Batch is possible once you trust it.
- Do not archive a `severity: critical` entry even if old — escalate.
- Do not archive a BDR (structuring decision) without explicit confirmation: BDRs live long by design.

## Verification

The skill ran correctly if:
1. The report exists at the expected path
2. The report contains the 4 sections (summary, per-register, recommendations, footer)
3. The count of ARCHIVE+REVIEW+KEEP+SKIP = total entries scanned
4. If `--apply`: the `archive-applied-*.md` file exists AND the archived entries indeed have `status: archived` in their frontmatter (verify via grep)

## Examples

### Example 1: monthly detection-only audit

```
User: /scan-obsoletes
```

Output:
```
Report generated: <workspace>/audits/scan-obsoletes-<YYYY-MM-DD-HHmm>.md
117 entries scanned
0 ARCHIVE / 2 REVIEW / 105 KEEP / 10 SKIP

REVIEW to examine manually:
- L9 (180d) : "..." — still cited 3x in events.jsonl
- L25 (185d) : "..." — referenced in a project

No ARCHIVE entry detected. System healthy.
```

### Example 2: lowered threshold for testing

```
User: /scan-obsoletes --threshold-days 90
```

Output: threshold 90d, possibly more candidates. Useful for a quarterly audit.

### Example 3: application after confirmation

```
User: /scan-obsoletes --apply
```

The script runs the scan, then for each ARCHIVE candidate asks for confirmation. Marks `status: archived` on the confirmed ones. Produces an applied log.

## Known limitations

- **No embeddings dependency**: the skill works without an API key
- **Missing events.jsonl**: graceful fallback (0 citation), no blocking failure
- **Missing frontmatter** (legacy entries): fallback git log then mtime. Less precise but functional.
- **No cross-register merge**: if a local entry was promoted globally, the 2 are distinct for this skill. Consolidation by merge is the job of `/dedup-registres`.

---

**Doctrine link**: Frame 3 (Consolidation) step 4 — Archive
**Related rules**: none directly (the skill materializes a doctrinal criterion)
