# Complementary agents for lab {{LAB_NAME}}

This folder hosts agents SPECIFIC to this lab's domain — agents that do not exist in the Vibeforge parent method.

## Customization strategy

Vibeforge supports 3 strategies (cf. `{{VIBEFORGE_PATH}}/doctrine/04-agents.md` §"Per-lab customization strategies"):

**A — Complementary agents (RECOMMENDED)**
Add domain-specific agents without touching the generic ones.
- Benefit: zero drift, automatic inheritance of Vibeforge evolutions
- Example: `gdpr-checker.md`, `client-liaison.md`, `frontend.md`, `copywriter.md`

**B — Override (avoid except in exceptional cases)**
Rewrite a generic agent (same name). The lab REPLACES the parent's agent.
- Downside: guaranteed drift over time, heavy maintenance
- Use ONLY if context enrichment is not enough
- If you do it, mark it explicitly: `override_of:` field in the frontmatter + a comment

**C — Combination (typical real-world case)**
A mix of A + B. Typically 3-5 complementary agents + 0-1 override.

## Precedence (technical reminder)

When you launch `claude` from this lab, Claude Code looks for agents in this order:
1. `<this-lab>/.claude/agents/` ← priority 1
2. `~/.claude/agents/`
3. Vibeforge plugin ← priority 5

Any agent defined here WINS over the same-named agent in the parent.

## Format of complementary agents

Same rules as the generic agents (complete frontmatter + dense system prompt). See the generic agents in `{{VIBEFORGE_PATH}}/.claude/agents/` as a reference.

Each complementary agent must also have its own folder `<this-lab>/agent-contexts/<name>/` with SOUL, USER, MEMORY, journal, skills/INDEX.

## Recommended complementary agents for this domain

(To fill in when the lab is created — cf. the "pre-planned domains" table in doctrine/08-transposition.md)

| Agent | Role | Status |
|-------|------|--------|
| | | |

## Evolution

If a complementary agent becomes useful across several labs, it is a candidate for promotion to a generic Vibeforge agent. The traffic-controller can detect this pattern and propose it to you.
