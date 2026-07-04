---
name: verify-completion
description: Verifies an agent's completion claims against concrete evidence (diff, test output). Triggered by the Stop hook on .claude/verification-required.md or manually.
when_to_use: |
  When `.claude/verification-required.md` is present in the cwd (placed by the
  Stop hook on detection of a completion pattern). Also invocable manually
  to retrospectively audit an agent's claims.
allowed-tools: Read, Bash, Glob, Grep, Skill
argument-hint: "[claim: <text of the claim to verify> | flag-file (default)]"
---

# /verify-completion

Operational anti-hallucination. The R001 doctrine guarantees the PRD before the build; this skill guarantees that what is *said done* is *really done*.

## Differentiation vs `superpowers:verification-before-completion`

The two skills are **complementary, not competing**. They don't self-sabotage because they act at different moments:

| Aspect | `verify-completion` (this skill) | `superpowers:verification-before-completion` |
|---|---|---|
| **When** | At the **end** of a session (Stop hook) or manual invocation | **BEFORE** the agent claims to be done, in its own flow |
| **Who triggers** | External to the agent (OS hook + user) | The agent itself, integrated into its reasoning |
| **Mechanism** | Regex pattern match on transcript -> flag -> skill requests evidence | Skill the agent invokes BEFORE saying "I'm done" to self-verify |
| **Position** | **Downstream** (after the claim was emitted) | **Upstream** (prevents the unverified claim) |
| **Case covered** | Agent that forgets to invoke superpowers, or claim emitted without an agent call | Rigorous agent wanting to self-discipline |

**Why keep both**:
1. The agent may **forget** `superpowers` (imperfect human or AI) -> the Stop hook catches it via `verify-completion`
2. If `superpowers` is invoked correctly, the Stop hook's `verification-required.md` flag may not trigger (claim absent from transcript because proven upstream) -> natural no-op
3. Defense in depth: 2 chances to catch a hallucination, acceptable asymmetry

**Future decision**: if metrics show that `superpowers` is invoked in 95%+ of completion cases, the Stop hook on `verify-completion` can be disabled. For now we don't have that measure -> keep both.

## Workflow

1. **Source of the claim**:
   - Default: read `<cwd>/.claude/verification-required.md` (placed by the Stop hook)
   - Otherwise: explicit argument passed via `$ARGUMENTS`
   - If nothing: exit with message "No claim to verify."

2. **Decompose the claim**:
   - List of verifiable assertions: files created/modified, passing tests, command that exits 0, observable behavior
   - For each assertion -> define the **concrete test** (command to run, file to read, regex to match)

3. **Verify each assertion**:
   - **File created**: `Glob` or `Read` to confirm existence + reasonable content
   - **File modified**: `git diff <file>` must return a non-empty diff since the previous HEAD
   - **Tests pass**: `Bash` the test command, exit code 0
   - **Observable behavior**: specific command expected by the claim
   - **Correct implementation** (semantic): `Skill(superpowers:code-reviewer)` for non-trivial code changes

4. **Report**:
   - pass for verified assertions
   - fail for assertions that fail (with failure detail)
   - unverifiable for assertions not verifiable with available tools (state why)

5. **Action**:
   - If all pass: delete `.claude/verification-required.md` + add `[verified: <ts>]` to the local journal
   - If at least one fail: leave the flag, write the report to `.claude/verification-report-<ts>.md`, raise an explicit alert to the operator (the agent hallucinated a completion)
   - Append metrics event `kind:"verification_done"` or `kind:"verification_failed"`

## Delegation to Superpowers

This skill complements `superpowers:verification-before-completion` (which formalizes the "evidence before assertions" discipline). If relevant, delegate the semantic verification to `Skill(superpowers:verification-before-completion)` rather than reinventing it.

The difference here:
- Superpowers: manual skill, self-check discipline
- This method: auto-triggered by the Stop hook on pattern detection -> systematizes without imposing

## Format `.claude/verification-required.md`

The Stop hook writes it append-only on each detection:
```markdown
# Verification required (auto-detected by Stop hook)

> Completion patterns detected in the agent's response. Each entry must be verified before the session advances.

## <timestamp>
- Pattern matched: "I implemented X"
- Context (200 chars): "...I implemented the PostToolUse hook by adding the try/catch block..."
- Expected action: run `/verify-completion` then delete this file if OK

## <timestamp>
...
```

## Guardrails

- **Non-blocking skill by default**: it is invoked manually or via the CLAUDE.md mention (see bootstrap), not via an automatic mid-session exec.
- **The flag is a nudge, not a barrier**: the session continues normally if the operator chooses to ignore the flag - at worst we have a false positive.
- **Anti-false-positives**: "I did not do X" matching "did" is an acceptable false positive. The cost is low, the benefit of detecting real cases is greater.
- **Memory**: if you often verify the claims of the same agent and they are reliable, note it in `agent-contexts/<agent>/MEMORY.md` ("reliable claims: no need to verify systematically") - the skill can then be skipped for that agent.
