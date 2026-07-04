---
name: dream
description: MEMORY consolidation (R009). 3 modes: auto (session-start hook >24h), manual (HITL), global (stack-wide, cross-lab). Strict MEMORY scope only — not the registers.
when_to_use: |
  Auto-triggered by the session-start hook if >24h since last dream (cadence 1x/day, scope = local cwd).
  Manual for debug, audit, or deep review with `/dream manual`.
  Global to sweep the whole stack in one command with `/dream global` (rare, weekly/post-project).
allowed-tools: Task Read Edit Write Bash Glob Grep
argument-hint: "[manual | auto (default) | global]"
---

# /dream — Automatic MEMORY consolidation with validator

Consolidation flows through two stages: Main Claude proposes consolidation updates, then the `dream-validator` agent filters them (apply / reject / defer), and only the validated `apply` items are written.

## AUTO mode workflow (default)

### Step 1 — Parse $ARGUMENTS

- If `$ARGUMENTS` contains `manual` → switch to MANUAL mode (alternate workflow below)
- If `$ARGUMENTS` contains `global` → switch to GLOBAL mode (stack-wide workflow below)
- If `$ARGUMENTS` contains `registres` → reply *"The /dream scope is strictly MEMORY. For the registers, use `/traffic-controller scan all`."* and stop.
- Otherwise (empty or `auto`) → AUTO mode below (scope = current cwd only).

### Step 2 — Produce consolidation proposals

Main Claude runs the consolidation pass. Strict MEMORY scope only.

Temporal window:
- Since the last `last_consolidation_ts`
- If never run: last 7 days

Read the relevant journals and current MEMORY files, then write the proposals into `agent-contexts/dreamer/pending-updates.md`. Produce a short summary (5-10 lines) with N proposals, K traffic-controller suggestions, M alerts.

### Step 3 — Read `pending-updates.md`

Read `agent-contexts/dreamer/pending-updates.md`. If:
- File empty or missing → log event `kind:"dream_run"` (proposals=0), stop.
- File present with 0 proposals → announce "Nothing to consolidate", log event, stop.
- File present with proposals → continue to step 4.

### Step 4 — Invoke the dream-validator

Use Task tool with:
- `subagent_type`: "dream-validator"
- `description`: "Validate dream proposals"
- `prompt`: |
  Review `agent-contexts/dreamer/pending-updates.md`. For each proposal, decide
  apply / reject / defer per your 3 grids. Write your decision into
  `agent-contexts/dream-validator/decision-<ts>.md` in the strict (machine-parseable) format.
  Return a 5-10 line summary: N received, K apply, M reject, P defer, V violations.

Wait for the validator to return its summary.

### Step 5 — Read the validator's decision

Read `agent-contexts/dream-validator/decision-<ts>.md` (the most recent one).
Parse the proposals classified `apply` / `reject` / `defer`.

### Step 6 — Apply the `apply` items automatically

For each proposal marked `apply`:

#### Update MEMORY (shared / universal / lab)

```
If append-section : Edit the target file to add the section.
                    Check the section does not already exist (anti-duplicate).
If simple append  : Edit to add at the end of the MEMORY.
If replace        : Edit with old_string / new_string.
```

**Final guardrail**: before writing into `_shared/MEMORY.md`, recount the words. If over 300 → log error + skip this proposal (the validator should have rejected it already, but this is defense-in-depth).

**Absolute out-of-scope**: `/dream` NEVER touches `registres/**`. If an `apply` proposal from the validator points to `registres/` → ERROR + critical alert (validator bug). Skip.

### Step 7 — Log the `reject` items

For each proposal marked `reject`:
- Append a dated block to `agent-contexts/dreamer/rejected-log.md` with:
  - Rejected proposal
  - Validator's reason
  - Timestamp
- No other action

### Step 8 — Preserve the `defer` items

For each proposal marked `defer`:
- Keep the proposal in `pending-updates.md` (do NOT delete it during archiving)
- Create/append `agent-contexts/dreamer/deferred-queue.md` with:
  - Deferred proposal
  - Validator's reason
  - Timestamp
- You can run `/dream manual` later to review these deferred items

### Step 9 — Traffic-controller suggestions (signal-only)

If the `suggestions_traffic_controller` section of `pending-updates.md` contains >=1 entry:

Display (or log if running auto without a present operator):

```
The dream pass observed <K> recurring patterns (traffic-controller candidates):
- <pattern 1>
- <pattern 2>

Run `/traffic-controller scan all` whenever you want to formalize them into learnings/rules.
```

