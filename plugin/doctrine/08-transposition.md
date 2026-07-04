# Frame 8 — Transposition

> Applicability of the method to any kind of domain (dev, content, marketing, business, freelance).

## Definition

Vibeforge is not specialized for dev. Its structure (10 frames, 9 agents, 5 registers) works for any domain where a solo human needs to orchestrate intellectual work with an AI. Transposition is what makes Vibeforge **multi-domain**.

## Transposition mechanisms

### 1. Lab templates
Location: `vibeforge/templates/lab.template/`

Skeleton of a new lab:
```
lab.template/
├── CLAUDE.md.tpl              generic lab constitution
├── SOUL.md.tpl                lab identity (to customize)
├── contexte-domaine.md.tpl    domain corpus (to fill in)
├── .gitignore.tpl
└── registres/
    ├── INDEX.md.tpl
    ├── bdr.md.tpl
    ├── blockers.md.tpl
    ├── learnings.md.tpl
    ├── journal.md.tpl
    └── eval.md.tpl
```

Variables to substitute (via the `/new-lab` skill):
- `{{LAB_NAME}}`: lab name
- `{{LAB_DOMAIN}}`: domain (dev, content, business...)
- `{{LAB_CLIENT}}`: client/context if applicable
- `{{LAB_CREATED}}`: creation date
- `{{LAB_PARENT}}`: path to Vibeforge

### 2. Project templates (two templates)

Location: `vibeforge/templates/`

- **`projet.template/`** — skeleton of the **deliverable** at the stack root level. Minimalist:
  - `README.md.tpl` (generic entry doc for the client)
  - `.gitignore.tpl` (Node + env + OS)
  - Nothing Vibeforge-specific — it's a repo that can be forked at the client's side.
- **`projet-meta.template/`** — skeleton of the **meta-project** inside the lab. Rich:
  - `CLAUDE.md.tpl`, `HANDOVER.md.tpl`, `README.md.tpl`
  - `docs/PRD.md.tpl`, `docs/prd-coverage-reports/`
  - `registres/{INDEX,bdr,blockers,learnings,journal,eval}.md.tpl`
  - `.claude/rules/00-project-context.md.tpl`
  - `.claude/settings.local.json.tpl` (additionalDirectories pointing to parent lab + Vibeforge + deliverable)

### 3. Skill `/new-lab -Name <domain>`
Bootstrap a new lab from the template (the `lab-` prefix is added automatically). Examples:

- `/new-lab -Name client-acme` → `<workspace>/lab-client-acme/`
- `/new-lab -Name freelance-web` → `<workspace>/lab-freelance-web/`
- `/new-lab -Name content` → `<workspace>/lab-content/`

**Important — inheritance of Vibeforge agents/skills**:

The created lab inherits the 9 generic agents (`lead`, `architecte`, `ux`, `business-analyst`, `prompt-engineer`, `reviewer-prd`, `traffic-controller`, `skill-curator`, `lab-architect`) and all wrapper skills (`/lead`, `/architecte`, etc.) **automatically** via the Claude Code plugin `vibeforge@vibeforge-marketplace`, **NOT via `additionalDirectories`**.

→ Prerequisite: the plugin must be installed on the machine (`claude plugin install vibeforge@vibeforge-marketplace`). See doctrine 04, section "Installing the Vibeforge plugin".

→ The lab can still keep `additionalDirectories: ["../vibeforge"]` in its `settings.local.json` — this is useful to let lab-specific agents **read** Vibeforge files (registers, doctrine), but it is NOT the mechanism that loads the agents/skills.

→ The `new-lab.ps1` script reminds you at the end of creation to verify the plugin is correctly installed.

### 4. Skill `/new-projet -Name <name> -AffiliatedLab lab-X`
Bootstrap a new project as **two folders**:

1. **Deliverable** created at `<workspace>/<name>/` (from `projet.template/`)
2. **Meta-project** created at `<workspace>/lab-X/projets-meta/<name>/` (from `projet-meta.template/`)

