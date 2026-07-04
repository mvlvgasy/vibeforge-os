---
name: cloture-cadrage
description: Closes a long framing phase (R007) - Lead synthesis, MEMORY update, releases routing. Use before switching to build or moving to another effort. Distinct from /cloture-session.
when_to_use: |
  End of a long framing phase started with /lead (several back-and-forth exchanges).
  Before moving to a build phase, or before switching to a completely different effort.
  Do NOT confuse with /cloture-session (which closes the whole session, not just the framing).
allowed-tools: Task
argument-hint: "(optional: closing note, e.g. 'PRD draft ready, moving to build')"
---

You are executing a framing closure. Pattern R007 (see registers/rules.md).

## Steps

1. **Final synthesis from the active Lead**: try `SendMessage` to the last Lead sub-agent invoked in this session (agentId remembered from the last `/lead`). Ask it to:

   ```
   Final synthesis of the framing. Cover:
   - Decisions made (numbered list)
   - Deliverables produced (file paths)
   - Open items / deferred decisions
   - Recommended next step (build? more framing? stakeholder clarification?)
   - Update your agent-contexts/lead/MEMORY.md (workspace-specific) with the current state
   - If a cross-cutting learning is discovered: propose it for promotion (don't write it, just flag it)
   ```

2. **If no active Lead**: fallback. Start a fresh `/lead` with:

   ```
   No active Lead to close. The operator is closing a framing. Closing note: $ARGUMENTS
   Recap what you can read in the HANDOVER + workspace registers for a synthesis.
   ```

3. **Release routing**: after the Lead's synthesis, present it to the operator. Tell them:
   - "Framing closed. Future natural-language messages will no longer be routed via SendMessage to this Lead."
   - If a new framing is needed: they re-run `/lead`.
   - If moving to build: `/prompt-engineer prepare session 0`.

## Anti-patterns

- Closing a framing without requesting a synthesis (loss of capitalization).
- Confusing this with `/cloture-session` (which closes the WHOLE session, updates HANDOVER, MEMORY of all invoked agents, proposes promotions). `/cloture-cadrage` is lighter and focused on the Lead alone.

## Expected output

- Textual synthesis from the Lead presented to the operator
- agent-contexts/lead/MEMORY.md (workspace-specific) updated
- Note (optional) in the project/workspace HANDOVER if one is in progress

Mission: $ARGUMENTS