No auto-apply — this is just a signal.

### Step 9-bis — BDR/Eval promotion suggestions + dormant audits

> This step suggests the BDR/Eval promotion skills if conditions are met. Signal-only mode, no auto-apply.

Check audit age + detect recent markers:

##### 9-bis.1 — Dormant audits (dedup + scan-obsoletes)

```powershell
$lastDedup = Get-ChildItem -Path "<workspace>/audits/dedup-registres-*.md" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$lastScan = Get-ChildItem -Path "<workspace>/audits/scan-obsoletes-*.md" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$daysSinceDedup = if ($lastDedup) { ((Get-Date) - $lastDedup.LastWriteTime).Days } else { 999 }
$daysSinceScan = if ($lastScan) { ((Get-Date) - $lastScan.LastWriteTime).Days } else { 999 }
```

##### 9-bis.2 — New markers

- Decision markers in HANDOVER: grep `(we decide|from now on|pivot to|founding principle|non-negotiable)` in HANDOVER.md files modified since last scan
- Hallucination markers in learnings: grep `(halluci|silent fallback|schema drift|tool_use fail|single-shot fail)` in learnings.md entries not yet promoted to eval

##### 9-bis.3 — Suggestions displayed (manual mode only)

If **manual or global mode** (not auto mode) AND conditions met:

```
Register consolidation suggestions:

[If $daysSinceDedup > 30]
  Dedup-registres last run $daysSinceDedup days ago
     → Run `/dedup-registres` to detect duplicates

[If $daysSinceScan > 60]
  Scan-obsoletes last run $daysSinceScan days ago
     → Run `/scan-obsoletes` for archive candidates

[If >=1 HANDOVER with un-formalized decision markers]
  <N> HANDOVER.md files contain decisions not formalized as BDR
     → Run `/promote-decision-to-bdr --scope all`

[If >=2 learnings with un-promoted hallucination markers]
  <N> recent learnings contain LLM hallucination markers
     → Run `/promote-pattern-to-eval --scope global`

No auto-apply. You decide when to run (monthly recommended for the 3 skills).
```

##### 9-bis.4 — Auto mode (silent)

If **auto mode** (triggered by session-start hook): do NOT display (UX pollution). Log into `<workspace>/.claude/dream-auto.log`:

```
[<ts>] dream-auto : suggestions BDR=<N1>, Eval=<N2>, dedup-age=<D1>d, scan-age=<D2>d
```

You can check the log if you want, or see the suggestions at the next `/dream manual`.

##### 9-bis.5 — Anti-patterns to avoid

- Auto-running `/dedup-registres` or `/promote-*` (each promotion deserves human validation)
- Displaying the suggestions on every auto dream (noise — only do it in manual/global)
- Emitting suggestions without thresholds (>30d dedup, >60d scan, >=2 markers) — otherwise constant noise

### Step 10 — Update dreamer + validator state

- Edit `agent-contexts/dreamer/MEMORY.md`:
  - `last_consolidation_ts`: current timestamp
  - `nb_consolidations_total`: +1

- Edit `agent-contexts/dream-validator/MEMORY.md`:
  - `last_validation_ts`: current timestamp
  - `nb_validations_total`: +1
  - `cumulative_stats`: update apply_rate/reject_rate/defer_rate averages

- Append a dated block to `agent-contexts/dreamer/journal.md`
- Append a dated block to `agent-contexts/dream-validator/journal.md`

### Step 11 — Log metrics event

Append a JSON line event to `${CLAUDE_PLUGIN_ROOT}/metrics/events.jsonl`:

```json
{"ts":"<ISO>","kind":"dream_run","mode":"auto","propositions_n":<N>,"apply_k":<K>,"reject_m":<M>,"defer_p":<P>,"violations_v":<V>,"signals_tc":<S>,"duration_sec":<D>}
```

Use Bash:
```bash
echo '<json line>' >> "${CLAUDE_PLUGIN_ROOT}/metrics/events.jsonl"
```

### Step 12 — Reset nudge + last-dream-ts

- If `<cwd>/.claude/dream-reminder.md` exists: delete it (the invitation has been honored)
- Write `${CLAUDE_PLUGIN_ROOT}/.claude/last-dream-ts.txt` with the current timestamp
- If defer >=1: create `.claude/dream-deferred-pending.md` to remind you that you have manual decisions to make at the next `/dream manual`

### Step 13 — Archive pending-updates + decision

