# Frame 4 — Agents

> .md files in `.claude/agents/` that define specialized roles.
> At the heart of Vibeforge operations.

## Definition

A Vibeforge agent is a specialized entity to which you delegate a type of task. It has:
- An identity (its own SOUL.md)
- Tools (tools, mcpServers)
- A persistent memory (memory: project + agent-contexts/)
- Attached skills
- Guardrails (maxTurns, permissionMode)
- Its own hooks

It is MUCH more than a text persona. It is a quasi-autonomous, framed agent.

## The Vibeforge V1 agents

| Agent | Role | Type | Model |
|-------|------|------|--------|
| `lead` | Orchestrator, never direct execution | Meta | Opus |
| `architecte` | Technical design, architecture, stack choices | Specialist | Opus |
| `ux` | User experience, design, journeys | Specialist | Opus |
| `strategie-contenu` | Content automation, marketing | Specialist | Sonnet |
| `business-analyst` | Business needs framing, functional analysis | Specialist | Opus |
| `prompt-engineer` | Preparation of Claude Code session prompts | Specialist | Opus |
| `reviewer-prd` | PRD coverage audit (materializes R001) | Validator | Sonnet |
| `traffic-controller` | Cross-lab consolidation | Meta | Sonnet |
| `skill-curator` | Validation of auto-created skills | Meta | Sonnet |
| `lab-architect` | New lab creation (orchestration) | Meta | Opus |
| `code-reviewer` | Pre-push code review (systematic phase 5) | Validator | Sonnet |
| `devil-advocate` | Structured critique of an artifact (4 sections) | Optional | Sonnet |
| **`dream-validator`** (R009 v2) | **Validates the MEMORY consolidation proposals (apply/reject/defer)** | **Meta** | **Sonnet** |

**MEMORY consolidation** runs via the `/dream` skill (target 2-3x/week) or via a nudge hook: Main Claude scans the journals + git log + current MEMORY files, identifies recurring patterns, and writes structured proposals in `agent-contexts/dreamer/pending-updates.md`. The **`dream-validator`** agent then filters them (apply/reject/defer) before `/dream` applies the validated ones. Strict MEMORY scope — never the registers.

## The "armed agent" pattern

Complete frontmatter (vs a bare persona agent that only has `name` + `description` + body):

```yaml
---
name: architecte
description: |
  Designs the technical architecture of a feature/project.
  Reads PRD + existing architecture + registers before proposing.
  To be invoked after a validated brainstorming, before prompt-engineer.
model: claude-opus-4-7
tools: Read, Grep, Glob, Task, Skill, Write(agent-contexts/architecte/**)
mcpServers: [notion, github]
disallowedTools: Edit, Bash(rm:*), Bash(git push:*)
memory: project
maxTurns: 20
permissionMode: default
skills:
  - superpowers:brainstorming
  - superpowers:writing-plans
  - vibeforge:promote-learning
hooks:
  Stop:
    - command: "powershell.exe -File hooks/architecte-stop.ps1"
color: green
---
```

### Critical fields

- **`tools`**: precise palette. NO default inheritance. Better to add than to forget to restrict.
- **`disallowedTools`**: security. No `rm`, no `git push`, no general `Bash` on non-technical agents.
- **`mcpServers`**: dedicated MCPs (Notion, GitHub, Slack...) — not loaded on every agent.
- **`memory: project`**: native Claude Code persistence v2.1.33+. Gives a folder at `~/.claude/agent-memory/<agent>/` cross-session.
- **`maxTurns`**: 5-30 depending on the role. Reviewer = 5, Architecte = 20, Lead = 30.
- **`permissionMode: default`**: asks for validation before sensitive actions. Not `bypassPermissions` except in extreme cases.
- **`skills`**: preloading. 2-4 fundamental skills. The others are invocable via the `Skill` tool.
- **`hooks`**: specific to the agent (Stop for capitalization, PreToolUse for logging, etc.).

## The "agent-contexts" pattern

Each agent has its own persistent "home":

