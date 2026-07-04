# Frame 9 — Traffic

> Automated cross-lab consolidation.

## Definition

Traffic is the orchestration of knowledge circulation between levels (project → lab → global). It is what turns Vibeforge from a collection of isolated registers into a **living system that learns**.

Without Traffic, each lab/project learns on its own and the root method stays static. With Traffic, what works everywhere becomes the norm everywhere.

## Mechanism: the `traffic-controller` agent

See `agents/traffic-controller.md` for the full spec.

Role:
1. **Scan** the local registers of labs/projects
2. **Detect** recurring patterns (≥2 distinct projects with a similar resolution)
3. **Propose** promotions/demotions to the operator
4. **Apply** validated decisions
5. **Journal** in `vibeforge/registers/traffic-journal.md`

## The traffic flows

### Upward flow (promotion)

```
[Project A] learnings.md L01 ─┐
                              │ similar (>70% overlap)
[Project B] learnings.md L01 ─┤
                              │ stable ≥30 days
                              │ user validation
                              ▼
                      [Global] rules.md R<NN>
```

### Downward flow (application)

Global rules are automatically read by agents at bootstrap. No need to "push" — it is pulled by the agent.

### Lateral flow (consultation)

An agent in project A can consult `lab-B/registers/learnings.md` via Read (absolute relative paths), if it has Read authorized on that path. This is rare but possible for cross-reference cases (typically when a project draws inspiration from a project already done in the same lab).

### Demotion flow

```
[Global] rules.md R<NN>
    │
    │ not read for 180 days OR contradicted by a new learning
    │ (detected by traffic-controller)
    │
    ▼
[Global] learnings.md L<NN> (back to learning, marked `demoted_from: R<NN>`)
    │
    │ OR
    ▼
deprecated (status: deprecated in frontmatter)
```

## Scan frequency

### Default
Bi-weekly, Monday 9am, even weeks.

Configured via skill `/schedule`:
```bash
/schedule create "0 9 * * 1#2" "/traffic-controller scan all"
```

### Adjustment
- If 0 promotions over 3 consecutive scans → traffic-controller proposes spacing it out (monthly)
- If >5 promotions per scan → traffic-controller proposes tightening (weekly)

### On demand
The operator can invoke `/traffic-controller scan all` or `/traffic-controller scan lab=client-acme` at any time.

## Quantitative indicators (reminder)

### Promotion learning → rule
- Recurrence ≥2 distinct projects
- Similar resolution (≥70% semantic overlap)
- Stability ≥30 days
- User validation

### Promotion local decision-record → global decision-record
- Transversality (impacts ≥2 predictable future projects)
- Tag `severity: critical` or explicit "cross-cutting"

### Promotion eval pattern → preventive rule
- Recurrence ≥2 projects or ≥3 times in the same project
- Tag `severity: high` or `critical`

### Demotion of a rule
- Not read for 180 days
- Contradicted by a new learning
- Marked obsolete manually by the operator

## Format of proposals

The traffic-controller produces structured reports (see `agents/traffic-controller.md`). The operator validates entry by entry OR with an explicit "approve all" command.

## Safeguards

- Traffic-controller NEVER decides alone (R-traffic-1)
- Does not promote a learning < 30 days old (R-traffic-2)
- ALWAYS reformulates as generic (no names, no client-specific IDs) (R-traffic-3)
- Marks the source `[promoted]` but never deletes it (R-traffic-4)
- Limit: max 10 promotions proposed per scan (to avoid drowning the operator)

## Anti-patterns

- ❌ Promoting a single learning (seen in only 1 project) → false signal
- ❌ Promoting too fast (without 30 days of stability) → volatile rule
- ❌ Promoting a project-specific formulation → contaminates the root method
- ❌ Erasing the source after promotion → loss of traceability
- ❌ Ignoring the decision journal → past rejections get re-proposed in a loop
- ❌ Cron too frequent (daily) → noise, false positives

## Why automate this

Manual consolidation works when you have 2-3 labs and an active memory. It does not scale when you have 5+ labs and work on several in parallel.

Vibeforge automates this detection but keeps the human decision. It is the "scalability without loss of control" trade-off.

## See also

- Agent: `.claude/agents/traffic-controller.md`
- Register: `registers/traffic-journal.md`
- Frame 3: Consolidation (traffic is a case of cross-lab consolidation)