`AffiliatedLab` is **mandatory** — every project is attached to a methodological lab. The lab provides the method, the deliverable receives the code.

This structure lets you push the deliverable to its own GitHub remote (e.g. `github.com/your-org/onboarding-v2/`) **without polluting** the client repo with the Vibeforge method.

### 5. Architecture of the project / meta-project split (R002)

**Non-negotiable rule R002** — `<workspace>/registres/rules.md`.

#### Lab categories (physical placement)

Each lab has a **category** defined at creation (`<lab>/.vibeforge/category.txt`):
- `client` — internal company project (you as an employee)
- `freelance` — paid external client engagement
- `perso` — personal project (blog, side-project)
- `custom` — other

The category is used to **physically place** deliverables: all deliverables of a lab go into `<workspace>/projets/<category>/<projet>/`.

Auto-inference at creation: if the lab name contains `client` / `freelance` / `perso`, the `/new-lab` script pre-suggests the matching category.

#### Full diagram (with categories)

```
<workspace>/
├── vibeforge/                                ← root method
├── lab-client-acme/                          ← lab cat: client
│   ├── .vibeforge/category.txt               (= "client")
│   └── projets-meta/
│       └── onboarding-v2/                    ← ⚙️ META-PROJECT
│           ├── CLAUDE.md
│           ├── HANDOVER.md
│           ├── docs/PRD.md (drafts + final pre-delivery)
│           ├── docs/architecture.md
│           ├── docs/transcription-*.md
│           ├── docs/prd-coverage-reports/
│           ├── registres/{bdr,blockers,learnings,journal,eval}.md
│           ├── .claude/rules/00-project-context.md
│           └── .claude/settings.local.json
│
├── lab-freelance-web/                        ← lab cat: freelance
│   ├── .vibeforge/category.txt               (= "freelance")
│   └── projets-meta/
│       └── acme-corp-site/
│
└── projets/                                  ← 📦 DELIVERABLES placed by category
    ├── client/
    │   └── onboarding-v2/                    ← standalone git repo
    │       ├── README.md (generic, not Vibeforge)
    │       ├── .gitignore
    │       ├── src/
    │       └── package.json
    │                                         → free to push to github.com/your-org/onboarding-v2/
    ├── freelance/
    │   └── acme-corp-site/
    │       └── ...                           → free to push to github.com/acme/site/
    └── perso/
        └── my-blog/
            └── ...                           → free to push to github.com/<perso>/my-blog/
```

#### Workflow of a session

1. The CLI launches `claude` with **`cwd = lab-client-acme/projets-meta/onboarding-v2/`** (meta-project)
2. Bootstrap: the lead reads
   - `./CLAUDE.md` (meta-project constitution)
   - `./HANDOVER.md` (previous session state)
   - `./docs/PRD.md` (product spec)
   - `./.claude/rules/00-project-context.md`
   - via `additionalDirectories`: `../..` (parent lab), `../../../vibeforge/` (root method), `../../../onboarding-v2/` (deliverable)
3. During the session:
   - The lead **writes the code** in `../../../onboarding-v2/src/` (the deliverable)
   - The lead **writes the method** here (HANDOVER, registers, PRD drafts)
4. End of session: `/cloture-session` updates the meta-project only

#### Substitution variables (`projet-meta.template/` templates)

To avoid hardcoding absolute paths, the templates use these variables substituted by the `new-projet.ps1` script at bootstrap:

- `{{PROJET_NAME}}`: project name (kebab-case)
- `{{PROJET_CREATED}}`: date YYYY-MM-DD
- `{{LAB_NAME}}`: affiliated lab name
- `{{LAB_CATEGORY}}`: category inherited from the lab (client / freelance / perso / custom)
- `{{LAB_PATH_RELATIVE}}` = `../..` (from meta to lab)
- `{{VIBEFORGE_PATH_RELATIVE}}` = `../../../vibeforge`
- `{{LIVRABLE_PATH_RELATIVE}}` = `../../../projets/<category>/<projet>`