```
agent-contexts/<name>/
├── SOUL.md             ← stable identity
├── USER.md             ← who the operator is (preferences)
├── MEMORY.md           ← current SYNTHESIZED state (≤200 words)
├── journal.md          ← chronological log of sessions (APPEND-ONLY)
├── skills/
│   ├── INDEX.md        ← table of auto-created skills
│   └── <topic>.md      ← skill validated by the curator
└── credentials.env     ← optional
```

The agent reads its context at bootstrap (see the system prompt of the foundational agents).

### The 4 memory mechanisms — explicit separation

Vibeforge uses **4 mechanisms** of memory that are COMPLEMENTARY (not redundant). Each has its role:

| Mechanism | Location | Role | Format | Discipline |
|-----------|--------------|------|--------|------------|
| **`memory: project`** (native Claude Code v2.1.33+) | `~/.claude/agent-memory/<agent>/` (outside the repo) | Cross-session AI optimization. Claude Code automatically decides what to put there. | Black box optimized for the AI | You don't touch it. Not in Git. |
| **`agent-contexts/_shared/MEMORY.md`** (R009 v2) | In the repo, versioned in Git | **Cross-agent cross-cutting patterns** (stack, paths, constraints). Loaded by ALL agents at bootstrap. | Markdown, max ≤300 words, fixed sections (cf. `_shared/README.md`) | Written only via `/dream` (the consolidation proposes, you validate). |
| **`agent-contexts/<name>/MEMORY.md`** (custom Vibeforge) | In the repo, versioned in Git | **Human-readable synthesis** of the agent's current state (agent-specific). For audit, debug, handover to another human (a future collaborator). | Markdown, max ≤200 words universal / ≤300 words lab, **REWRITTEN at each update** | Forced synthesis. Never append (except journal). Updated by the consolidation or the agent itself (lab only). |
| **`agent-contexts/<name>/journal.md`** (custom Vibeforge) | In the repo, versioned in Git | **Chronological history** of the agent's sessions. For traceability, forensics, pattern analysis + the consolidation's source. | Markdown, **APPEND-ONLY** (never rewritten) | One dated entry per session. Never rewrite the old ones. |

### Why the 3 and not just one?

- The native `memory: project` is **optimized by Anthropic** for the agent's performance. But it is a black box — you control nothing.
- `MEMORY.md` is **readable and auditable** by you. It lets you understand what the agent "thinks about its state" at a glance. It lets you hand the agent over to a third party (a future collaborator).
- `journal.md` is the **complete history** for forensics. When an incident happens, you can trace the thread back.

The 3 do not conflict because they have **different roles**:
- `memory: project` = internal agent performance (AI black box)
- `MEMORY.md` = present state visible (human audit)
- `journal.md` = past history (forensics)

### Typical workflow (capitalization at end of session)

At the end of each significant session:
1. The agent **APPENDS** a dated entry for the session in `journal.md` (chronological, as before)
2. The agent **NO LONGER REWRITES its MEMORY.md by default** (except in an exceptional case: critical ADR session, lab MEMORY only). The `/dream` consolidation proposes MEMORY updates 2-3x/week.
3. Claude Code updates the native `memory: project` automatically (not our job)
4. **`/dream` cadence**: invoked by you manually (target 2-3x/week) or via a nudge hook after ≥3 days without a dream

**Why externalize the consolidation**: when each agent is expected to rewrite its own MEMORY at every session, in practice almost none of them do → MEMORY freezes at bootstrap. Externalizing the consolidation to the `/dream` pass makes it reliable.

### Anti-patterns

- ❌ Appending to MEMORY.md (that's journal.md's role). If you append to it, it grows, becomes unreadable, and loses its synthesis role.
- ❌ Rewriting journal.md (loss of traceability)
- ❌ Putting PII in MEMORY.md or journal.md (they are in Git)
- ❌ Trusting ONLY `memory: project` for external handover (black box, non-transferable)
- ❌ Manually documenting what should go into `memory: project` (waste of time)

## The "contract" pattern between agents

