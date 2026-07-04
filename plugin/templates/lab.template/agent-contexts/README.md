# Agent-contexts for lab {{LAB_NAME}}

This folder hosts the persistent "homes" of the COMPLEMENTARY agents of this lab (those defined in `<this-lab>/.claude/agents/`).

## Expected structure per agent

For each complementary agent created in `.claude/agents/<name>.md`, create here:

```
agent-contexts/<name>/
├── SOUL.md             ← stable identity
├── USER.md             ← who the operator is (preferences for this agent) — start EMPTY, no personal data
├── MEMORY.md           ← current state — start EMPTY
├── journal.md          ← chronological
├── skills/
│   └── INDEX.md        ← auto-created skills
└── credentials.env     ← optional (gitignored)
```

> Note on `USER.md` / `MEMORY.md`: in a fresh distribution these MUST start as empty stubs. Do not pre-fill them with any personal information; they get populated locally as the agent runs.

## Important note

The GENERIC agents (lead, architecte, etc.) have THEIR OWN `agent-contexts/` in the parent method (`{{VIBEFORGE_PATH}}/agent-contexts/`). Do NOT duplicate them here.

Here we put ONLY the complementary agents specific to this lab.

## Invocation pattern

When the lead (generic, in the context of this lab) wants to invoke a complementary agent:
```
Task("<complementary-agent>", "<mission contract>")
```

The agent reads its agent-contexts at bootstrap (path from the lab: `agent-contexts/<name>/...`).
