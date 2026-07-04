---
name: cloture-session
description: End-of-session audit - registers, pending-blockers/eval, HANDOVER, agent MEMORY updates, promotion candidates. Triggered by SessionEnd hook or manually.
when_to_use: |
  When the user says "let's stop", "see you tomorrow", "ok thanks", "session done",
  OR when the lead detects long inactivity, OR on demand via /cloture-session [full].
allowed-tools: Read Grep Glob Write Edit
argument-hint: "[full]"
---

## Purpose

Prevent documentation debt from accumulating. Force an explicit audit at the end of each session:
registers up to date, HANDOVER written, learnings captured, promotion candidates identified, pending-blockers/pending-eval processed.

## When to use

- End of a work session (signals: "let's stop", "see you tomorrow", "ok thanks", inactivity >=30 min)
- On explicit demand: `/cloture-session` or `/cloture-session full`
- Before a significant `/compact` or `/clear`
- At the start of the next session if a reminder is active (presence of `.claude/last-stop-reminder.md`)

## Methodology

### Standard mode (`/cloture-session`)

#### Step A - Identify the scope
1. Current CWD -> which workspace / project
2. If `git status` is accessible: list files modified since the start of the session
3. Read the lead's journal for invoked agents

#### Step B - Process `pending-blockers.md`

The post-tool-use hook auto-detects errors and appends them to `.claude/pending-blockers.md`. You must process each one:

1. Read `.claude/pending-blockers.md`
2. For each pending entry:
   - Real durable friction? -> promote to `B<NN>` in `registers/blockers.md` with full frontmatter
   - Transient error / false alarm? -> ignore (mention in journal)
   - Mergeable with an existing blocker? -> update the existing one
3. Once processed, empty or archive `pending-blockers.md`

#### Step C - Process `pending-eval.md`

The post-tool-use hook auto-detects hallucination patterns (notably invented files). Process the same way:

1. Read `.claude/pending-eval.md`
2. For each pattern: promote to `E<NN>` in `registers/eval.md` if relevant, otherwise ignore
3. Empty or archive

#### Step D - Audit local registers

- Read `registers/INDEX.md`
- For each register, ask the user:
  - New blockers to add (beyond auto-detection)?
  - New learnings?
  - Decision records to formalize?
  - Eval patterns observed manually?
- If gaps detected: propose the entries, validate, Write.

#### Step E - Write the HANDOVER

In `<project|workspace>/HANDOVER.md`:

```markdown
# HANDOVER - Session of <YYYY-MM-DD>

## Final state
<3-5 line summary>

## What was done
- <list>

## What remains (next session)
- <concrete action 1>
- <concrete action 2>

## Blockers
- <if applicable, blocker link>

## Files modified
- <list>

## Files to read first on next startup
1. This HANDOVER
2. <critical file 1>

## Decisions made this session
- <BDR<NN> or informal decision>

## Notable learnings
- <L<NN> or notes>

## Promotion candidates for traffic-controller
- <list of learnings/decisions potentially promotable>
```

#### Step F - Update MEMORY of invoked agents

For each agent invoked during the session: append a section to `<root|workspace>/agent-contexts/<agent>/MEMORY.md` and `journal.md`.

#### Step G - Delete `last-stop-reminder.md` if present

The stop hook may have created `.claude/last-stop-reminder.md`. If the closure is done, it can be deleted (signal that capitalization happened).

#### Step H - Confirm to the user

```
Closure OK.
- <N> blockers promoted, <M> ignored
- <N> learnings added
- <N> eval patterns added
- HANDOVER written
- <N> promotion candidates listed for traffic-controller
You can close the session.
```

### Full mode (`/cloture-session full`)

In addition to standard mode:

#### Step I - Global documentation debt audit

Count across all registers and project/workspace files:
- **A** = entries without complete frontmatter (missing severity, domain, or status)
- **B** = blockers `status: open` for >30 days
- **C** = learnings `status: active` not promoted for >60 days
- **D** = auto-created skills in `agent-contexts/*/skills/` never cited in any journal since creation >90 days
- **E** = entries in `pending-blockers.md` unprocessed for >7 days
- **F** = entries in `pending-eval.md` unprocessed for >7 days
- **G** = HANDOVER.md not updated since the last significant session (>3 days)

