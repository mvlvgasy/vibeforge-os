# BDR — {{PROJET_NAME}}

> **Business Decision Record** — committing strategic decisions made on this meta-project.
> Format: `## BDR-<NN> — <title>` then frontmatter + context + decision + consequences (cf. `<workspace>/registres/bdr.md` BDR01 for the canonical template).

## 🎯 When to activate this register?

**Empirically: most meta-projects do NOT produce a BDR locally.** Structuring decisions naturally bubble up to the lab or the parent method.

Activate this register only if this meta-project:
- **Makes its own committing decision** (e.g. "this project uses a DB schema different from the lab standard" + trade-off justification)
- **Decides to close an option** that will be hard to reopen (changing stack, dropping a major feature, pivoting the scope)
- **Explicit documented trade-off**: the decision changes the trajectory and has cross-session consequences

If these criteria are not met, **leaving this file empty is legitimate**. Promote via `/promote-decision-to-bdr` if a decision emerges.

> Promotion to the lab: if a project BDR is confirmed across several projects of the same lab → candidate for lab promotion via `traffic-controller`.
> Promotion to the global level: if the decision impacts ≥ 2 labs or the parent method → escalate to global.

---

(Empty — leave as-is unless a committing decision specific to this meta-project arises)