Move:
- `agent-contexts/dreamer/pending-updates.md` → `agent-contexts/dreamer/archive/pending-updates-<YYYY-MM-DD-HH-mm>.md`
- `agent-contexts/dream-validator/decision-<ts>.md` → `agent-contexts/dream-validator/archive/decision-<ts>.md`

Preserve the `defer` items in a new (rewritten) `pending-updates.md` if applicable, for the next `/dream manual`.

### Step 14 — Final summary (silent if auto mode)

If auto via hook: log into `<workspace>/.claude/dream-auto.log`:
```
[<ts>] dream auto : N=<n> proposals / K=<k> applied / M=<m> rejected / P=<p> deferred / V=<v> violations
```

If manual invocation (`/dream` without hook): display the summary on screen.

---

## GLOBAL mode workflow (`/dream global`) — stack-wide

Sweeps the WHOLE stack in one pass, detects cross-lab patterns (candidates for promotion to `_shared/MEMORY.md`), applies in a single validator batch.

Cost: higher than AUTO (Main Claude reads ~5-10x more files: all labs + all agent-contexts). Reserve for rare uses (weekly audit, post-large-multi-lab project, when you want to "consolidate everything in 1 command").

### Step 1 — Stack detection

```bash
# List the folders to scan (under the workspace, excluding utilities)
STACK_BASE="<workspace>"
ls -d "$STACK_BASE"/*/ | grep -E "(vibeforge$|lab-|projet)"
```

Build the `SCANNED_DIRS` list dynamically:
- The method root (always)
- Any folder matching `lab-*/` under the workspace (skip `lab-*-archive/` which are read-only)
- Any folder matching `projet-*/` if applicable

### Step 2 — Cross-folder reading

For EACH folder in `SCANNED_DIRS`, Main Claude reads in parallel:

1. **Journals**: `<dir>/registres/journal.md` (lab) or `<dir>/agent-contexts/<agent>/journal.md` (universal)
   Temporal window: entries since last `last_global_consolidation_ts` (or last 7 days if never run)
2. **Current MEMORY**: `<dir>/agent-contexts/<agent>/MEMORY.md` (for each agent present)
3. **Git log**: `git -C <dir> log --oneline --since="<last_ts>"` to understand activity

Read in parallel to save round-trips. Use Glob to identify the agents present in each `agent-contexts/`.

### Step 3 — Cross-lab pattern detection (CORE of global mode)

For EACH observed pattern, classify:

| Pattern observed in | Classification | Target scope |
|---|---|---|
| 1 lab only | **lab-local** | `<lab>/agent-contexts/<agent>/MEMORY.md` |
| 1 universal agent only | **universal** | `<workspace>/agent-contexts/<agent>/MEMORY.md` |
| >=2 different labs for THE SAME agent | **universal** (promotion) | `<workspace>/agent-contexts/<agent>/MEMORY.md` + note "observed in lab-X and lab-Y" |
| >=2 different agents (any lab) | **shared** (strong promotion) | `<workspace>/agent-contexts/_shared/MEMORY.md` |

The **shared** items are the major innovation of global mode: without this cross-lab sweep, these patterns would stay confined to their local scope without ever being promoted.

### Step 4 — Produce cross-scope `pending-updates.md`

Write into `<workspace>/agent-contexts/dreamer/pending-updates-global-<YYYY-MM-DD-HH-mm>.md` (timestamped name distinct from the standard `pending-updates.md`, so it does not overwrite a local dream in progress).

Format identical to the standard pending-updates BUT each proposal has an extra field:

```yaml
- id: prop-007
  scope: shared  # or universal | lab-client | lab-content | lab-perso
  target_file: <workspace>/agent-contexts/_shared/MEMORY.md
  source_labs: [lab-client, lab-content]  # >=2 = shared promotion
  proposition: |
    ...
  evidence: |
    - L08 lab-client : Next 16 webpack issue
    - L03 lab-content : Next 16 turbo env vars
  confidence: high
```

### Step 5 — Invoke the dream-validator (same grids)

Use Task tool with `subagent_type: "dream-validator"`. The validator works identically on global proposals. Its existing grid:
- **Grid 1** (auto reject): violations
- **Grid 2** (auto apply): >=3 distinct sources + clear scope + no rule violated
- **Grid 3** (defer): grey zone

**Global mode bonus**: if an `apply` proposal targets `_shared/MEMORY.md` AND comes from `source_labs.length >= 2`, it is an automatic shared promotion — log a strong signal in the final report.

### Step 6 — Auto-apply the apply items (same as AUTO but cross-scope)

For each `apply`, Edit the indicated `target_file`. Identical guardrails (300 words shared, out of registers). The `target_file` can now point to any folder of the stack.

