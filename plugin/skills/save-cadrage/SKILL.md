---
name: save-cadrage
description: Saves / updates the persistent framing memory (MEMORY-cadrage.md) of the current project. Externalizes the why, roadmap, decisions and key facts to disk to survive compactions (R018). Run on each structuring decision, after a daily, before a compaction, or at end of session.
when_to_use: |
  During a long framing session, as soon as important info appears and must not be lost:
  a structuring decision is made, a daily/stakeholder meeting was processed, a new business need emerges,
  or context grows and a compaction approaches. Also before closing the session.
  This is the save action of the project's long-term brain (distinct from the HANDOVER which only keeps the last state).
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
argument-hint: "(optional: focus, e.g. 'decision on the DB' or 'daily of 06/03')"
---

You update the **persistent framing memory** of the current project: `MEMORY-cadrage.md`. It is the anti-amnesia safety net (R018). The two memories are complementary: the conversation memory remains the live working memory, but everything critical is ALSO written to disk to survive compactions. We never depend on the conversation alone.

## Locate the file

`MEMORY-cadrage.md` lives at the root of the current meta-project:
- In a session started in a project: `./MEMORY-cadrage.md`
- From a workspace: `./projets-meta/<project>/MEMORY-cadrage.md`

If the file does NOT exist yet: create it from the template `${CLAUDE_PLUGIN_ROOT}/templates/projet-meta.template/MEMORY-cadrage.md.tpl` (replace the `{{...}}`), then fill it in.

## Method

### 1. Gather the session signal
- Re-read the recent conversation context (decisions, expressed needs, sessions mentioned).
- `git log --oneline -15` in the deliverable + the meta-project for recent commits.
- List recent `docs/` (daily transcripts, stakeholder notes) modified since the last update.
- If `$ARGUMENTS` specifies a focus, prioritize that area.

### 2. Update the sections (MERGE, not overwrite)
`MEMORY-cadrage.md` is **cumulative**. For each section, ADD or REFINE, do not delete useful history:
- **Why this project**: refine if the need has clarified.
- **Session roadmap**: add new sessions, update statuses (planned -> done, with commit/PR), note what motivated each session.
- **Structuring decisions**: add decisions made this session (dedup with existing). A decision = what + why.
- **Key technical facts**: stack, URLs, resource identifiers, capitalized bugs. NEVER secrets (no credentials, no client data).
- **Uncertainty zones**: add open questions, remove those that have been resolved.

### 3. Maintain the SUMMARY
The file has a `## SUMMARY` section at the top. Update it to reflect the present sections (and ideally a counter, e.g. "9 sessions delivered, 6 planned"). This is what sessions read first on startup, without a full read.

### 4. 400-line cap: SMART COMPACTION (no archiving)
After your update, count the lines. **HARD cap = 400 lines** (R018). If you exceed (or approach) it, do NOT create an archive file: **recompact the data in place**, keeping all the signal:
- **Delivered and closed sessions**: reduce to one line (name, objective in 5 words, status "delivered", commit/PR). Remove implementation details that became useless once the session is closed.
- **Redundant or superseded decisions**: merge. If a decision replaces an old one, keep the new one + a short mention of the change, not both in full.
- **Technical facts**: dedup, group by theme, drop the verbose.
- **Resolved uncertainties**: remove (they became decisions).
- **NEVER lose**: the why, the active decisions, the critical facts (URLs, resource identifiers, bugs+learnings), the open uncertainties.

The goal: a dense file that stays under 400 lines even after 3 months of framing, readable at a glance.

### 5. Date it
Update `derniere_maj:` in the frontmatter.

### 6. Anti-drift discipline
- Stay **factual and dense** (it's a memory, not a novel).
- If a decision contradicts a prior one, keep the new one AND briefly note the change (not just overwrite).
- NEVER write a secret / token / client email. Aggregated counts only.

## Expected output

- `MEMORY-cadrage.md` updated (frontmatter `derniere_maj` refreshed).
- A short summary to the operator: "Framing memory updated: N decisions added, roadmap refreshed (X sessions), Y uncertainties."

## Anti-patterns

- Overwriting the whole file (it's cumulative, we merge).
- Putting secrets or client data in it.
- Confusing it with HANDOVER (HANDOVER = last volatile state; MEMORY-cadrage = durable knowledge).
- Filling it once and forgetting it (the goal is to keep it alive throughout the framing).

Focus of this save: $ARGUMENTS
