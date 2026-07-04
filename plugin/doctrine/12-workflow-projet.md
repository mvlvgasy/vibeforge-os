# Frame 12 — Project workflow (framing → dev → prod)

> How to go from an idea to a feature in prod via Vibeforge.
> Who talks to whom, who validates what, where the code is written, where the method is written.

## Guiding principle — a single session, cwd = LAB

All phases of a project (framing, build sessions S0→Sn, capitalization) take place in **a single Claude Code session** whose `cwd` is the **parent lab**:

```
session cwd = <workspace>/<lab>/
```

The lab has a `.claude/settings.local.json` that declares at minimum:

```json
{
  "additionalDirectories": [
    "../vibeforge",                  // root method (doctrine reading, global registers)
    "../projets"                     // root of all deliverables (all categories)
  ]
}
```

**Why cwd = lab (and NOT meta-project)**:
- You automatically benefit from `<lab>/CLAUDE.md`, `<lab>/SOUL.md`, `<lab>/contexte-domaine.md`, and the `R-<lab>-X` rules
- The **lab-specific agents** are loaded (e.g. a domain-research agent + a domain-analyst agent for a research lab)
- The **lab-specific skills** are available (`/cherche-sources`, `/analyse-source`, etc.)
- The **local registers** of the lab are readable
- **You stay in the same conversation** from framing through to push — no cwd change, no re-bootstrap

**The meta-project is a subfolder of the lab** (`<lab>/projets-meta/<project>/`) that serves as a container for the project's method files (PRD, HANDOVER, the project's local registers, session prompts). You access it via a relative path from the lab (`./projets-meta/<project>/PRD.md`, etc.) — it does not need to be a cwd.

**The deliverable is external to the lab** (`<workspace>/projets/<category>/<project>/`). Pushable as-is to the client repo with no pollution. You access it via a relative path from the lab (`../projets/<category>/<project>/src/...`).

**"Current project"**: memorized by the lead in `<lab>/agent-contexts/lead/MEMORY.md` (the "Current project: <name>" field). At the start of a session, the lead reads this field and knows what we are continuing on. To switch the current project: "let's switch to <other-project>" → the lead updates MEMORY.

## The 6 phases

### Phase 0 — Project creation (1 min) — often **detected automatically** by the lead/main lab Claude

If you talk about a new initiative in a lab conversation ("I want to do X", "build Y", "new project Z"), Claude detects the trigger and **proposes the pre-filled command** (see the "New project detection" section in `<lab>/CLAUDE.md`). You validate, and the project is created without changing session.

Otherwise, manually from any terminal:
```powershell
pwsh <workspace>/vibeforge/scripts/new-projet.ps1 `
    -Name acme-app-v2 -AffiliatedLab lab-client-acme -GitInit
