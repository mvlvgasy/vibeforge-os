# Projets-meta for lab {{LAB_NAME}}

This folder contains the META-PM NOTES of this lab's projects/work. **Not the project code** (which lives in `projets/` gitignored or in external repos).

## What to put here

Documents that drive the project on the meta-PM side, but that have no place in the project's code repo:

- `<work>-suivi.md`: general tracking of the work (state, planning, checkpoints)
- `<work>-stakeholder-meeting-YYYY-MM-DD.md`: stakeholder meeting notes
- `<work>-prd-draft-v0.X.md`: PRD drafts before they go into the code repo
- `<work>-handover-meta.md`: meta transitions between you and a potential successor
- Discovery notes, structured brainstorms, user feedback

## What NOT to put here

- The project source code (→ `projets/<work>/src/` or external repo)
- Finalized PRDs (→ `projets/<work>/docs/PRD.md`)
- Architectures (→ `projets/<work>/docs/architecture.md`)
- Build-session HANDOVERs (→ `projets/<work>/HANDOVER.md`)

## Sensitivity

This folder may contain stakeholder data (names, emails, internal decisions). It is versioned in the lab's Git BUT the lab is a PRIVATE repo. Not for public push nor for client repos.

If you have strictly confidential data → put it in `credentials/` (gitignored) or outside the repo.
