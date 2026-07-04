# Frame 6 — Rules

> Non-negotiable cross-cutting rules, promoted up from learnings via consolidation.

## Definition

A rule is a learning that has been **validated by recurrence** and **crystallized** as a constraint applied systematically. It is READ by all agents at bootstrap and respected without debate.

## Location

| Level | File | Scope |
|-------|------|-------|
| Global | `vibeforge/registers/rules.md` | Cross-project, post-promotion |
| Lab | `<lab>/rules.md` | Domain-specific |
| Project | `<project>/.claude/rules/00-XX.md` | Project-specific, numbered |

## Numbered pattern for project rules

```
.claude/rules/
├── 00-project-context.md       project context (always read first)
├── 01-stack-locked.md          locked technical stack
├── 02-security-defaults.md     security rules
├── 03-<domain-pattern>.md      domain-specific pattern
├── 04-async-pattern.md         async programming rules
├── 05-llm-tone.md              tone/style of LLM outputs
├── 06-testing.md               testing rules
└── 07-pr-review.md             PR workflow
```

The number indicates the reading order (priority). 00 = mandatory context, 99 = optional rules.

## Lifecycle of a rule

```
Local learning (lab/project)
     │
     │ recurrence ≥2 projects + stability ≥30 days + user validation
     │ (via traffic-controller)
     ▼
Global learning (vibeforge/registers/learnings.md)
     │
     │ even more stable + non-negotiable + user validation
     │ (via traffic-controller)
     ▼
Global rule (vibeforge/registers/rules.md)
     │
     │ mandatory application by all agents
     │ read at bootstrap
     ▼
If contradicted by a new learning OR not read for 180 days
     │
     │ (via traffic-controller)
     ▼
Demotion: back to learning OR deprecated OR modified
```

## Format of a rule

```markdown
## R<NN> — <short title>

```yaml
---
id: R<NN>
type: rule
created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
severity: <low|medium|high|critical>
domain: <domain>
related: [<related>]
promoted_from: [<source path 1>, <source path 2>]
status: active
---
```

### Rule
<generic formulation, applicable to all projects>

### Why
<2-3 lines of justification, examples>

### How to apply
- <Point 1>
- <Point 2>

### Limits / counter-examples
<if applicable>

### Anti-patterns to avoid
- ❌ ...

### See also
- <related decision-record path if applicable>
- <source learning path>
```

## The first Vibeforge rule: R001

**R001 — PRD coverage before a build session** (resulting from a real incident).

Before any build session prompt, RE-READ in full:
1. PRD
2. Architecture
3. Architecture addendum
4. Shadowing transcripts
5. HANDOVER

And have the coverage validated by `reviewer-prd` BEFORE launching the session.

This rule was born from a real, costly incident. It is exemplary of how Vibeforge turns a painful experience into a systemic safeguard.

## Mandatory reading of rules

All agents read `vibeforge/registers/rules.md` at bootstrap. They know these rules are NOT negotiable except by explicit override from the operator (which must then be traced).

## Contradiction between a rule and a new learning

If an agent encounters a learning that contradicts an existing rule:
1. It does **NOT ignore** the rule for that reason
2. It flags the conflict to the lead
3. The lead invokes traffic-controller
4. Traffic-controller analyzes, proposes to the operator:
   - (a) Keep the rule, the learning is invalid / specific
   - (b) Modify the rule to integrate the learning's case
   - (c) Demote the rule to a learning (the condition has changed)
5. The operator decides, traffic-controller applies

## Anti-patterns

- ❌ Rules that contradict each other → traffic-controller must detect and flag
- ❌ Rules too specific (mention a project name, a lib v3 while we're on v4) → reformulate as generic at promotion time
- ❌ Rules without a clear `why` → permanent debate when an agent wants to bypass them
- ❌ Dormant rules (not read for 180 days) → traffic-controller proposes demotion
- ❌ Too many global rules (>30) → the agent saturates, ignores the least critical ones

## See also

- Frame 2: Registers (rules live in `rules.md`)
- Frame 3: Consolidation (the promotion that creates the rules)
- Frame 9: Traffic (the agent that orchestrates promotions/demotions)
