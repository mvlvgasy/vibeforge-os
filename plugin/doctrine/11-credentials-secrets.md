# Frame 11 — Credentials & Secrets

> A 3-level credentials management pattern in Vibeforge.

## Definition

**Credentials** are sensitive values (API keys, tokens, secrets) used by:
- Vibeforge agents that interact with external tools (MCP servers, APIs)
- The APPLICATION code of projects (which calls SDKs from Node.js)

They MUST NEVER be:
- Committed to Git
- Mentioned in plaintext in registers, agent-contexts, or public docs
- Logged at `info` level or higher

## 3-level architecture

```
vibeforge/credentials/.env          ← LEVEL 0 — global Vibeforge
                                       Rare in practice (Claude Code OAuth handles most of it)
                                       E.g.: tokens used by scripts/hooks

<lab>/credentials/.env              ← LEVEL 1 — lab domain
                                       Credentials common to the domain's projects
                                       E.g. lab-client-acme: NOTION_TOKEN, PAYROLL_API_KEY
                                       E.g. lab-freelance-web: STRIPE_SECRET_KEY, APIFY_TOKEN

<lab>/projets/<projet>/.env         ← LEVEL 2 — project-specific
                                       Credentials of the project under development
                                       E.g. onboarding: ANTHROPIC_API_KEY (application LLM),
                                       SLACK_BOT_TOKEN_ONBOARDING, UPSTASH_REDIS_REST_URL
```

## Special case — Claude Code in OAuth

If you use Claude Code in OAuth mode (Claude.ai Team/Pro account), **the Vibeforge agents do NOT need `ANTHROPIC_API_KEY`** to work. Anthropic authentication is handled by Claude Code itself via the OAuth tokens stored in `~/.claude/.credentials.json`.

`ANTHROPIC_API_KEY` is required ONLY for:
- The application code of a project that calls the Anthropic API from Node.js (e.g. `onboarding/src/lib/anthropic.ts` using the official SDK for an embedded LLM chatbot)
- An external, non-Claude-Code script that calls the API directly

## Special case — claude.ai OAuth connectors (Gmail, Calendar, Drive, etc.)

When you connect third-party services on `claude.ai → Settings → Connectors`, Claude Code exposes **MCP servers** prefixed `mcp__claude_ai_<Service>__*`. These connectors grant **implicit** access to data without any key appearing in a `.env`. This is a distinct case from the classic credentials of Frame 11: there's no secret to protect, but a **read/write scope** to understand.

### Current scope (example)

| Service | Read | Write | Anthropic guardrail |
|---------|---------|----------|----------------------|
| Gmail | threads, drafts, labels | create_draft, label management | ❌ no direct `send_message` — drafts only, human sending required |
| Google Calendar | events, calendars | create / update / delete events, RSVP | — |
| Google Drive | content, metadata, permissions | create_file, copy_file | ❌ no delete / move |
| Notion, Slack, Atlassian, HubSpot, Vercel, Sentry, Figma, Canva, Gamma, Hugging Face, Make, monday.com | per connector | per connector | variable |

### Implications

- **Sensitive client data** (employees, GDPR) is potentially readable by any agent in a Vibeforge session if it transits through the Gmail, Calendar or Drive of the connected account.
- The anonymization rule applies fully: any content read via these connectors must NEVER be copied into registers, agent-contexts or public docs without anonymization.
- The **Anthropic logs** capture tool results — so everything an agent reads via these MCPs is technically seen by Anthropic under their retention policy.

### Recommendations

- **Sensitive sessions** (handling applications, payroll data): disconnect Gmail + Drive before the session via `claude.ai → Settings → Connectors`. Keep Calendar only if truly necessary.
- **Ad hoc audit**: before an unknown session (new lab, custom agent), check the active connectors on `claude.ai`.
- **No automatic Gmail sending**: the drafts-only limitation is an Anthropic guardrail — do not try to bypass it. If a project must send automated emails, go through a custom MCP server or an SDK with an explicit credential (level 1 or 2 depending on scope).

### Distinction from classic credentials

| | claude.ai OAuth connector | `.env` credential (Frame 11) |
|---|---|---|
| Provisioning | OAuth click on claude.ai | Manual by you |
| Storage | Tokens at Anthropic | local gitignored `.env` |
| Rotation | Auto (refresh tokens) | Manual |
| Scope | Fixed by Anthropic | Defined by you |
| Visible in code | No | Yes (env var) |
| Auditable | Via claude.ai UI | Via grep `.env.example` |

The two coexist: claude.ai connectors for standard SaaS with limited read/write, `.env` for custom APIs or precise scopes not available on the connector side.

## Recording timing

### At lab creation
**Who**: `lab-architect`
**What**:
- Asks you which DOMAIN credentials will likely be used
- Creates `<lab>/credentials/.env.example` with the list of variables (template, no values)
- Creates `<lab>/credentials/.gitignore` that ignores `.env`

**Example lab-client-acme**:
```
# lab-client-acme/credentials/.env.example
NOTION_TOKEN=ntn_XXXXX
PAYROLL_API_KEY=XXXXX
PAYROLL_API_BASE_URL=https://api.example.com
URSSAF_CLIENT_ID=XXXXX
URSSAF_CLIENT_SECRET=XXXXX
GITHUB_TOKEN_CLIENT=ghp_XXXXX
```

### During project discovery
**Who**: `business-analyst`
**What**:
- Identifies which EXTERNAL SERVICES the project will consume
- Lists them in the PRD section "Internal / external tools used"
- Does not list the exact technical variables (that's the architect's job)

