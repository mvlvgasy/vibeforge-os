# Eval — {{PROJET_NAME}}

> **LLM hallucination/error patterns** detected on this meta-project.
> Format: `## E<NN> — <title>` then frontmatter + description + symptoms + prevention (cf. `<workspace>/registres/eval.md` E01 for the canonical template).

## 🎯 When to activate this register?

**Empirically: most meta-projects have NO domain-specific hallucination patterns.** LLM patterns bubble up to the parent method.

Activate this register only if this meta-project observes an LLM error pattern **specific to its domain**:
- **Reproducible pattern**: observed ≥ 2 times with a hypothesis about the cause (training bias, SDK fallback, context loss)
- **Domain-specific**: the pattern appears because of this project's specifics (ambiguous business terminology, little-known API, tricky data format)
- **Expressible prevention**: you can write an anti-pattern instruction in the bootstrap of the project's agents

If these criteria are not met, **leaving this file empty is legitimate**. Promote via `/promote-pattern-to-eval` if a pattern emerges.

> **Difference from a learning**: a learning explains HOW I resolved a blocker. An eval explains WHY the LLM fails in this way (meta-analysis).
> Candidate hallucinations automatically detected by the PostToolUse hook first land in `.claude/pending-eval.md` and are triaged in `/cloture-session`.

---

(Empty — leave as-is unless a domain-specific hallucination pattern arises in this meta-project)