#### Quick test to understand

> "If I had to push this folder to the client's remote, would it be OK?"

- The **deliverable** → YES, it's designed for that (just code)
- The **meta-project** → NEVER (contains drafts, transcriptions, stakeholder data)

If you're unsure about a specific file, put yourself in the client's shoes: *do they have a legitimate reason to see this file in their repo?* If not → it's meta, it stays in the lab.

## Pre-planned domains

| Domain | Lab type | Most useful generic agents | Recommended complementary agents | Specifics |
|---------|----------|--------------------------------|-----------------------------------|----------------|
| Client HR | `client-acme` | lead, BA, prompt-engineer, reviewer-prd | `gdpr-checker`, `hr-liaison`, `payroll-specialist` | GDPR constraint, HR stakeholder, specific PRD format |
| Freelance dev | `freelance-dev` | lead, architecte, prompt-engineer | `frontend`, `backend`, `devops`, `qa`, `client-comm` | Separate client repos, invoicing, quotes |
| Content creation | `content` | lead, strategie-contenu, ux | `copywriter`, `video-editor`, `seo`, `community-manager` | Editorial calendar, social formats |
| Marketing | `marketing` | lead, strategie-contenu, BA | `campaign-manager`, `analytics-specialist`, `ab-test-designer` | Campaigns, A/B testing, metrics |
| Personal business | `business-perso` | lead, BA | `accounting`, `prospecting`, `contracting` | Activity steering, finances |

Not exhaustive. You can add other types by creating new templates.

## "Complementary agents" pattern (recommended)

Complementary agents are agents SPECIFIC to the domain of a lab. They:
- Live in `<lab>/.claude/agents/<name>.md`
- Do NOT OVERRIDE the generic agents (which stay in the root method)
- Provide skills the root method doesn't cover (e.g. GDPR, payroll, frontend, copywriting)
- Follow the same "armed agent" pattern as the generic ones (full frontmatter, agent-contexts, etc.)

**Creation workflow**:
1. At lab startup, you identify 1-5 domain-specific roles
2. The lead (generic, in the lab's context) proposes the specs of the complementary agents
3. For each, create `<lab>/.claude/agents/<name>.md` + `<lab>/agent-contexts/<name>/`
4. Complementary agents are invokable by the lead via the Task tool, like any generic agent

**Evolution**: if after several labs the same complementary agent keeps coming back (e.g. `gdpr-checker` useful for 2+ HR/dev labs), it's a candidate for promotion to a generic Vibeforge agent via the traffic-controller.

## Adaptation per domain

Each lab has its own `contexte-domaine.md` that specializes:

### For `client-acme`
- Client tech stack
- GDPR rules
- Specific PRD format
- Internal tools (Notion, Slack, etc.)
- Stakeholders (HR director, management)

### For `freelance`
- Quote templates
- Contracting patterns
- Invoicing workflows
- Client communication conventions

### For `content`
- Editorial calendar
- Target platforms (Instagram, LinkedIn...)
- Hook, narration, CTA patterns
- Performance metrics

## The method stays agnostic

The Vibeforge root method CONTAINS NO domain specifics. Only labs specialize. This allows you to:
- Reuse the method for any new domain
- Avoid polluting the root method with overly specific context
- Easily onboard someone else to Vibeforge without them having to know your client

## Anti-patterns

- ❌ Putting client-specific context into the Vibeforge root method → breaks transposition
- ❌ Creating a lab specific to each sub-domain ("lab-hr-onboarding-only") → needless proliferation, 1 lab = 1 reasonably broad objective
- ❌ Templates too rigid → prevent adaptation
- ❌ Templates too empty → the user has to rewrite everything at each bootstrap
- ❌ A `/new-lab` skill that creates without personalization → no effective specialization

## See also

- Skill `/new-lab` in `.claude/skills/new-lab/SKILL.md`
- Skill `/new-projet` in `.claude/skills/new-projet/SKILL.md`
- Templates in `vibeforge/templates/`