### During project design
**Who**: `architecte`
**What**:
- Specifies EXACTLY which env variables are needed
- Documents them in `docs/architecture.md` section "§N Env variables"
- If sensitive data (GDPR) → coordinates with `gdpr-checker`
- Recommends a strict Zod schema for runtime validation

### Before the S0 build session
**Who**: `prompt-engineer` + `reviewer-prd`
**What**:
- The build session prompt mentions:
  - The required env variables
  - The validation pattern (strict Zod)
  - The loading pattern (from which file)
- `reviewer-prd` audits that these points are present (extended R001 coverage)

### During the S0/S1+ build session
**Who**: the building agent (Claude Code in the project)
**What**:
- Creates the `<projet>/.env.example` file (committed, no values)
- Creates `<projet>/src/lib/env.ts` (or equivalent) with a strict Zod schema
- In the HANDOVER, tells you what to put in `<projet>/.env` (local, gitignored)
- NEVER writes the real values in a file that will be committed

### At any time
**Who**: you
**What**:
- Can add a variable on the fly if an agent requests a new one
- MUST track it in the `.env.example` of the appropriate level (lab or project)
- MUST update the Zod schema if applicable

## Loading hierarchy

Variables are loaded in this order (the next one overrides the previous):

1. System env variables (rarely used)
2. `vibeforge/credentials/.env` (Level 0)
3. `<lab>/credentials/.env` (Level 1)
4. `<projet>/.env` (Level 2)
5. `<projet>/.env.local` (local developer override)

In practice, the application code loads from `<projet>/.env` (via `dotenv` or equivalent). Levels 0 and 1 are rarely loaded by the application code — rather by scripts or agents when they invoke MCP servers.

## Format of `.env.example`

Always committed. Pattern:

```dotenv
# Section: <Service>
# Description: <what it's for>
# How to obtain: <doc, dashboard, etc.>
SERVICE_API_KEY=XXXXX

# Required variables marked # REQUIRED
# Optional variables marked # OPTIONAL
```

Example:
```dotenv
# Section: Notion (read client corpus)
# Description: Notion token for access to project pages
# How to obtain: https://www.notion.so/profile/integrations
NOTION_TOKEN=ntn_XXXXX # REQUIRED

# Section: Anthropic SDK (application)
# Description: API key used by the Node.js code (NOT for Claude Code itself)
# How to obtain: https://console.anthropic.com/settings/keys
ANTHROPIC_API_KEY=sk-ant-XXXXX # REQUIRED if app uses embedded LLM
```

## Zod validation pattern

The application code of projects uses a strict pattern:

```typescript
// src/lib/env.ts
import { z } from 'zod';

const envSchema = z.object({
  ANTHROPIC_API_KEY: z.string().startsWith('sk-ant-'),
  NOTION_TOKEN: z.string().startsWith('ntn_'),
  // ...
}).strict();

export const env = envSchema.parse(process.env);
```

Benefits:
- Validation at startup (explicit crash if a variable is missing or malformed)
- Type safety throughout the code
- Implicitly documents the expected variables

## Security

### Non-negotiable rules

- ❌ NEVER commit a `.env` (always gitignored)
- ❌ NEVER log a variable value at `info` level or higher (only `debug`)
- ❌ NEVER paste a value into a `.md` file (doc, register, agent-context)
- ❌ NEVER share a `.env` via DM, email, or screenshot (except your own private circle)
- ❌ NEVER hardcode a key in the source code

### Automatic audit

Pre-commit hooks can scan diffs to detect patterns:
- `sk-ant-` (Anthropic)
- `xoxb-` (Slack Bot Token)
- `ntn_` (Notion)
- `xapp-` (Slack App Token)
- `ghp_` (GitHub Personal Access Token)
- `pa-` (Voyage AI)

Reference pattern in `.claude/hooks/pre-commit-validate-env.sh`.

### Rotation

To consider (not implemented in V1):
- Periodic rotation of long-lived tokens (yearly for API keys, monthly for short-lived access tokens)
- Audit of the permissions granted to each token

## Special cases

### Sensitive client domains (anonymization)
Client credentials (e.g. NOTION_TOKEN, PAYROLL_API_KEY) need extra protection:
- Not mentioned in plaintext in the registers
- Not in committed files, even in a personal lab
- If the lab is pushed to GitHub (even private), explicitly exclude the `.env`

### Multi-machine
If you work on 2 machines (personal + work), you must manually recreate the `.env` files on each machine. No automatic sync of credentials (security).

### Vibeforge in "agent called from a script" mode
If a PowerShell script (e.g. `scripts/new-lab.ps1`) must invoke a Claude Code agent, it uses the already-configured OAuth auth — no additional credential needed.

## Anti-patterns

- ❌ Putting all keys in `vibeforge/credentials/.env` (centralization = single point of failure)
- ❌ Putting keys in the `.env.example` (the `.example` is COMMITTED, therefore public)
- ❌ Documenting a key "for reference" in a register (registers are committed)
- ❌ Bypassing Zod validation "to save time"
- ❌ Sharing a full `.env` via Slack (even in a personal DM, it's risky — prefer 1Password or equivalent)

## Planned evolution

- Automatic pre-commit hook to scan for secret patterns (port of `pre-commit-validate-env.sh`)
- Skill `/credentials-audit` to scan `.env.example` against usages in the code (detect undocumented variables, or vice versa)
- 1Password CLI integration (optional, if you adopt a secrets manager)

## See also

- Frame 1: Constitution (anonymization rule, applicable to sensitive client domains)
- Frame 4: Agents (frontmatter `mcpServers` that may reference credentials)
- `vibeforge/credentials/.env.example`
- `<lab>/credentials/.env.example`