```

Creates:
- `<lab>/projets-meta/acme-app-v2/`: meta container (CLAUDE.md, HANDOVER, empty PRD, docs/, registers/, .claude/settings.local.json — the latter is no longer the canonical cwd but remains useful in fallback mode)
- `<workspace>/projets/<category>/acme-app-v2/`: deliverable (README, .gitignore, optional git init)

### Phase 1 — Framing (variable duration) — in the current lab conversation

**You are already in the lab conversation** (cwd = `<lab>/`). No need to change cwd. You invoke (if not already done):
```
/lead I want to rebuild acme-app. Needs: [...]. Stakeholders: a sponsor on the business side, a collaborator validates the stack.
```

If the project was just created via auto-detection, **the lead proceeds directly** to framing without a new invocation. It updates `<lab>/agent-contexts/lead/MEMORY.md` field "Current project: acme-app-v2".

**Lead** bootstraps (reads global + lab + project), proposes an orchestration plan, asks for your validation (`/lead` semi-auto mode by default). In `/lead-auto` mode, it proceeds without validating.

**Lead dispatches, in order**:

| Agent | Produces | Output |
|---|---|---|
| `business-analyst` | Interactive discovery (15-30 questions) + business need section | `docs/PRD.md` (first draft) |
| `ux` | User journey, ASCII wireframes, friction points | `docs/parcours.md` |
| `compliance-checker` (lab-specific agents) | Data compliance audit | `docs/compliance-audit.md` |
| `stakeholder-liaison` (lab-specific agents) | Formal note for the stakeholder (expected document format) | `docs/comm-stakeholder.md` |
| `domain-specialist` (lab-specific agents, if applicable) | Domain integration section in the architecture (APIs, limits) | `docs/architecture.md` (domain section) |
| `architecte` | Full technical stack, data schema, integrations, secrets | `docs/architecture.md` (complete) |

**Throughout this framing**: you speak in **natural language** ("add a budget constraint", "no, that role is different"). R007 guarantees that these follow-ups reach the **same** Lead via `SendMessage(agentId)`. No need to re-`/lead`.

#### During this Phase 1 — Agent delivery architecture MANDATORY

If the project has an **AI agent component** (almost always the case in 2026+), the `business-analyst` + `architecte` MUST apply **Frame 14** (`doctrine/14-architecture-livraison-agent.md`):

1. **BA discovery**: ask the 5 criteria questions (cost-of-failure, dev speed, vendor lock-in, ongoing costs, data sovereignty) — see Frame 14 § Application in Phase 1
2. **Architect synthesis**: comparative table of the 4 architecture patterns (A custom deterministic / B hosted managed agents / C self-hosted multi-agent runtime / D pure custom) in `docs/architecture.md` — see Frame 14 § The 4 patterns
3. **Integration pattern per service** (direct API / MCP Tunnel / CLI wrapper) — see Frame 14 § External integration pattern

The final PRD MUST document the chosen pattern + explicitly justify rejecting the other 3. The `reviewer-prd` (Phase 2) checks this section, otherwise **PRD NOT OK**.

**See**: `doctrine/14-architecture-livraison-agent.md` for the full detail (tables, examples, anti-patterns).

**Closing** (3 paths, see R007):
1. You explicitly type `/cloture-cadrage [note]`
2. You say in NL "let's close", "PRD ready", etc. — the main Claude invokes automatically
3. The main Claude proposes it itself when it detects end-of-phase signals (consolidated deliverables, user satisfaction)

### Phase 2 — PRD validation (R001 mandatory before build)

**Automatic** (triggered by the Lead before session 0):

Lead invokes `Task(subagent_type="reviewer-prd")`. This agent (haiku, **read-only**: `disallowedTools: Edit, Bash, Task, Write(../../**)`):
- Reads `docs/PRD.md`, `docs/architecture.md`, `docs/compliance-audit.md`, shadowing transcripts
- Reads the session 0 prompt produced by `prompt-engineer`
- Checks: do all PRD criteria appear in the prompt? Is any locked decision bypassed?
- Output: `docs/prd-coverage-reports/YYYY-MM-DD-coverage.md` with verdict `OK` / `NOT OK` / `REVIEW`

**You** validate its verdict (in semi-auto mode). In `/lead-auto`, the Lead proceeds if OK.

### Phase 3 — Session 0 (technical init of the deliverable)

**Lead invokes** `prompt-engineer`, which produces `sessions/s0-prompt.md` in the meta-project. The prompt covers:
- `git init` in the **deliverable** (relative path from the meta: `cd ../../../projets/<category>/<project> && git init`)
- `npm init` + Next.js 16 structure (client convention)
- `.env.example` (NEXT_PUBLIC_*, GOOGLE_*, OAUTH_*, expected secrets)
- Generic README (without Vibeforge)
- `.gitignore`
- First commit, remote configuration to `github.com/your-org/<project>` (on your side, fork to the client afterwards)

**You validate** the prompt (via reviewer-prd, R001 mandatory). Then you give the Lead the go-ahead to execute S0.

**Execution**: you stay **in the same session** (cwd = lab). The Lead (or a dispatched sub-agent) writes the code in the deliverable via relative paths `../projets/<category>/<project>/...`. The S0 HANDOVER stays in the meta-project (`./projets-meta/<project>/HANDOVER.md`).

**Important note**: at no point do you open a separate session — neither in the deliverable nor in the meta-project. Everything happens at the lab cwd. The deliverable and the meta-project are "slave" folders written by the agents from the lab session.

### Phase 4 — Build sessions S1..Sn

For each feature:

1. You tell the Lead "prepare S1" (or it proceeds automatically in `/lead-auto`)
2. Lead invokes `prompt-engineer` → `sessions/s1-prompt.md` (reads S0 HANDOVER, the relevant PRD section, architecture, local registers)
3. Lead invokes `reviewer-prd` (R001) → audits that S1 covers the feature without gaps
4. If OK → Lead executes S1 in the same session (the code is written in the deliverable)
5. At the end of S1: Lead automatically invokes phase 5 (code review) before moving on to S2

**You can interrupt at any time**: "stop, I want to change X" → you take back control, the Lead waits.

### Phase 5 — Code review (before push)

At the end of each build session, **automatic**:

**Agent `code-reviewer`** (Vibeforge V2, to be created):
- Frontmatter: `skills: [superpowers:requesting-code-review]` (reuses the proven Superpowers mechanic)
- Business layer: knowledge of the client's patterns (naming conventions, IAP, Cloud Run, Sheets), domain-specific compliance rules, recurring blockers (em-dashes forbidden in emails, idempotent Sheet auto-create, etc.)
- Bootstrap: reads `docs/PRD.md` (feature section), `docs/architecture.md`, `git diff HEAD~1`, the project's `registers/learnings.md`
- Output: `docs/code-reviews/S<N>-review.md` with severities (critical / major / minor)
- Tools: `Read, Grep, Glob, Bash(git diff:*, git log:*)`. No code Write, no Edit.

**Verdict**:
- OK → Lead proceeds with the push + opening the PR
- Minor only → Lead presents to you, you validate
- Critical / Major → back to a session with fixes

### Phase 6 — Push, fork, deploy

**Lead executes** (with explicit confirmation, R4 safeguard for irreversible actions):
1. `git push origin main` to your personal repo `your-org/<project>`
2. `gh repo fork your-org/<project> --org your-org` (or via the UI if not configured)
3. Push the feature branch to the client fork
4. `gh pr create` with the body auto-filled from `docs/PRD.md` + `docs/code-reviews/S<N>-review.md`

**A collaborator** reviews the PR. If OK, merge to main → Cloud Build kicks in automatically → Cloud Run deploy.

For a specific project (exception documented in the lab's domain-context): no auto-deploy, manual redeployment via `gcloud run deploy` or the GCP Console.

## 3 control modes

| Mode | You validate | For what |
|---|---|---|
| `/lead` (default, semi-auto) | Each delegation and phase transition | Critical projects (prod, data sensitivity). 95% of cases. |
| `/lead-auto` | Only irreversible actions (push, deploy) | Simple projects, known refactors, you trust it. |
| Manual (direct slash by you) | Everything | Learning, debugging, exploration. You invoke `/architecte`, `/ux`, etc. by hand. |

## Auto-build: native Claude Code limit

`/lead-auto` can chain **framing + S0** automatically in a single session. **But** Claude Code **cannot spawn new sessions on its own** for S1, S2... — this is a native limit (except for experimental Agent Teams).

So in V1, S1..Sn remain successive phases in the **same session** as the framing. If the session saturates on context (>200k tokens), `/cloture-session` capitalizes, and you restart a new session with the up-to-date HANDOVER. The Lead bootstraps its context from MEMORY and resumes.

A conceivable V2 evolution: a wrapper script that runs `claude --print --resume <id>` in series for S1..Sn with a supervisor — to be explored if there is a real need.

## Anti-patterns

❌ Opening a new Claude Code session in the **deliverable** for the build phase (forces a re-bootstrap, loses the Lead, loses the lab + meta-project context). **Stay in the lab, write in the deliverable via `additionalDirectories`.**

❌ Opening a Claude Code session in the **meta-project** (`<lab>/projets-meta/<project>/`). That is wrong — you lose the auto-loading of the lab rules, the lab-specific agents, and the domain-context. The meta-project is just a subfolder of the lab, accessible via a relative path. **Canonical cwd = lab.**

❌ Skipping phase 2 (PRD validation, R001). This was the origin of a historical build-session incident. R001 is sacred.

❌ Pushing to the client repo without first forking from the personal repo. Your personal repo = source of truth for the deliverable, the fork = client view.

❌ Mixing HANDOVER / docs / registers into the deliverable. All of that stays in the meta-project (R002).

## See also

- Frame 4 (Agents): SendMessage, hybrid agent-contexts pattern
- Frame 8 (Transposition): creation of labs/projects
- R001 (PRD coverage), R002 (deliverable/meta split), R007 (long framing)