When agent A invokes agent B (via the Task tool), it generates an ephemeral contract:

```markdown
# Mission contract — <target-agent>
## Issuer
<source-agent> (session <id>)

## Mission
<1-3 precise lines>

## Context
- Files to read: <list>
- Current state: <summary>

## Constraints
- <Explicit list>

## Expected deliverables
- <File 1>: <format>

## Success criteria
- <Measurable criterion>

## Escalation
If you cannot fulfill the contract, come back with a structured escalation report.
```

Advantages:
- The sub-agent knows exactly what is expected
- The success criterion is measurable (avoids drift)
- Escalation is framed (avoids infinite retry loops)

## The 3 orchestration modes

| Mode | Slash | Behavior |
|------|-------|--------------|
| Auto | `/lead-auto` | Lead chains without validating |
| Semi (default) | `/lead` | Lead proposes each delegation, waits for validation |
| Manual | (no slash) | You invoke each agent yourself |

Automatic detection of a switch to semi-auto if:
- The project contains "your client", "production", "GDPR", "employee data"
- Lead is going to modify files outside `agent-contexts/`
- Lead is going to make >5 cascading delegations
- Lead is approaching its maxTurns

## Customization strategies per lab

The 9 Vibeforge V1 agents are generic (they live in the root method). When you create a specialized lab, you have 3 strategies to adapt the agents' behavior to the lab's domain.

### Installing the Vibeforge plugin (prerequisite)

Vibeforge is packaged as a **Claude Code plugin** (`plugin/.claude-plugin/`). The agents/skills/hooks live under `plugin/` (plugin convention): `agents/`, `skills/`, `hooks/`.

**Install once per machine**:

```powershell
# 1. Register the marketplace
claude plugin marketplace add mvlvgasy/vibeforge-os

# 2. Install the plugin
claude plugin install vibeforge@vibeforge-marketplace
```

Verification: `claude plugin list | grep vibeforge` should show `vibeforge@vibeforge-marketplace ✔ enabled`.

**Consequence**: from any lab/project, the commands `/lead`, `/architecte`, `/ux`, etc. and the dispatch `Task(subagent_type="lead")` work without additional config. The method files are reachable via `${CLAUDE_PLUGIN_ROOT}`.

**Why**: `additionalDirectories` authorizes filesystem access but does NOT load plugins. Only `claude plugin install` registers the plugin in `~/.claude/plugins/installed_plugins.json` and triggers the loading of the agents/skills/hooks.

### Propagating changes

When you modify an agent (`agents/lead.md`), a skill (`skills/lead/SKILL.md`) or a hook (`hooks/post-tool-use.ps1`) in the local repo, the **Claude Code cache** (`~/.claude/plugins/cache/vibeforge-marketplace/vibeforge/X/`) does NOT update automatically.

**To propagate**:
- Manual: re-run `claude plugin install vibeforge@vibeforge-marketplace` (uninstall + reinstall)
- Auto via git hook (recommended): `pwsh scripts/install-git-hooks.ps1` once. The `post-commit` detects changes impacting the plugin and resyncs automatically.

### Claude Code precedence (technical reminder)

When you launch `claude` from a lab, Claude Code looks for agents in this order:

1. `<lab>/.claude/agents/` — lab agents (priority 1, override possible)
2. `~/.claude/agents/` — user agents
3. **Vibeforge plugin** (`~/.claude/plugins/cache/vibeforge-marketplace/vibeforge/X/agents/`) — generic agents

**Any agent defined in the lab WINS over the agent of the same name in the root method.** This is the mechanical basis for customization.

### Strategy A — Complementary agents (RECOMMENDED)

The lab ADDS agents specific to its domain. It does NOT OVERRIDE the generic ones.

Example `lab-client-acme/.claude/agents/`:
- `gdpr-checker.md` (new, specific to the client domain)
- `hr-liaison.md` (new)
- `payroll-specialist.md` (new)

The generic agents (lead, architecte, ux, BA, prompt-engineer, reviewer-prd, traffic-controller, skill-curator) stay in the root method, UNCHANGED. But at bootstrap they read the lab's context → their behavior adapts naturally.

