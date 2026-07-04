# Frame 3 — Consolidation

> A periodic process that maintains register quality: archives, merges, promotes, reindexes.

## Definition

Without consolidation, registers become a dumping ground: duplicates, obsolete entries, learnings never promoted to rules. Consolidation is the semantic garbage collection of Vibeforge.

## The 4 operations

### 1. Archive
- Obsolete entries (e.g. a blocker resolved 6 months ago without reappearing)
- Format: move to an `## Archives` section at the bottom of the file, OR mark `status: archived` in the frontmatter
- Criterion: not read/cited for 180 days OR explicitly marked obsolete by the operator

### 2. Merge
- 3 similar blockers → 1 single blocker with multiple occurrences
- 2 learnings that say the same thing → 1 consolidated learning
- Format: new block, old ones marked `[merged-into <ID>]`
- Criterion: > 70% semantic overlap

### 3. Promote
- Local learning → global learning (via traffic-controller, Frame 9)
- Global learning → global rule (when recurrent + stable)
- Local BDR → global BDR (if cross-cutting)
- Eval pattern → preventive rule (if detected early enough)
- Format: copy in a generic form, mark the source `[promoted]`, new entry in the target
- Criterion: recurrence ≥2 projects + stability ≥30 days + user validation

### 4. Reindex
- Update the INDEX at the top of each register
- Update the counters
- Check the integrity of cross-register references (related: [...])
- Format: automatic via the `/cloture-session` skill or manual

## When to consolidate

### Trigger 1: `/cloture-session` skill (manual)
Invoked at the end of a session by the operator or by the lead. Explicit audit:
- [ ] Local registers up to date (journal at minimum)
- [ ] Resolved blockers marked as such
- [ ] New learnings captured
- [ ] Candidate promotions listed for the traffic-controller
- [ ] Auto-created skills validated by the curator
- [ ] HANDOVER written for the next session

### Trigger 2: `SessionEnd` hook (automatic)
If `/cloture-session` was not invoked and the session ends, the hook forces a quick check:
- Append the session journal
- Detect uncaptured blockers (from the session's errors)
- Propose to the operator to run a full `/cloture-session` at the next session

### Trigger 3: Traffic Controller (periodic)
Bi-weekly by default. Global scan, proposes promotions. See Frame 9.

### Trigger 4: Manual on demand
The operator can invoke `/cloture-session full` or `/traffic-controller scan all` whenever they want.

## The promotion chain (central mechanism)

```
[Local Project]                    [Local Lab]                    [Global Vibeforge]
                                                                  
blockers.md (B042)                                                
    │ resolved                                                    
    ▼                                                             
learnings.md (L007)  ─── recurrent ──>  learnings.md (L007-global)  ─── stable ───>  rules.md (R<NN>)
    │ promoted=true                          │ promoted=true                              │
    │                                        │                                            │
    └─ marked [promoted]                     └─ marked [promoted]                          └─ canonical
```

Rule: **a promoted element stays in the source** (marked `[promoted]` for traceability), but the canonical version lives in the target. If the source disappears (project archived), the canonical one survives.

## Format of a `/cloture-session` call

```markdown
# Session close — <YYYY-MM-DD HH:mm>

## Session
- Lab/project: <path>
- Agents involved: <list>
- Duration: <minutes>
- Initial request: <summary>

## Capitalization
### Blockers detected
- [B<NN>]: <description> → <status: open/resolved>

### Learnings detected
- [L<NN>]: <description> → <added locally: yes/no>

### BDRs taken
- [BDR<NN>]: <description> → <added locally: yes/no>

### Eval patterns observed
- [E<NN>]: <description> → <added locally: yes/no>

## Candidate promotions (to submit to the traffic-controller)
- [L<NN> local] → candidate global learning (reason: also seen in <other project>)

## HANDOVER for the next session
- State: <summary>
- Next action: <concrete>
- Possible blockers: <if applicable>

## Documentation debt audit
- [ ] All local registers updated
- [ ] HANDOVER written
- [ ] Auto-created skills validated by the curator (if applicable)
- [ ] No forgotten TODO in the code
```

## Anti-patterns

- ❌ Consolidation never done → registers rot within 6 months
- ❌ Consolidation done but without user validation → promotions too fast or wrong
- ❌ Promotion without a generic phrasing → the global rule stays contaminated by the project context
- ❌ Deleting the source after promotion → loss of traceability
- ❌ Reindexing without checking cross-register references → broken links

## See also

- Frame 2: Registers (what gets consolidated)
- Frame 7: Capitalization (overall view of the close process)
- Frame 9: Traffic (automated cross-lab consolidation)
