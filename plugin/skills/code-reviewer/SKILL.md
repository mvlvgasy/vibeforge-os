---
name: code-reviewer
description: Launches the Code Reviewer. Double layer (superpowers + method patterns). Verdict OK/MINOR/BLOCKING. End of every build session before push.
when_to_use: |
  End of a build session (S0, S1, ..., Sn) before push/merge PR.
  The Lead invokes it automatically in phase 5 of the project workflow (frame 12).
  You can also invoke it manually to audit a series of commits.
allowed-tools: Task
argument-hint: "(optional: review scope, e.g. 'last 3 commits' or 'feature X')"
---

Use the Task tool to invoke the `code-reviewer` subagent with:

- `subagent_type`: "code-reviewer"
- `description`: "Code review pre-push"
- `prompt`: $ARGUMENTS

The Code Reviewer sub-agent will bootstrap its context (SOUL, USER, MEMORY, PRD, architecture, conventions), run the Git diff, apply the double review layer (Superpowers + method patterns), and produce a markdown report in docs/code-reviews/. Verdict: OK / MINOR / BLOCKING.

Come back with its report.