**How the adaptation happens**: via the lab's files that the agents read automatically:
- `lab/CLAUDE.md` (the lab's operational rules)
- `lab/SOUL.md` (the lab's identity)
- `lab/contexte-domaine.md` (stack, GDPR, stakeholders, PRD format specific to the domain)
- `lab/registres/learnings.md` (the lab's learnings)
- `lab/registres/bdr.md` (the lab's BDR)

**Advantages**:
- Zero drift between the root method and the labs
- If the root method evolves, all labs benefit automatically
- Simple maintenance
- Compatible with promotion via traffic-controller

**Typical use cases**:
- Client domain lab: add gdpr-checker, hr-liaison, payroll-specialist
- Complex dev lab: add frontend, backend, devops, qa
- Content lab: add copywriter, video-editor, seo, community-manager
- Business lab: add accounting, prospecting, contracting

### Strategy B — Override (to avoid except in exceptional cases)

The lab REWRITES certain generic agents by creating a file `<lab>/.claude/agents/<same-name>.md` with a different system prompt.

**Major problem**: Claude Code does NOT "merge" the lab's override and the root method's agent. The lab's system prompt TOTALLY REPLACES that of the root method.

Consequences:
- You lose the doctrine bootstrap, the triggers, the patterns that the root method put in the agent
- You have to recopy ALL the useful content into the override
- The day the root method evolves (new rule, new doctrine, new pattern), the lab does not follow → DRIFT guaranteed in the long run
- Maintenance multiplied

**When to use it (rare cases)**:
- The generic agent is frankly unsuited to the domain AND enrichment by context is not enough
- The lab has radically different constraints that require a completely different workflow

**If you use B, mark it explicitly**: in the override's frontmatter, add an `override_of: ${CLAUDE_PLUGIN_ROOT}/agents/architecte.md` field and a comment explaining why.

### Strategy C — Combination (typical real case)

Most labs will combine:
- A: complementary agents added (new domain roles)
- B (rare): override of 0-1 generic agent only if truly necessary

This is the strategy expected by default. A lab like `lab-client-acme` will have 3-5 complementary agents and 0 override. A very specialized lab may need 1 override.

### How complementary agents should be armed

Same rules as the generic agents (cf. the "armed agent pattern" section above):
- Complete frontmatter (model, tools, mcpServers, memory, maxTurns, permissionMode, skills, hooks)
- Its own agent-contexts/<name>/ (SOUL, USER, MEMORY, journal, skills/INDEX)
- Dense system prompt with bootstrap + mission + workflow + anti-patterns + guardrails

The pattern is replicable. The skill-curator validates the skills auto-created by complementary agents just like for the generic ones.

## Native Claude Code limits

- **No nesting beyond 1 level**: a sub-agent CANNOT invoke another sub-agent via Task. To go deeper → Agent Teams (experimental).
- **No memory sharing between subagents**: each agent has its own memory. No "shared workspace" without an intermediary file.
- **Task only once per invocation**: you cannot spawn 10 subagents in parallel within the same Task call.

Strategy in the face of these limits:
- 1 level of depth (lead → specialist) is enough for 95% of cases
- Memory sharing via files (`contrat.md`, local registers)
- Multiple sequential Task calls for apparent parallelism

## Anti-patterns

- ❌ Agent without a restrictive `tools` → full palette by inheritance, weak security
- ❌ Agent without `maxTurns` → runaway loop vector
- ❌ Agent that codes AND orchestrates (the lead must DELEGATE, not execute)
- ❌ Too many agents (>15 for a solo project) → the user's core is diluted
- ❌ Agents with vague descriptions → Claude doesn't know when to delegate
- ❌ Agents that don't read their `agent-contexts/<name>/` at bootstrap → loss of cross-session memory
- ❌ Persona-only agent (just a text .md with no armed frontmatter) → you fall back onto the bare persona method, underused

## Agent invocation modes

Vibeforge supports 3 ways to invoke an agent. Each has its use case.

### 1. Slash skill wrapper (automatic dispatch)
**Example**: `/lead find sources on X`, `/architecte frame the stack of this project`

The slash invokes the corresponding wrapper skill which **dispatches** the sub-agent via the Task tool. The sub-agent has its own isolated context (system prompt from `.claude/agents/<name>.md` + autonomous bootstrap). Its response comes back into the main conversation.

**Consequence**: each `/lead` call = fresh sub-agent. **No identity confusion** if you use several over the course of a session.

### 2. Natural language (implicit dispatch)
**Example**: *"Lead, dispatch a /cherche-sources then synthesize"*, *"Architecte, propose a stack for this project"*

The main agent interprets the natural language and does the Task dispatch itself. More conversational but requires the main agent to already be aware that there are sub-agents available (reading CLAUDE.md, doctrine, etc.).

### 3. Direct slash agent (rare)
**Example**: `/architecte` then wait for the agent to ask for a mission

Starts the sub-agent without a predefined mission. Useful for interactive exploration.

### Usage recommendation

| Situation | Convention |
|-----------|-----------|
| First interaction of the session, new project | `/lead <complex request>` |
| You want to orchestrate multiple steps | Natural language with Lead |
| You know which technical skill you want | `/cherche-sources X`, `/new-lab Y` |
| You want to dispatch a precise sub-agent | `/architecte <mission>` or natural language |
| **You re-invoke the agent in the middle of a session** | Slash agent (`/lead X`) — each call = fresh isolated sub-agent |

### Anti-pattern resolved

Before the wrapper refactor: the slashes `/lead`, `/architecte`, etc. reloaded the agent's system prompt **into the main context** instead of dispatching a sub-agent. This created an identity confusion when the user retyped a slash agent during a session — the second user prompt was ignored or misinterpreted.

**The fix**: all the wrappers `.claude/skills/<agent>/SKILL.md` now use `allowed-tools: Task` and invoke the sub-agent via the Task tool. Each call = fresh sub-agent with isolated context.

### Continuous conversation with a sub-agent via SendMessage (native Claude Code)

**Correction of an earlier assertion**: we initially thought that a sub-agent "dies" after its synthesis. That's false. It becomes **dormant**, its context is preserved, and the main Claude can **wake it up** via `SendMessage(agentId)`.

Mechanism:

```
/lead I want to frame an HR Onboarding (1st turn)
   ↓
Main Claude dispatches Task(subagent_type="lead", ...)
   → receives agentId = "a2d04f7..." (id of the dormant sub-agent)
   → Lead boots, reflects, responds
   → Main Claude presents the synthesis to the user

The user types a follow-up in NL: "add a GDPR constraint"
   ↓
Main Claude MUST route via SendMessage(agentId="a2d04f7...", prompt="add...")
   (cf. R007 in registres/rules.md)
   → The SAME Lead wakes up, keeps its context, responds
   → Main Claude presents the 2nd response

While the main Claude is in the same session:
   - The agentId stays valid
   - The sub-agent stays wakeable
   - Its intra-session memory is preserved

When the main session is compacted OR closed:
   - The agentId is invalidated
   - For a new framing: redo /lead (full boot, new agentId)
```

**Key**: R007 (doctrine 06-rules) requires the main Claude to route via SendMessage instead of responding itself. Without this rule, the main Claude "imitates the Lead" without having its guardrails/memory/identity.

### Inter-session memory (hybrid agent-contexts)

Sub-agents preserve their **intra-session** context via SendMessage. For **inter-session** memory (the Lead "remembers" yesterday's framing at the next `/lead`), it is `agent-contexts/lead/MEMORY.md` that serves.

**Hybrid pattern**:

| Level | Path | Content |
|---|---|---|
| **Global** (root method) | `<workspace>/agent-contexts/lead/MEMORY.md` | Cross-cutting acquired knowledge: Vibeforge versions, architectural decisions, meta-patterns |
| **Lab-specific** | `<lab>/agent-contexts/lead/MEMORY.md` | State of the lab's projects: ongoing projects, active blockers, last session |

At bootstrap, the Lead reads **both** (global first, then lab if present). It writes to the **lab-specific** one by default. Promotion to global = via `traffic-controller` when an acquired piece of knowledge becomes cross-cutting.

Advantage: the Lead stays globally coherent AND retains the specifics of each lab. No duplication, no drift.

### "Natural language": what actually happens

When you respond in natural language after a sub-agent's response, **it is not the sub-agent that responds**: it is the main Claude that has its synthesis in context and continues the conversation by imitating it.

| Description | Status |
|---|---|
| "You continue naturally with Lead" | ✅ True from the user's point of view |
| "It's the main Claude that responds to you, with the Lead synthesis in context" | ✅ True technically |
| "The Lead sub-agent is still active" | ❌ False — it died after its synthesis |

The two true descriptions are **two angles of the same mechanism**. For the user it's fluid; in reality the main Claude plays the proxy.

### Choosing the right mode according to the need

The official Vibeforge pattern for ALL cases, including long framings:

| Need | Recommended mode | Why |
|---|---|---|
| New strategic framing (1st message of the session) | `/lead <context-rich request>` | Fresh Lead sub-agent, re-bootstrap doctrine, real Lead reasoning |
| Adjustment, clarification, continuation of the conv | **Natural language** (no slash) | Main Claude has the Lead synthesis in context, continues coherently |
| Delegation to a precise specialist (architecte, ux, etc.) | `/architecte <request>` or *"run the ux agent on X"* | Isolated specialist sub-agent, own context |
| Re-wake the Lead fresh (change of project, polluted conv) | `/lead <new framing + context reminder if needed>` | Full re-boot of the Lead sub-agent |

**Pattern Option 1 (official)** — project framing with several exchanges:

```
Turn 1  → /lead I want to frame an HR Onboarding with strict GDPR constraints
          [Lead boots → delegates to BA, UX, GDPR-checker → synthesis]

Turn 2  → add a budget constraint < 3000€
          [Main Claude continues with Lead context — no /lead]

Turn 3  → run reviewer-prd now
          [Main Claude dispatches reviewer-prd via the Task tool]

Turn 4  → /lead let's switch: new project Overtime v2, keep the HR context
          [New /lead = new explicit framing]
```

This is **exactly the native Claude Code pattern**: no one retypes `/architect` at each message. You invoke the agent at the start of a framing, you continue in NL, you only re-type when you change project or want fresh reasoning.

### Anti-pattern: Lead-as-root

❌ **NEVER put the Lead instructions in the lab's `CLAUDE.md`** ("Lead-as-root").

This is exactly the pattern that caused the **double identity** bug. The Lead instructions were injected into the main context, so:
- At session start: the main Claude "became" Lead
- If the user typed `/lead` afterward: re-injection of the same instructions → confusion, second user prompt ignored

**Consequence**: Vibeforge **does not support** the Lead-as-root pattern. Lead is **always** a sub-agent dispatched via the Task tool (by the `/lead` skill wrapper, or by an NL mention "Lead, do X").

If you want a "continuous conv" with Lead over several turns, **use Option 1 above**: a rich `/lead` at the start, then natural language. The main Claude plays the proxy with the Lead synthesis in context — it's fluid enough for real usage.

### Acknowledged limitation

The current pattern does NOT give a "true continuous conv" with a sub-agent (each `/lead` = fresh sub-agent with no memory of the previous invocation). This is **a conscious trade-off**:
- ✅ No double identity possible
- ✅ Isolated context (token savings)
- ✅ Composable (`/lead`, `/architecte`, `/lead` in any order)
- ❌ No conversational memory between `/lead` calls (compensated by `agent-contexts/lead/MEMORY.md` which persists between sessions)

## See also

- Frame 5: Skills (competencies attached to agents)
- Frame 10: Self-improvement (agents can create their own skills)
- Official Claude Code doc: [Subagents](https://code.claude.com/docs/en/sub-agents)
