---
name: review-prd-coverage
description: PRD coverage audit before build (R001). Compares a candidate prompt vs PRD+architecture+HANDOVER+rules. Decisive verdict: OK / NOT OK / REVIEW.
when_to_use: |
  Before EVERY BUILD session prompt. Mandatorily invoked by the lead via reviewer-prd.
  NOT for exploratory/debug/refactor sessions without new production code.
allowed-tools: Read Grep Glob
---

## Purpose

Prevent PRD criteria from being forgotten in a build session prompt. Materializes R001 - a non-negotiable rule.

## When to use

**MANDATORY before**:
- Any "S<N> build" session that modifies production code
- Any prompt that says "implement", "code", "add feature X"

**Optional for**:
- Exploratory sessions (brainstorm, debug)
- Refactor sessions without new code
- Docs/tests-only sessions

**Explicitly bypassable** by the operator for:
- Urgent hotfix (but a catch-up session is required afterward)

## Methodology

### Step 1 - Identify the scope

- Which project (`<workspace>/projets/<name>/` or external client repo)?
- What is the candidate prompt (given by lead or prompt-engineer)?
- Which session (S<N>)?

### Step 2 - Read the sources IN FULL

**Not skimming. This is R001.**

Mandatory sources:
1. `<project>/docs/PRD.md` (full)
2. `<project>/docs/architecture.md` (full)
3. `<project>/docs/addendum-architecture.md` or `addendum-archi.md` (if it exists)
4. `<project>/docs/transcription-*.md` (all, if they exist)
5. `<project>/HANDOVER.md`
6. `<project>/.claude/rules/00-XX.md` (all, in numerical order)

Optional sources:
- `<workspace>/contexte-domaine.md` (domain-context) if domain-sensitive effort
- Previous audits in `<project>/docs/prd-coverage-reports/`

### Step 3 - Extract the criteria

For each source, identify:
- **Functional criteria** (PRD): "F1", "F2"... or descriptions "The app must X"
- **Locked decisions** (architecture): §1, §2...
- **Technical constraints** (rules): imposed stack, forbidden libs
- **Security constraints**: auth, secrets, validation
- **Acceptance criteria**: thresholds, metrics

List each with a short ID: `PRD-F1`, `ARCHI-§3`, `RULE-01-stack`, etc.

### Step 4 - Audit the candidate prompt

For each identified criterion:
- Present EXPLICITLY in the prompt
- Present IMPLICITLY ("see PRD" without detail)
- ABSENT

Use Grep to search for keywords in the prompt.

### Step 5 - Produce the report

Format:
```markdown
# PRD Coverage Report - <Project> / Session <N>

## Sources read (timestamps)
- PRD: <path> - modified <date>
- Architecture: <path> - modified <date>
- Addendum: <path> or N/A
- Transcripts: <list>
- HANDOVER: <path> - modified <date>
- Project rules: `.claude/rules/00-XX.md` x <N>

## Extracted criteria

### From the PRD (F<X>)
| ID | Description | Present |
|----|-------------|---------|
| F1 | <crit> | yes |
| F2 | <crit> | no |

### From the architecture (§)
| § | Decision | Present |
|---|----------|---------|
| §3 | <...> | yes |
| §7 | <...> | implicit |

### From the project rules
| Rule | Constraint | Present |
|------|------------|---------|
| 01-stack | TS strict | yes |
| 02-security | Zod validation | no |

### From the previous HANDOVER
- Next steps S<N-1> covered: <X/Y>
- Initial state carried over: yes / no

## Missing criteria (blocking)
- F2: <precise description>
- 02-security: <precise constraint>

## Implicit criteria (to make explicit)
- §7: <decision>

## Decision
**NOT OK** (or OK / REVIEW)

**Reason**: <1-line synthesis>

**Required action**:
- prompt-engineer must explicitly add: <precise list>
- Resubmit after correction.
```

### Step 6 - Append the report

Write to `<project>/docs/prd-coverage-reports/session-S<N>-audit-v<n>.md` (create the folder if needed).

### Step 7 - Return the decision

- If OK -> the prompt can be sent to the operator for launch
- If NOT OK -> re-delegated to prompt-engineer (max 3 iterations then escalate to the operator)
- If REVIEW -> operator decision

## Anti-patterns

- "The PRD is in my head" -> root cause of coverage incidents
- Skimming "I know the project"
- Considering "see PRD" in the prompt as sufficient
- Bypassing to save time
- Approving critical implicits without flagging

## Examples

### Audit OK
```
Lead invokes reviewer-prd for prompt S3 onboarding-v2.

reviewer-prd reads:
- PRD.md (12 criteria F1-F12)
- architecture.md (15 decisions §1-§15)
- HANDOVER S2.md (3 next steps)
- 7 project rules

Audit:
- 12/12 PRD criteria present
- 15/15 locked decisions present
- 3/3 next steps covered
- 7/7 rules respected

Decision: OK. Session S3 can start.
Report: docs/prd-coverage-reports/session-S3-audit-v1.md
```

### Audit failure
```
reviewer-prd detects:
- PRD-F7 absent from the prompt
- ARCHI-§14 absent (API rate limit)
- RULE-02-security: Zod validation missing

Decision: NOT OK
Action: prompt-engineer must add F7, §14, Zod validation.
```

## Verification

- [ ] All listed sources were actually read (timestamps logged)
- [ ] Exhaustive criteria table
- [ ] Decisive verdict (no "almost OK")
- [ ] Report appended to `prd-coverage-reports/`
- [ ] If NOT OK: precise and actionable list of gaps

---

**Version**: 2.0
**Reference**: rule R001