**Score formula**:
```
score = min(100,
    A * 5 +     # critical: broken structure (missing frontmatter)
    B * 3 +     # major: unresolved friction lingering
    C * 1 +     # light: dormant material to promote
    D * 2 +     # moderate: dead skill, to archive
    E * 4 +     # major: forgotten capitalization (hook did its job)
    F * 4 +     # major: untreated eval pattern
    G * 6       # critical: no HANDOVER = next session is blind
)
```

**Interpretation scale**:
- `0-15` : clean (nothing to do)
- `16-30` : OK (check in passing)
- `31-50` : handle this week
- `51-75` : urgent, `/cloture-session full` recommended now
- `76-100` : critical, immediate action

**Present to the user**:
```
Doc debt score: 32/100
Detail:
- 0 entries without frontmatter (A=0)
- 2 blockers open >30d (B=2 -> 6 points)
- 4 learnings not promoted >60d (C=4 -> 4 points)
- 1 unused skill >90d (D=1 -> 2 points)
- 5 pending-blockers unprocessed >7d (E=5 -> 20 points)
- 0 pending-eval (F=0)
- 0 stale HANDOVER (G=0)

Total: 32/100 -> handle this week
Top priority: 5 pending-blockers to handle NOW
```

#### Step J - Propose a traffic-controller scan if threshold reached

The traffic-controller is disabled in auto-scheduling (see its SOUL.md). Reactivation is by **project threshold**, not by time:

1. Count active/completed projects across all workspaces:
   ```powershell
   $count = (Get-ChildItem -Path "<workspace>/lab-*/projets/*" -Directory -ErrorAction SilentlyContinue).Count
   ```

2. If `$count >= 3` AND (last scan in `${CLAUDE_PLUGIN_ROOT}/registers/traffic-journal.md` = never OR >60 days) -> **propose a scan to the operator**:
   ```
   Traffic-controller threshold reached: <N> active/completed projects.
   Last scan: <date or "never">.
   Run /traffic-controller scan all?
   ```

3. Otherwise, mention in 1 line (no pressure):
   ```
   Traffic-controller: <N> projects / 3 required -> waiting.
   ```

**Why by threshold and not by time**: the traffic-controller must have material to scan. Running a scan every 2 weeks on 0-2 projects is a costly dead point.

#### Step K - Check global rules not read recently

For each global rule in `${CLAUDE_PLUGIN_ROOT}/registers/rules.md`, check the last citation in agent journals. If >180 days -> flag for demotion.

#### Step L - Verify register audits + suggest BDR/Eval promotion

> Makes the register consolidation cycle ACTIVE by suggesting the appropriate skills based on the age of the last audits.

Check the age of the last audits and suggest promotions:

##### L.1 - Age of the last dedup-registres

```powershell
$lastDedup = Get-ChildItem -Path "${CLAUDE_PLUGIN_ROOT}/audits/dedup-registres-*.md" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$daysSinceDedup = if ($lastDedup) { ((Get-Date) - $lastDedup.LastWriteTime).Days } else { 999 }
```

- If `$daysSinceDedup > 30` -> **suggest** `/dedup-registres`:
  ```
  Last dedup-registres audit was $daysSinceDedup days ago.
     Recommended: run `/dedup-registres` to detect new duplicates.
  ```
- If `<= 30d`: show nothing (silent)

##### L.2 - Age of the last scan-obsoletes

```powershell
$lastScan = Get-ChildItem -Path "${CLAUDE_PLUGIN_ROOT}/audits/scan-obsoletes-*.md" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$daysSinceScan = if ($lastScan) { ((Get-Date) - $lastScan.LastWriteTime).Days } else { 999 }
```

- If `$daysSinceScan > 60` -> **suggest** `/scan-obsoletes` (check at 60d because entries must age before becoming obsolete)
- If `<= 60d`: silent

##### L.3 - New decision markers in HANDOVER -> suggest /promote-decision-to-bdr

