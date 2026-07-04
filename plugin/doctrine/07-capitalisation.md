# Frame 7 — Capitalization

> Closing process that prevents documentation debt.

## Definition

Capitalization is the set of mechanisms that force the agent (and you) to **finish each session cleanly**: registers up to date, HANDOVER written, learnings captured, candidate promotions identified. Without it, documentation debt explodes within a few weeks.

## The 4 capitalization mechanisms

### 1. Skill `/cloture-session` (manual)
Invoked at the end of a session by you or by the lead. Explicit audit with a checklist:

- [ ] Local registers up to date (at least journal.md)
- [ ] HANDOVER written for the next session
- [ ] New learnings captured (with complete frontmatter)
- [ ] Resolved blockers marked as such
- [ ] Decision records taken added to the register
- [ ] Observed eval patterns recorded
- [ ] Auto-created skills validated by curator
- [ ] Candidate promotions listed for traffic-controller
- [ ] No forgotten TODO in the code

If an item is missing → the user is prompted to complete it before the session officially ends.

### 2. Hook `SessionEnd` (automatic)
If `/cloture-session` was not invoked and the session ends, the hook:
- Automatically appends the session journal (minimal entry)
- Detects candidate blockers from errors observed during the session
- Creates a `pending-capitalization.md` file that will be processed in the next session
- Notifies you at the next session: "The previous session was not closed cleanly, run `/cloture-session full`"

### 3. Agent `reviewer-prd` (preventive)
Before EACH build session, `reviewer-prd` is invoked. It checks:
- The PRD coverage (R001) is respected
- The criteria, constraints, and locked decisions are all present
- The HANDOVER from the previous session has indeed been read

Without its OK, no build session.

### 4. Agent `skill-curator` (continuous validation)
Every skill self-creation goes through it. Prevents pollution of the base by low-quality skills.

## HANDOVER format

```markdown
# HANDOVER — Session of <YYYY-MM-DD>

## Final state of the session
<summary in 3-5 lines>

## What was done
- <Precise list of accomplishments>

## What remains to be done (next session)
- <Concrete action 1>
- <Concrete action 2>

## Possible blockers
- <If applicable, with a link to the recorded blocker>

## Modified files
- <path1>
- <path2>

## Files to read first when starting the next session
1. This HANDOVER
2. <critical file 1>
3. <critical file 2>

## Decisions made this session
- <DR<NN> or informal decision>

## Notable learnings
- <L<NN> or notes>

## For the lead on resumption
"Start the session with: [Read CLAUDE.md, registers, this HANDOVER, then continue on <next action>]"
```

## Documentation debt audit

`/cloture-session full` additionally runs:
- Count of entries without complete frontmatter (to fix)
- Count of blockers unresolved for >30 days (to arbitrate)
- Count of learnings not promoted for >60 days (to be reviewed by traffic-controller)
- Count of auto-created skills unused since creation (to be reviewed by skill-curator)

Output: a "doc debt" score (0-100, 0 = spotless, 100 = catastrophic).

## When NOT to capitalize

Cases where capitalization is explicitly skipped:
- Draft session (short exploration without modifications)
- Interrupted session (emergency)
- 100% read session (no writing, no decision)

But even in these cases, the `SessionEnd` hook appends at minimum the trace in the journal.

## Anti-patterns

- ❌ Skipping `/cloture-session` "because I'm in a hurry" → debt accumulates, the future cost is 10×
- ❌ Vague HANDOVER ("we'll continue next time") → the next session starts from scratch
- ❌ No blocker capture → we repeat the same mistakes
- ❌ No learning capture → traffic-controller has nothing to promote
- ❌ Capitalization without an actionable HANDOVER → the next lead doesn't know where to resume
- ❌ Capitalization only for "real" sessions, never for short ones → ironically the short ones are those that contain the most subtle learnings

## See also

- Frame 2: Registers (where capitalization lives)
- Frame 3: Consolidation (consolidates what was capitalized)
- Frame 4: Agents (reviewer-prd, skill-curator are the guardians)
- Skill `/cloture-session` in `.claude/skills/cloture-session/SKILL.md`