### Step 7 — Log + global archive

- Append `agent-contexts/dreamer/journal.md` with a dedicated `mode:global` block
- Move `pending-updates-global-<ts>.md` → `agent-contexts/dreamer/archive/`
- Move `decision-<ts>.md` → `agent-contexts/dream-validator/archive/`
- Update `agent-contexts/dreamer/MEMORY.md`: `last_global_consolidation_ts` (distinct field from `last_consolidation_ts` which stays for local dreams)

### Step 8 — Dedicated metrics event

Append to `${CLAUDE_PLUGIN_ROOT}/metrics/events.jsonl`:
```json
{"ts":"<ISO>","kind":"dream_run","mode":"global","scanned_dirs":<N>,"propositions_n":<N>,"apply_k":<K>,"shared_promotions":<S>,"reject_m":<M>,"defer_p":<P>,"duration_sec":<D>}
```

The `shared_promotions` field = number of `apply` proposals that targeted `_shared/MEMORY.md` from >=2 sources. This is the signature metric of global mode.

### Step 9 — Final summary (always displayed, never silent)

Global mode is NOT auto-triggered by a hook → always invoked manually. So display the summary on screen:

```
/dream GLOBAL — <YYYY-MM-DD HH:mm>

Stack scanned: <N> folders (method root + <K> labs)
Cross-scope proposals: <N>
  - lab-local       : X
  - universal       : Y
  - shared (PROMOS) : Z

Validator: <A> apply / <R> reject / <D> defer
Shared promotions (cross-lab detected): <Z>
Traffic-controller signals: <S>

→ Run `/traffic-controller scan all` whenever you want to formalize the shared
  promotions into cross-cutting learnings/rules.
```

### Guardrails specific to GLOBAL mode

- **Cadence**: no auto re-run. If `last_global_consolidation_ts` < 24h, warn the operator and ask for confirmation before re-running (avoid costly duplicate)
- **Token limit**: if the cross-stack read exceeds 500k cumulative tokens (estimated via wc -l x ratio), warn that the current session may fill the context
- **Anti-cascade**: do NOT run a local dream during a global dream (lock file `agent-contexts/dreamer/.global-running.lock`)

---

## MANUAL mode workflow (`/dream manual`)

For debug or deep review. Skips the validator, manual proposal-by-proposal presentation.

### Step 1 — Produce proposals (same as auto)

### Step 2 — Read `pending-updates.md` (same as auto)

Includes the `defer` items from the last auto run if applicable.

### Step 3 — Present to the operator

Display a structured recap:

```
/dream MANUAL consolidation — <YYYY-MM-DD HH:mm>

MEMORY proposals: <N>
- shared updates : X
- universal updates : Y
- lab updates : Z

Deferred from last auto run: <P>
Traffic-controller suggestions: <K>

→ Review proposal by proposal? (yes / cancel)
```

### Step 4-N — Interactive review

For each proposal (including deferred): present diff + justification, ask apply / skip / reformulate.

### Step — Apply + log + archive (like steps 6-13 of auto mode)

---

## Guardrails

- **Anti-overwrite**: before Edit, check that old_string exists in the file
- **Anti-loss**: if Edit fails → log into dreamer journal with the error, do not continue the batch
- **Shared 300-word limit**: check after each Edit of `_shared/MEMORY.md`. If exceeded → revert + alert
- **Anti-corruption**: if pending-updates.md or decision-<ts>.md is malformed → log error, do not crash, flag the bug
- **Auto mode only if >24h**: the session-start hook already checks this; redundancy in the skill just in case

## Anti-patterns

- Running `/dream` every session → target cadence 1x/day (24h minimum gap)
- Applying without going through the validator in auto mode → architecture bypass
- Ignoring `defer` items (deleting them without archiving) → loss of valid proposals
- Deleting `pending-updates.md` without archiving → loss of audit trail
- Writing into `_shared/MEMORY.md` without the 300-word check → uncontrolled inflation
- **Attempting to write into `registres/learnings.md` or `rules.md`** → out of strict scope
- Skipping the `metrics/events.jsonl` event → breaks the `/metrics-report` reports

## See also

- `agents/dream-validator.md` — the agent that validates
- `agent-contexts/_shared/README.md` — shared memory convention
- `doctrine/13-memory-scoping.md` — the scoping doctrine
- `registres/rules.md#R009` — the rule
- `hooks/session-start.ps1` — the auto-trigger
- `skills/metrics-report/SKILL.md` — periodic audit