Grep in active HANDOVER.md files (modified since last BDR audit) for markers:
```bash
grep -lE "(we (have )?decide|decision (made|recorded|validated)|pivot to|from now on|founding principle|non-negotiable|we switch)" \
  <workspace>/HANDOVER.md <workspace>/lab-*/HANDOVER.md <workspace>/lab-*/projets-meta/*/HANDOVER.md \
  2>/dev/null | head -5
```

- If >= 1 file matches since the last BDR audit:
  ```
  Decision markers detected in <N> HANDOVER.md.
     Recommended: run `/promote-decision-to-bdr --scope all` to formalize as BDR.
  ```

##### L.4 - Hallucination markers in recent learnings.md -> suggest /promote-pattern-to-eval

Grep in `${CLAUDE_PLUGIN_ROOT}/registers/learnings.md` (and workspaces) for LLM hallucination patterns in recent entries (<= 30d):
```bash
grep -nE "(halluci|silent fallback|silent (fail|fallback)|schema drift|tool_use (fail|broken)|MALFORMED|single-shot (failure|fail)|meta-recursion)" \
  ${CLAUDE_PLUGIN_ROOT}/registers/learnings.md \
  2>/dev/null | head -5
```

- If >= 2 matches not already promoted to eval (cross-check `promoted_to:` in frontmatter):
  ```
  <N> recent learnings contain unpromoted LLM hallucination markers.
     Recommended: run `/promote-pattern-to-eval --scope global` to migrate L->E.
  ```

##### L.5 - Synthesis

Present in one compact block at the end of the closure:

```
Register consolidation recommendations:
  - [Case 1] dedup-registres 47d ago -> run `/dedup-registres`
  - [Case 2] 3 HANDOVER.md with unformalized decisions -> `/promote-decision-to-bdr --scope all`
  - [Case 3] 2 learnings with unpromoted hallucination markers -> `/promote-pattern-to-eval`

Run them one by one whenever you want, no rush.
```

**No auto-launch.** This step is a *signal*, not an action. The operator decides when to run them.

**Anti-pattern to avoid**: suggesting all skills at every closure (noise). Respect the thresholds (>30d, >60d, >=2 matches) so you only suggest when relevant.

## Anti-patterns

- Doing the closure but without an actionable HANDOVER
- Skipping `pending-blockers.md` processing (the hook auto-detected them, they are precious)
- Skipping `pending-eval.md` processing (same)
- Vague HANDOVER ("we'll continue next time") without specifying what
- Promoting ALL pending-blockers to blockers (filter false alarms)
- Updating agent MEMORY without dating it
- Running `/cloture-session full` every day (token cost)

## Examples

### Simple session
```
Operator: "Ok thanks"
Lead: "[invoke /cloture-session]"

Skill:
1. Detects session on a client workspace, files modified: projets/onboarding-v2/docs/PRD.md
2. Reads .claude/pending-blockers.md: 0 entry
3. Reads .claude/pending-eval.md: 0 entry
4. Asks the operator for new blockers/learnings: they flag 1 learning on PRD format
5. Appends L001 to the workspace registers/learnings.md
6. Writes HANDOVER: "PRD v0.2 ready. Next session: stakeholder validation then architecture"
7. Updates MEMORY business-analyst
8. Confirms
```

### Complex session (with auto-detections)
```
Operator: "See you tomorrow"
Lead: "[invoke /cloture-session full]" (3h session, 4 agents, 2 auto-detected errors)

Skill full:
1-7: standard
8. Processes pending-blockers: 2 entries
   - "missing-dependency": real friction -> promoted to B042 (forgotten npm install)
   - "timeout": transient -> ignored, mentioned in journal
9. Processes pending-eval: 1 entry (invented file) -> promoted to E007
10. Debt audit: score 12/100 (good)
11. Proposes traffic-controller scan (last scan = 18 days)
12. Confirms
```

## Verification

After execution:
- [ ] `pending-blockers.md` and `pending-eval.md` processed (empty or archived)
- [ ] HANDOVER exists with mandatory sections
- [ ] Registers up to date (consistent INDEX, correct counters)
- [ ] MEMORY of invoked agents updated
- [ ] `last-stop-reminder.md` deleted if present
- [ ] HANDOVER "Promotion candidates" section consistent

---

**Version**: 2.0 (with processing of hook-auto-detected pending-blockers/pending-eval)
