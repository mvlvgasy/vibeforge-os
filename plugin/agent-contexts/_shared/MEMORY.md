# Shared MEMORY — Vibeforge cross-agent

> Loaded by ALL agents at bootstrap. ≤300 words total (HARD).
> Updated exclusively via `/dream` (consolidation pass + validation).
> Full convention: `_shared/README.md`.

## Shared technical stack
- Claude Code: recent version required (native SendMessage, plugin marketplace)
- Vibeforge scripts: target PowerShell 5.1 (default Windows compatibility)

## Path conventions
- Workspace root: `<workspace>/`
- Labs: `<workspace>/lab-<name>/` with `.vibeforge/category.txt`
- Meta-project: `<lab>/projets-meta/<project>/`
- Deliverable: `<workspace>/projets/<category>/<project>/`
- Active plugin: `${CLAUDE_PLUGIN_ROOT}` resolves to the Claude Code plugin cache

## Cross-agent orchestration patterns
- Lead = the single orchestration path (R1). Specialist agents invoked via the Task tool.
- Typical order: business-analyst -> ux + architecte -> reviewer-prd (R001) -> prompt-engineer -> build -> code-reviewer
- devil-advocate optional on critical stakes (R10), proposed never auto-invoked

## Cross-cutting anti-patterns
- No direct Write into `_shared/MEMORY.md` (always via the consolidation pass + validation)
- No build session without validated PRD coverage (R001)
- No auto-created skill without skill-curator (R6)
- No secrets in registers or agent-contexts (R3)

## Meta
- Doctrine: 14 frames (see DOCTRINE.md)
