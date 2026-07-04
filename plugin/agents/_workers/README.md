# Workers — fleet of lightweight agents for Dynamic Workflows (DW)

> Answers the question: *"instead of spawning 100 lambda agents, can we have an army of purpose-built mini-agents?"* — **Yes. This is that folder.**

## The problem it solves

When an agent (lead, code-reviewer...) launches a **Dynamic Workflow** (the `Workflow` tool), `agent()` can spawn 3 types of sub-agents:

| Type | How | Bootstrap | Cost | When |
|------|---------|-----------|------|------|
| **Generic ("lambda")** | `agent("...")` without `agentType` | ~1-2k tokens | low | Pure mechanical task, zero domain context (read, count, extract) |
| **Full agent** | `agent("...", {agentType: 'plugin:architecte'})` | ~33k tokens (SOUL+USER+MEMORY+doctrine+rules) | high | Task requiring judgment + full domain/doctrine context. **Max 3-5 per run** |
| **Worker (this folder)** | `agent("...", {agentType: 'plugin:_workers:<name>'})` | ~5-8k tokens (minimal context inlined) | medium | **The scale sweet spot**: precise need + a bit of domain context, repeated N times |

**Golden rule of scale**: beyond ~3 parallel instances, a full agent (33k x N) blows up the token budget. The worker embeds ITS minimal context inline (a few hundred words) -> starts 4-6x lighter, and runs on a cheaper model (Sonnet/Haiku instead of Opus).

## Worker conventions

- **Does NOT bootstrap** `CLAUDE.md` / `rules.md` / SOUL/USER/MEMORY. All context is inlined in its `.md`.
- **Disposable and focused**: 1 worker = 1 precise need, launched in parallel by DW.
- **Model matched to the task**: Haiku for the mechanical, Sonnet for what requires judgment. Never Opus (reserved for full agents).
- **Read-only by default**: no Edit/Write/Task (they report, they do not mutate — except where documented).
- **Low maxTurns** (6-8): a worker that loops is a bug.

## Current fleet

| Worker | agentType | Model | Role | Used by |
|--------|-----------|--------|------|-------------|
| `module-reviewer` | `plugin:_workers:module-reviewer` | Sonnet 4.6 | Review of ONE module (bugs, security, conventions/GDPR) | `/mass-code-review` |
| `transcript-analyzer` | `plugin:_workers:transcript-analyzer` | Haiku 4.5 | Metrics of ONE .jsonl transcript (cost, tokens, compactions) | `/session-analyzer` |

## How does an orchestrator agent know what to call?

**No automatic discovery.** Two mechanisms:

1. **Skills (nominal case)**: the DW skills (`/mass-code-review`, etc.) have the `agentType` **hardcoded** in their script. The orchestrator has nothing to decide — it runs the skill, the author already picked the right worker.
2. **Ad-hoc DW**: if an agent improvises a workflow, it reads THIS README (the menu) to know which workers exist. That is why this file is the reference registry.

## Need a worker that is absent at the time of a DW run?

Two cases — **do NOT confuse them**:

### Case 1 — IMMEDIATE need (in the current DW run) -> INLINE pattern
A freshly created worker does NOT resolve in the current session (registration happens at startup, see Limits). For a "here and now" need, do NOT use a file: pass a **generic agent with a rich embedded prompt** (an "inline-defined worker"). It works immediately; it is just repeated on each call (prompt cost) and not reusable outside the run.

```javascript
const PROMPT = `You are a focused GDPR scanner. Look for names/emails/salaries in cleartext. Bootstrap nothing. Return {findings:[...]}.`
await parallel(files.map(f => () =>
  agent(`${PROMPT}\nFile: ${f}`, { model: 'haiku' })   // <- NO agentType: generic agent + rich prompt
))
```

### Case 2 — REUSABLE need (for later) -> `/forge-worker`
If the task will recur, forge a real worker: `/forge-worker <name> : <role>`. It creates the `.md`, updates this README, syncs the plugin. **Available at the next session start** (not before).

### Add a worker by hand
1. `agents/_workers/<name>.md` (lightweight, inlined context, read-only, cheap model).
2. A line in "Current fleet" above.
3. `scripts/sync-plugin.ps1` **+ restart Claude Code**.
4. Reference it in the DW skill that uses it.

## Known limits (verified empirically during a DW validation run)

1. **Registration = at session start.** Workers in a subfolder become `plugin:_workers:<name>`. BUT `sync-plugin` **mid-session is not enough**: the `agentType` registry is frozen at Claude Code startup. -> **Restart Claude Code** for `plugin:_workers:*` to resolve. Symptom if forgotten: `agent type 'plugin:_workers:X' not found. Available agents: ...` (without the worker).

2. **`args` does NOT bind to the inline DW script.** Passing `args: {...}` to the `Workflow` tool -> `args` arrives `undefined` in the script (verified across 2 runs). **Mandatory pattern**: write the data (lists, paths) **directly into the script** as JS literals. All `/mass-*` and `/parallel-cadrage` skills follow this pattern (no `args`).

3. **Pure metric extraction** (cost/tokens of a session): a generic agent grepping large `.jsonl` files produces **unreliable** numbers (LLM arithmetic over millions of tokens — a test run produced "$34 for 426 input tokens"). For `session-analyzer`, the worker must favor **deterministic** extraction (Bash/Select-String -> computation) over an LLM estimate. The DW engine itself is validated OK.

### Install reminder after adding a worker
`scripts/sync-plugin.ps1` (or commit -> git hook) **then restart Claude Code**.
