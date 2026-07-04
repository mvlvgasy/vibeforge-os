# Frame 10 — Self-improvement

> The ability of each agent to write its own skills from its experiences.

## 📊 Empirical status (doctrine audit) — DECISION: KEEP

**Observation**: **0 `skill-curator` invocations in 6 months** across 7 skills created. All written by the operator during root-method development (auditable via git diff, out of R6 scope — see CLAUDE.md R6 + `audits/r6-skill-curator.md`).

**Arbitration (consistent with decision-record BDR02 Path A)**: **we KEEP the frame, we do NOT simplify it.** Reasons:
1. R6 protects a **real future scenario** (a Vibeforge sub-agent on an autonomous mission that identifies a missing skill) — one that simply has not happened yet, not an invalid scenario.
2. The maintenance cost is zero (the mechanism lies dormant without getting in the way).
3. When Dynamic Workflows / autonomous agents scale up, this frame will become active.

**Re-evaluation condition**: if in 6 months there are still 0 invocations DESPITE active autonomous agents on missions → re-arbitrate (simplify or remove the constraint). Measured via `/metrics-report` (counters `skill_invoked` + `agent_delegated`).

## Definition

Self-improvement allows an agent to **turn a successful experience into a reusable skill**. It is what makes Vibeforge non-static: the method enriches itself over the course of usage, agent by agent.

Inspired by autonomous skill self-improvement patterns, but framed by our `skill-curator` to avoid spam.

## Validated workflow

```
Agent X solves a complex problem
   │
   │ identifies a reusable pattern (at least 2 occurrences seen)
   ▼
Checks the INDEX of existing skills
   │
   │ no strict duplicate
   ▼
Prepares a draft SKILL.md (without writing it yet)
   │
   ▼
Invokes skill-curator via Task tool
   │ with: name, draft, requesting agent, context
   ▼
Curator analyzes (5 checks)
   │
   ▼
[APPROVE]  ──> operator validation ──> curator writes ──> update INDEX
[MERGE]    ──> modify existing skill ──> operator validation ──> Edit
[REVISE]   ──> back to the agent with comments ──> agent reworks
[REJECT]   ──> reason + alternative ──> agent does not write
```

## The 5 skill-curator checks (reminder)

1. **Strict duplicate**: exact name already exists? → REJECT
2. **Semantic overlap**: overlap >70%? → MERGE proposed
3. **Granularity**: too broad or too narrow? → REJECT/REVISE
4. **Standard Anthropic Agent Skills format**: frontmatter + sections? → REVISE if incomplete
5. **Vibeforge relevance**: cross-cutting / agent-specific / project-specific-reject

## Where auto-created skills land

### Cross-cutting skill (usable cross-project)
Target: `vibeforge/.claude/skills/<name>/SKILL.md`
Available to all labs/projects.

### Skill specific to an agent
Target: `agent-contexts/<agent>/skills/<name>.md`
Internal use, available only to that agent.

### Project-specific skill
**Refused**. The curator proposes storing it as a local learning instead.

## Anti-spam

- The curator is MANDATORY (impossible to bypass via permissions)
- The requesting agent CANNOT write directly into `.claude/skills/` or `agent-contexts/<other>/skills/`
- An agent that has 3+ consecutive drafts refused is flagged to the operator (problem on the requesting agent's side?)
- The INDEX is maintained by the curator, never directly by the agents
- Operator validation mandatory before final writing

## Expected typical cases of auto-created skills

(Hypotheses to be confirmed by usage)

### For the `lead`
- `cadrage-client-domain`: scoping pattern specific to a client domain
- `delegation-multi-specialists`: orchestration pattern for tasks that require 3+ agents

### For the `architecte`
- `deploy-vercel-bolt-receiver`: recurring Slack Bolt on Vercel pattern
- `rag-3-layers-pattern`: RAG pattern (knowledge + vectors + web)

### For the `prompt-engineer`
- `prompt-sensitive-session-pattern`: prompt pattern for sensitive sessions (post-incident)
- `handover-format-pattern`: expected structure of a HANDOVER

### For the `reviewer-prd`
- `audit-coverage-pattern`: standard PRD coverage audit grid

### For the `business-analyst`
- `discovery-stakeholder-pattern`: stakeholder interview pattern (HR director, managers)

## The moment of self-creation

An agent should NOT auto-create a skill:
- For every task (spam)
- For trivial patterns (already covered by learnings or rules)
- For project-specific patterns (store as a learning instead)

An agent SHOULD auto-create a skill when:
- It has applied the same pattern in 2+ different projects
- The pattern is complex (>5 steps) and requires rigor (so there is a gain in not rewriting it each time)
- The pattern is cross-cutting (at least 2 agents could use it, or at least 2 different contexts)
- The operator has explicitly said "you can make this a skill" or similar

## Anti-patterns

- ❌ Self-creation without curator → spam and redundancy
- ❌ Curator that rubber-stamps everything → the base degrades
- ❌ Auto-created skills too similar (different agents propose close things) → merge proposed by curator
- ❌ Auto-created skills that duplicate existing Superpowers → curator refuses, proposes invoking Superpowers instead
- ❌ "Speculative" auto-created skills (the agent imagines it might be useful) → refuse, ask for proof of recurring usage

## Expected evolution

- **0-3 months (V0.x)**: few self-creations, the system is breaking in. The operator intervenes a lot in validations.
- **3-12 months (V1.x)**: agents have calibrated their criteria. 1-3 auto-created skills per month on average. Fast operator validation.
- **>12 months (V2.x)**: mature base, few additions. Most new skills come from specific needs of new labs (transposition).

## See also

- Agent: `.claude/agents/skill-curator.md`
- Frame 5: Skills (where auto-created skills live)
- Inspiring pattern: autonomous agents that author their own reusable skills
