# Vibeforge Global Rules

> Non-negotiable cross-cutting rules, promoted from recurring learnings.
> MANDATORY reading for all agents at startup.

## Index

- [R001](#R001) — PRD coverage before a build session
- [R002](#R002) — Split deliverable / meta-project
- [R003](#R003) — Mandatory translation step before agentifying a raw format
- [R004](#R004) — Long tool output (>50 lines) MUST be saved to a file; the tool returns the path
- [R005](#R005) — Non-reversible domain → mandatory "draft" state before action
- [R006](#R006) — Mandatory formal replan between roadmap phases
- [R007](#R007) — Long scoping session pattern via SendMessage
- [R008](#R008) — Guaranteed three-layer session close
- [R009](#R009) — Agent MEMORY scoped to 2 levels + shared cross-agent + dreamer + validator
- [R010](#R010) — 3+ failed fix attempts on the same symptom → mandatory architecture pivot (stop patching)
- [R012](#R012) — Sub-agent frontmatter: `tools` AND `disallowedTools` using simple names only (no `Tool(pattern)`)
- [R013](#R013) — Frame 0 scoping: mandatory mature upstream OSS audit (≥80%) before building a framework/runtime
- [R014](#R014) — Upfront multi-sprint scoping when an upstream strategic backlog exists
- [R015](#R015) — Mandatory bootstrap ≤ 5 items + Edit in the tool palette of agents that write PRD/architecture/prompts
- [R016](#R016) — Agent MEMORY cap ≤ 500 words (HARD) + mandatory pruning before write
- [R017](#R017) — Skills auto-created by sub-agents on mission: skill-curator mandatory
- [R018](#R018) — Persistent scoping memory (MEMORY-cadrage.md): externalize the why/roadmap/decisions to disk, anti-compaction-amnesia

---

## R001 — PRD coverage before a build session

```yaml
---
id: R001
type: rule
severity: critical
domain: prd-coverage
status: active
version: 1.0
---
```

### Rule

**Before any Claude Code build session prompt** (i.e. a session that will modify production code), it is MANDATORY to:

1. Re-read in full, in this order:
   - The project PRD
   - The project architecture
   - The architecture addendum (if one exists)
   - The shadowing / discovery transcripts
   - The previous session's HANDOVER

2. Verify that ALL criteria / constraints / locked decisions identified in these documents appear explicitly in the upcoming session prompt.

3. Have the coverage validated by the `reviewer-prd` agent BEFORE launching the build session.

### Why

This rule emerged from a real incident where PRD criteria were omitted from the final session prompt. The consequence was costly rework, backtracking, and significant lost time. The root cause: no systematic coverage check before launch.

This is exactly the kind of friction Vibeforge aims to prevent through its reviewer agents.

### How to apply

- The `lead` MUST invoke `reviewer-prd` before delegating to `prompt-engineer` to prepare a build session prompt
- `reviewer-prd` produces a structured report:
  - ✅ Criterion X present in the prompt
  - ❌ Criterion Y MISSING
- If ≥1 criterion is missing → the build session does NOT start, `prompt-engineer` fixes and resubmits
- Tracking: the reviewer-prd report is committed as a PRD annex or appended to the session journal

### Limits / counter-examples

- **Exploratory sessions** (brainstorm, debug, refactor without new production code): the rule does NOT strictly apply, but a quick check is still recommended
- **Urgent hotfix sessions**: the rule may be explicitly bypassed by the operator, BUT the hotfix must be followed by a catch-up session that re-covers the criteria

### Anti-patterns to avoid

- ❌ "The PRD is in my head, no need to re-read" — this is exactly what caused the original incident
- ❌ "We re-read it 3 days ago, it's fine" — not sufficient if the PRD changed OR if you lost the thread in the meantime
- ❌ Skipping `reviewer-prd` to "save time" — missing one criterion costs 10× the time of the review

### See also

- Agent `reviewer-prd`

---

## R002 — Split deliverable / meta-project

```yaml
---
id: R002
type: rule
severity: critical
domain: project-architecture
status: active
version: 1.0
---
```

### Rule

Every Vibeforge project is materialized as **two physically separate folders**:

1. **Deliverable**: `<workspace>/projets/<category>/<project>/`
   - Pure code only (`src/`, `package.json`, generic `README.md`, `.gitignore`).
   - An **autonomous** git repo, pushable to the client remote (e.g. `github.com/your-org/<project>`).
   - **NO Vibeforge file** should live here: no `CLAUDE.md`, no `HANDOVER.md`, no `registers/`, no `.claude/rules/`, no `.vibeforge/`, no transcripts, no PRD drafts.
   - Filed under the **category** inherited from the affiliated lab (decided once at lab creation via `<lab>/.vibeforge/category.txt`).

2. **Meta-project**: `<lab>/projets-meta/<project>/`
   - All the **method + tracking** (CLAUDE.md, HANDOVER.md, docs/PRD.md drafts + final pre-delivery, docs/architecture.md, docs/transcript-*.md, docs/prd-coverage-reports/, registers/, .claude/rules/00-XX.md, .claude/settings.local.json).
   - Lives in the methodological lab (versioned with the lab, private).

**Claude Code sessions always have their `cwd` in the meta-project, never in the deliverable.** Agents write code into the deliverable via `additionalDirectories` (configured in the meta-project's `.claude/settings.local.json`, pointing to `../../../projets/<category>/<project>/`).

### Why

You must be able to push deliverables to client remotes (`github.com/your-org/...`) without polluting those repos with:
- The Vibeforge method (CLAUDE.md, doctrine, agents, settings)
- Pre-finalization PRD drafts
- Discovery / shadowing transcripts (often contain stakeholder data)
- HR / client meeting notes
- Internal registers (learnings, blockers, BDR)

If all these files lived in the deliverable repo:
- The client would receive a repo FULL of internal metadata
- Possible exposure of stakeholder data (GDPR concerns)
- No clean client repo ready to `git clone + npm install`
- Impossible to hand the repo to another developer without explaining 50 Vibeforge files

### How to apply

- `/new-projet -Name <name> -AffiliatedLab lab-<X>` always creates **both folders**
- `AffiliatedLab` is **mandatory** (without a methodological lab, no meta-project is possible)
- The **category** is read from `<lab>/.vibeforge/category.txt` (created by `/new-lab -Category <c>`). Fallback to `custom` if absent.
- The meta-project contains `.claude/settings.local.json` with:
  ```json
  {
    "additionalDirectories": [
      "../..",                                          // parent lab
      "../../../vibeforge",                             // root method
      "../../../projets/<category>/<project>"           // deliverable
    ]
  }
  ```
- Agents:
  - Write **code** in the deliverable (`../../../<project>/src/`, etc.)
  - Write **everything else** (method, tracking, registers, drafts) in the meta-project
- Outside a build session, NEVER launch `claude` with `cwd = <deliverable>`

### Limits / counter-examples

- **Final PRD delivered to the client**: it is OK to put a *final, cleaned* copy of the PRD in `<deliverable>/docs/PRD.md` at delivery time. Drafts/iterations stay in the meta-project.
- **Open source**: if a deliverable is public open-source, the separation is even more critical (no stakeholder leak).
- **Purely personal project**: if you build a personal project that is never shared, the separation is still useful for cleanliness but can be relaxed (registers in the deliverable if there is no confidentiality concern).

### Anti-patterns to avoid

- ❌ Creating `CLAUDE.md`, `HANDOVER.md`, `registers/` directly in `<deliverable>/`
- ❌ Putting discovery transcripts (they contain stakeholders) in the deliverable
- ❌ Putting pre-finalization PRD drafts in the deliverable
- ❌ Launching a Claude Code session with `cwd = <deliverable>` (the bootstrap would have nothing to read)
- ❌ Creating an "orphan" project with no affiliated lab — always attach to a methodological lab
- ❌ Versioning the meta-project's `.claude/settings.local.json` (gitignored: it contains machine-specific `additionalDirectories`)

### See also

- Frame 1 — Constitution (`doctrine/01-constitution.md`, "Project level" section)
- Frame 8 — Transposition (`doctrine/08-transposition.md`, "Project templates" section)
- `templates/projet.template/` (minimalist deliverable)
- `templates/projet-meta.template/` (rich meta)
- `scripts/new-projet.ps1` (orchestrates both creations)

---

## R003 — Mandatory translation step before agentifying a raw format

```yaml
---
id: R003
type: rule
severity: high
domain: agent-design
status: active
version: 1.0
---
```

### Rule

Before agentifying work on a raw business format, the **first mandatory step** is to define a **translation skill** that converts that raw format into a format the model masters natively: **structured Markdown, JSON, SQL/SQLite, standard Excel notation (B3:B5)**.

**The main agent NEVER reasons over the raw input.** It always reasons over the translated output.

### What is a "raw format" (= requires translation)

Indicative, non-exhaustive list. **If in doubt, apply the test below.**

- **PDF** (ATS resume, business PDF, scanned OCR PDF) → text extraction + Markdown structuring
- **Spreadsheet** (XLSX, ODS, chaotic CSV with inconsistent separators, mixed encodings) → SQLite or Markdown table
- **Raw audio / video** → transcription (Otter, AssemblyAI, Whisper) then Markdown enrichment
- **Raw transcript** without speaker tags or timestamps → Markdown enrichment (cf. skill `translate-transcript-to-prd`)
- **OCR output of a scan** → cleanup + Markdown reformatting
- **Server logs** (Apache, nginx, kubectl logs, journalctl) → pattern extraction + structured summary
- **Email mbox/eml** → subject/from/body extraction + thread reconstruction
- **Business XML** (HR SAP, EDIFACT, proprietary SOAP) → normalized JSON
- **Proprietary dump** (.sql dump, .sqlite dump, proprietary format) → tabular SQL extraction
- **Very noisy JSON** (>10 nesting levels, volatile keys, mixed schemas) → flattening + normalization first

### Concrete exemption test (when R003 does NOT apply)

For a given input, ask yourself: **"Does Claude read this format **without needing structural explanation**?"**

- ✅ If yes → exempt (no translation needed)
- ❌ If no → apply R003

### Formats explicitly exempt (no translation needed)

- **Well-structured Markdown** (.md, .markdown) with hierarchical headings
- **Clean JSON**: ≤5 nesting levels, stable keys, ≤200 lines
- **Clean YAML config** (settings, well-indented k8s manifests)
- **Source code** (.ts, .py, .go, .rs, .java...) with valid syntax
- **Simple HTML** (without 50 trackers or obfuscated inline JS)
- **Documented API response JSON** with a stable schema

⚠️ Caution: a Markdown or JSON file can **itself become raw** if it is poorly structured (a 1000-line .md with no headings, a JSON with keys `field_0001..field_0500`). In that case, R003 applies.

### Why

Cited public source — Tariq Mansour (Anthropic, Agent SDK team): *"Try and make your problem as in-distribution as possible for the agent."*

LLMs are massively trained on code (SQL, JSON, Python, Markdown). They are barely trained on custom business formats (ATS resumes, HR SAP XML, financial Excel dumps). Forcing the LLM to reason over an out-of-distribution format strongly degrades quality — the same mechanism as giving a human a text in a language they barely know.

This rule prevents the anti-doctrinal pattern *"just throw the resume PDF at it, it'll figure it out"* which produces inconsistent and unauditable outputs.

### How to apply

- **When scoping any new project** that touches a raw business format: identify the translation step AS EARLY AS the PRD, before architecture
- **Technical pattern**: create a dedicated skill per format (`/translate-cv-to-json`, `/translate-transcript-to-prd`, `/translate-spreadsheet-to-sqlite`)
- **Canonical output**: choose a pivot format the model masters (structured Markdown for text, JSON for structured data, SQL/DuckDB for tabular)
- **Translation test**: the skill MUST include a test on a sample (is the translated output faithful to the raw input? are the key facts preserved?)
- **Documented fallback**: if translation fails (poorly scanned PDF, noisy transcription), an explicit fallback procedure (human-in-the-loop, retry with another tool)

### Limits / counter-examples

- **Already-native formats** (Markdown, JSON, Python, SQL, YAML): no translation needed, R003 does not apply
- **Very short outputs** (a title, a name, an isolated date): direct extraction possible without formalizing a skill — a translation step would be over-engineered
- **Unexpected pivot format**: sometimes the best translation is exotic (e.g. Excel notation B3:B5 for spreadsheets) — that is OK as long as the model is in-distribution on that format

### Anti-patterns to avoid

- ❌ Handing a raw resume PDF to an agent and asking "analyze this resume" — approximate parsing corrupts everything downstream
- ❌ Writing a custom parser inside the agent instead of externalizing it into a reusable skill
- ❌ Treating the translation step as "a detail" — it is often 80% of the result quality
- ❌ Skipping the translation fidelity test — a silently broken parser poisons all downstream analyses

### See also

- Skill candidate `S-translate-transcript-to-prd`

---

## R004 — Long tool output (>50 lines) MUST be saved to a file; the tool returns the path

```yaml
---
id: R004
type: rule
severity: high
domain: agent-design
status: active
version: 1.0
---
```

### Rule

No tool call that produces **more than 50 lines of output** (or >5000 characters for dense output) returns the content directly to the calling agent. The tool saves to the filesystem (under `<project>/cache/`, `<lab>/registers/cache/`, or a contextual equivalent) and **returns only the path** + a short summary (10-15 lines max).

The calling agent greps / reads the file if relevant. The save also serves as an audit trail (the agent can later re-check its reasoning).

### Why

Cited public source — Tariq Mansour (Anthropic, Agent SDK team): *"Whenever I have a tool call, I save the results of the tool call to the file system so that you can search across it and then have the tool call return the path of the result. Just because that helps it recheck its work."*

Without this rule, long outputs (search results, listings, API dumps, logs) saturate the agent's main context. An agent at 80% context window sees its reasoning quality degrade sharply. The filesystem acts as a near-unlimited external memory — a pattern validated externally by Anthropic.

### How to apply

- **New custom tools / skills**: implement the save-and-return-path pattern by default for any structurally long output (search results, file listings, query dumps)
- **Storage convention**: `<project>/cache/<tool>-<timestamp>.txt` or `<lab>/registers/cache/...` — gitignored by default (cache = disposable)
- **Summary to return**: 10-15 lines max — number of results, first results, full path for drill-down
- **Audit of existing skills**: if a skill produces output >100 lines, consider migrating to save-and-return-path
- **Exception for short outputs**: <50 lines = direct return OK (filesystem overhead is pointless)

### Limits / counter-examples

- **Short structured outputs** (small JSON, computation result, boolean status): direct return, R004 does not apply
- **Final user output** (a response to present to the human in chat): direct return OK — the conversation context has its own logic
- **Outputs already persisted elsewhere** (e.g. the result of writing to a register): return just the path, no need to double-save

### Anti-patterns to avoid

- ❌ Returning a 500-line dump in a tool response — agent context saturation
- ❌ Caching without periodic cleanup — accumulation of disposable files
- ❌ No summary in the return (just the path) — the agent does not know what is there without going to fetch it
- ❌ Saving to an unpredictable location — the agent loses the path between turns

---

## R005 — Non-reversible domain → mandatory "draft" state before action

```yaml
---
id: R005
type: rule
severity: critical
domain: agent-design
status: active
version: 1.0
---
```

### Rule

Any agentic action whose effect is **irreversible in the real world** (sending an email to an external recipient, creating an employment contract, pushing to prod, paying a supplier, publishing a social media post, modifying a payslip, deleting GDPR-sensitive data) **MUST** pass through an intermediate **"draft"** state validated by a human.

**No irreversible action initiated directly by an agent without an explicit human checkpoint.**

### Why

The **reversibility test** classifies these actions as poor agent candidates by construction: an agent that errs on code = `git reset`, near-zero cost. An agent that sends an erroneous email to 50 candidates = impossible to recover, heavy reputational damage.

The canonical mitigation to agentify these domains anyway is to **artificially build in reversibility** via the draft state: the agent prepares, a human validates, the human (or a script triggered by the human) executes the irreversible action.

This rule particularly protects HR work (candidate email, contract, payroll) and any future content/marketing work (social media publishing, newsletter sending).

### How to apply

- **When scoping a new project**: explicitly run the reversibility test during the PRD. If an action is irreversible, plan for the "draft" state in the flow from the PRD onward.
- **Technical pattern**: the agent writes the output to a draft file (`<project>/drafts/<action>-<timestamp>.md` typically), returns the path to the human, NEVER executes the action itself.
- **Human validation**: can be a dedicated slash command (`/send-draft <path>`) or an in-conversation review ("OK send it") followed by a targeted dispatch.
- **For HR work**: all actionable HR outputs (candidate email, contract, payroll change) MUST be drafts. No direct dispatch to an SMTP sender or an HR API.
- **Document in the PRD**: an explicit "reversibility" section for each automated action — "reversible (rollback possible)" or "irreversible → mandatory draft state".

### Limits / counter-examples

- **Actions internal to the workspace** (modifying a code file, creating a folder, writing to a register): `git` makes everything reversible, R005 does NOT apply.
- **Sandbox test**: an agent can send emails to an internal test inbox without a draft state — the recipient is itself.
- **Urgent hotfix explicitly validated by the operator**: R005 may be bypassed ad-hoc, BUT the bypass must be traced in the session journal.

### Anti-patterns to avoid

- ❌ Agentifying a non-reversible workflow without explicit mitigation ("the agent will be careful") — exactly what the reversibility test condemns
- ❌ Treating "the agent is careful" as sufficient mitigation (LLMs hallucinate; you NEED a structural checkpoint)
- ❌ Mixing reversible and irreversible in the same tool without separation (e.g. a single `send_email_or_save_draft` tool driven by a flag — prefer 2 distinct tools)
- ❌ Defining the "draft" as a mere chat confirmation ("do you confirm the send?") without materializing a file — no trace, no audit

---

## R006 — Mandatory formal replan between roadmap phases

```yaml
---
id: R006
type: rule
severity: critical
domain: project-management
status: active
version: 1.0
---
```

### Rule

When crossing each roadmap phase (end of a TDD phase, end of a sprint, delivery of a milestone), the project MUST undergo a **formal replan** before engaging the next phase.

The formal replan materializes as at least one of the following:
- An updated **phase mini-PRD** (goals, scope, out-of-scope, success criteria of the next phase)
- A **refresh of the TDD plan** (new bite-size tasks, revision of in-progress tasks, explicit abandonment of obsolete tasks)
- A **phase BDR** if structuring decisions were made during the phase that change the scope

**Without a formal replan, do not engage the next phase.**

### Distinction from R001

R001 and R006 are complementary, not redundant:
- **R001** = consistency check between the session prompt and the **existing** PRD (check before build). Invoked by `reviewer-prd`. Applies to every build session.
- **R006** = the act of **redefining** the execution plan when **crossing a roadmap phase**. Applies once per phase, not every session. Produces an updated PRD or plan that R001 then checks.

R006 feeds R001: after the formal replan (R006), the next build session benefits from an updated PRD/plan that reviewer-prd can verify cleanly.

### Why

This rule emerged from a real incident where a project executed 5 roadmap phases in 7 days (~275 commits) **with no formal replan between phases**. The result: massive scope creep, cascading bugs, a project that was not functional end-to-end weeks later.

The initial bite-size TDD plan (Phase 1, ~5h, clean) degenerated from Phase 2 onward for lack of a closing ritual. The agent — or the human on autopilot — chains features without replanning, the scope grows invisibly, and cascading bugfixes signal that implicit technical debt has exploded.

With intensive agents (parallel execution, many sub-agents), scope creep can absorb 5 phases in 7 days. The code production speed masks the divergence from the initial scope.

### How to apply

- **Before starting a new phase**: produce at minimum a refresh of the TDD plan (list of phase tasks, success criteria, explicit out-of-scope)
- **For Vibeforge projects**: the replan can be a simple Lead message → `/lead "replan phase N"` that produces a document in `<meta-project>/docs/plan-phase-N.md`
- **"Phase" criterion**: any logical milestone (complete feature delivery, end of sprint, change of technical layer, test-user onboarding)
- **Minimal acceptable format**: 5 lines is enough — phase objective, 3 deliverables, 2 out-of-scope, one binary success criterion

### Limits / counter-examples

- **Ultra-short projects** (1 session, <1 day): R006 does not apply — a single phase
- **Isolated hotfixes**: fixing a specific bug without starting a new phase → no replan required
- **Exploratory / discovery sessions**: no formal roadmap → R006 does not apply

### Anti-patterns to avoid

- ❌ Jumping straight into the next phase after delivering one ("the momentum is here, let's keep going") — exactly what kills projects via scope creep
- ❌ Considering the initial plan still valid after several weeks of intensive agentic execution — the scope changed, so should the plan
- ❌ Confusing with R001: R001 checks the existing, R006 redefines for what's next
- ❌ A purely mental / verbal replan — it must be materialized in a file (audit trail, otherwise undetectable)

### See also

- R001 (PRD coverage before a build session — complementary, not redundant)

---

## R007 — Long scoping session pattern via SendMessage

```yaml
---
id: R007
type: rule
severity: critical
domain: orchestration
status: active
version: 1.0
---
```

### Rule

When the user invokes `/lead` (or `/lead-auto`, `/architecte`, etc.) to start a **long scoping** phase (several back-and-forth exchanges before a PRD/architecture deliverable), the main Claude **MUST** route natural-language follow-ups to the **SAME** sub-agent via `SendMessage(agentId)` as long as:

1. The user does not explicitly switch agent (`/architecte`, `/ux`, etc.)
2. The user has not said "end of scoping" / "thanks, I have what I need"
3. The main session has not been compacted

### Why

`SendMessage` is a **native Claude Code** mechanism (release 2.1.139+) that wakes a dormant sub-agent with its preserved context (the `agentId` returned by the Task tool at the initial dispatch). Without this rule, the main Claude tends to answer itself while imitating the Lead — losing the agent "personality", losing the specific context, and above all losing the guardrails (R1-R6 + doctrine + persistent memory that exist ONLY in the isolated sub-agent).

### How to apply (main Claude side)

- On the first `/lead <rich request>`, store the `agentId` returned by the Task tool
- On EACH subsequent natural-language user prompt, BEFORE answering yourself:
  - **Default routing**: `SendMessage(agentId=lead, prompt=<user message>)` and present the response
  - **Exceptions**: prompt starts with a different agent slash → switch; very short factual prompt ("ok", "thanks") that needs no orchestration → you may answer

### Closing — explicit, natural language, or auto-proposal

**3 closing paths**:

1. **Explicit slash**: the user types `/cloture-cadrage [note]` → main Claude executes the skill.
2. **Natural language**: the user says "let's close", "end of scoping", "thanks, on to the build", "PRD ready", "OK let's move on". Main Claude detects these triggers and **automatically invokes** `/cloture-cadrage` without asking for extra confirmation.
3. **Auto-proposal by main Claude**: main Claude **MUST** propose closing when it detects:
   - All the main scoping agents (BA, UX, architect, relevant lab agents) have produced their deliverable
   - Several turns with no substantive new decision (only minor clarifications)
   - The user expresses satisfaction ("OK works for me", "perfect", "good")
   - Presentation of a consolidated deliverable (complete PRD draft, etc.)

   Proposal format: *"The scoping seems to be wrapping up (X agents produced their deliverables, Y turns since the last decision). Want me to close now via `/cloture-cadrage` for a final synthesis + MEMORY persistence? (yes / continue)"*

**Closing action** (`/cloture-cadrage`):
1. Asks the active Lead for a final synthesis via `SendMessage(agentId=lead, "synthesize and propose next steps")`
2. Forces the Lead to update its `agent-contexts/lead/MEMORY.md` (lab-specific by default, global if a cross-cutting insight is flagged)
3. Releases the routing (subsequent user prompts go through main Claude directly, until the next `/lead`)

### Limits

- `agentId` expires with the main session (on close / compaction) → after compaction, redo `/lead` for a new dispatch
- The sub-agent keeps its context → watch for context bloat on very long scoping sessions (beyond ~100k tokens, ask for a synthesis + restart)

### Mandatory fallback — Claude Code < 2.1.139

On older Claude Code versions, the `SendMessage` tool **does not exist** (introduced in 2.1.139+). Symptom: main Claude announces *"SendMessage is not available in this session"* then re-dispatches a new Lead via `Task` → full re-bootstrap each turn (loss of the Lead's specific context).

**Acceptable fallback**:
1. Detect at startup: main Claude checks its version (`claude --version` or native presence of the `SendMessage` tool)
2. If `< 2.1.139`: route via the Task tool with an **enriched prompt** that includes the recap of relevant conversational context (instead of SendMessage which wakes a dormant agent). Cost: re-bootstrapping the sub-agent each turn, but scoping coherence preserved.
3. Recommend the user **update Claude Code** (`claude --upgrade` or reinstall) to benefit from the real SendMessage and R007 at its optimal.

**Anti-pattern within this fallback**: main Claude answering ITSELF (without dispatch) while imitating the Lead. Even in degraded mode, keep dispatching via Task (loss of SendMessage ≠ abandoning the sub-agent pattern).

### Anti-pattern

❌ Main Claude answering a scoping follow-up itself while imitating the Lead without routing via SendMessage (or Task as fallback). The user loses the guardrails, the persistent memory, and the orchestration coherence.

---

## R008 — Guaranteed three-layer session close

```yaml
---
id: R008
type: rule
severity: high
domain: capitalization
status: active
version: 1.0
---
```

> **Note on severity (downgraded from `critical`)**: initially marked `critical`, downgraded to `high` because layer 2 (main Claude conversational detection) only **PROPOSES**, it does not execute. The cost of a false positive is nil (just a question), and the cost of a miss is mitigated by layers 1 and 3 (hooks). Reserve `critical` for rules whose violation actually breaks something (e.g. R005 non-reversible domain → mandatory draft).

### Rule

Every significant session MUST trigger capitalization (`/cloture-session` or equivalent) via **at least one of 3 defensive layers**:

1. **Layer 1 — Automatic SessionEnd hook** (`hooks/session-end.ps1`): if HANDOVER.md was not modified within the hour, write `pending-capitalization.md` to be read at the next SessionStart.

2. **Layer 2 — Main Claude semantic detection**: main Claude MUST propose `/cloture-session` when it detects a session-end signal OR a long-pause signal in the user message. **Semantic interpretation, not rigid list matching**. Indicator categories (non-exhaustive): farewell greetings (`"see you tomorrow"`, `"bye"`), tiredness/bedtime (`"going to bed"`, `"I'm off to sleep"`), conclusion (`"ok thanks"`, `"let's stop here"`, `"that's enough"`), deferred pause (`"until next time"`, `"later"`). The proposal is mandatory; execution depends on the user's OK. **Distinguish** in-flow politeness (`"thanks for this explanation"` mid-flow ≠ session end) from a real departure signal.

3. **Layer 3 — Post-inactivity marker** (`hooks/stop.ps1`): if activity ≥5 files modified but 0 registers updated → write `.claude/last-stop-reminder.md` to be read at the next startup.

### Why

This rule emerged from an empirical audit showing that nearly all core agents had their MEMORY frozen at their creation date, with no post-intervention update.

Without a triggered session close, the agent system (SOUL/MEMORY/USER/journal) is an **investment at a loss**: you pay the bootstrap cost at every dispatch (~5-10k tokens) without the learning benefit.

The three layers guarantee that **even if one layer fails, the other two catch up**.

### How to apply

#### For main Claude (layer 2 — the most critical because it is new)

On each user message received, **before answering**:
1. **Interpret semantically**: "Does this message look like a session-end or long-pause signal?" (vs matching a fixed list — the list is indicative, not exhaustive)
2. If a signal is detected → explicitly propose before continuing normally:
   *"I detect a session-end signal ('<excerpt of the message>'). Do you want me to run `/cloture-session` to capitalize this session (update agent MEMORY, HANDOVER, traffic-journal)? (yes / continue normally)"*
3. If the user says yes → invoke `/cloture-session`
4. Otherwise → continue the requested work

**Recommended mindset**: prefer a false positive (1 question for nothing) over a false negative (a missed close → uncapitalized MEMORY). The asymmetric cost justifies slightly aggressive detection.

#### For the hooks (layers 1 and 3)

Hooks are already in place under `hooks/`. If you modify these hooks, keep the non-blocking behavior (`exit 0` always, even on internal error) — a hook that blocks the session is worse than no hook.

### Limits

- Conversational triggers = heuristic. False positives are possible ("thanks for this explanation" ≠ session end). Mitigation: main Claude **proposes**, it does not execute directly.
- The SessionEnd hook only fires on explicit Claude Code shutdown (quit, exit). On crash or timeout → layer 3 (Stop) catches up.
- Agent MEMORY capitalization remains **opt-in on the agent side** (R009 documents the mechanism). R008 only guarantees that `/cloture-session` is invoked, not that each agent enriches itself.

### Anti-patterns

❌ A hook that blocks the session if capitalization is forgotten → worse than the omission
❌ Main Claude executing `/cloture-session` automatically without the user's OK → frustrating on a false positive
❌ Conversational detection only (without a hook fallback) → fragile

---

## R009 — Agent MEMORY scoped to 2 levels + shared cross-agent + dreamer + validator

```yaml
---
id: R009
type: rule
severity: high
domain: agent-memory
status: active
version: 2.1
---
```

> **Overview** — evolution v1 → v2 → v2.1:
>
> **v2**:
> - Project level removed (theoretical, 0 files in practice)
> - Added `_shared/MEMORY.md` cross-agent
> - `dreamer` agent (low-cost model) + `/dream` skill HITL (manual validation)
>
> **v2.1**:
> - Auto cadence 1×/day via session-start hook (>24h trigger)
> - Added `dream-validator` agent (between dreamer and apply)
> - No more user validation in auto mode (full trust + audits via `/metrics-report`)
> - `/dream manual` mode remains available for debug/review of deferred items

### Rule

A core Vibeforge agent's `MEMORY.md` is **scoped to 2 levels** + one shared cross-agent file:

1. **Shared cross-agent**: `agent-contexts/_shared/MEMORY.md` — cross-cutting patterns shared by ALL agents (common tech stack, cross-cutting constraints, cross-agent orchestration patterns). Loaded by ALL agents at bootstrap.
2. **Universal agent level**: `agent-contexts/<agent>/MEMORY.md` — cross-cutting patterns specific to THIS agent (style, conventions, its own anti-patterns). Loaded by the agent only.
3. **Lab agent level** (if cwd is in a lab): `<lab>/agent-contexts/<agent>/MEMORY.md` — patterns specific to the lab domain (GDPR for an HR lab, credibility tier for a watch lab). Loaded by the agent if the lab exists.

At bootstrap the agent **loads in parallel (multiple Read tool calls)**:
- Always: `_shared/MEMORY.md` + `<agent>/MEMORY.md` (universal)
- If in a lab: `<lab>/agent-contexts/<agent>/MEMORY.md` (silent skip if absent)

**The central mechanism is a 3-stage pipeline** (v2.1):

1. **`vibeforge-dreamer` (low-cost model)**: proposes MEMORY updates in `pending-updates.md`. Strict MEMORY scope (not registers).

2. **`dream-validator` (judgment model)**: reads `pending-updates.md`, applies 3 grids (reject/apply/defer), writes `decision-<ts>.md`. Automatic quality filter without human intervention.

3. **`/dream` skill**: auto-applies the `apply` items, logs the `reject` items, preserves the `defer` items for a later `/dream manual`. Appends a `kind:"dream_run"` event to metrics.

**Auto cadence**:
- The `session-start.ps1` hook detects >24h since `last-dream-ts.txt` + activity ≥1 recent commit
- Writes `.claude/dream-auto-pending.md`
- Main Claude reads it (CLAUDE.md bootstrap step) → invokes `/dream`
- The full pipeline runs without user validation
- Periodic audits via `/metrics-report --focus=memory-consolidation`

**Manual `/dream manual` mode** available for debug/review of deferred proposals.

**If the dreamer detects candidate learnings/rules patterns** → a `suggestions_traffic_controller` section (signal-only). `/dream` surfaces the suggestion (run `/traffic-controller scan all` when desired). It does not touch the registers.

### Why

**Problem measured empirically**:
- Nearly all core agents had their universal MEMORY **frozen at bootstrap date**, with no post-intervention update
- 0 project-scope `<project>/agent-contexts/` files exist (the project level was purely theoretical)
- No automatic post-session consolidation mechanism (the equivalent of a sleeptime agent was missing)
- The `learnings.md` / `rules.md` registers are also not auto-updated (manual via `/promote-learning` or `traffic-controller`, rarely invoked)

**Benefit of 2 levels + shared + dreamer**:
- The agent loads fewer files (removal of the redundant project level)
- `_shared` lets you capitalize truly cross-agent patterns (stack versions, path conventions) without duplicating in each agent MEMORY
- The dreamer fills the main gap: automatic consolidation without depending on the agent's manual discipline at end of session
- The dreamer scopes its output to both registers AND MEMORY → addresses both problems at once
- Target cadence: `/dream` 2-3×/week or via a nudge hook after N sessions

### How to apply

#### Each agent's bootstrap

```markdown
## Scoped MEMORY bootstrap (R009 v2)

At startup, load in parallel (multiple Read calls):
1. `<workspace>/agent-contexts/_shared/MEMORY.md` (always present)
2. `<workspace>/agent-contexts/<self>/MEMORY.md` (always present)
3. If `<cwd>` is in a lab (presence of `<cwd>/agent-contexts/`):
   `<lab-root>/agent-contexts/<self>/MEMORY.md` (silent skip if absent)
```

#### Updating MEMORY — delegation to the dreamer

At the end of a significant session, **the agent NO LONGER writes its MEMORY itself** (except in exceptional cases — a critical ADR for the project). Default pattern:
1. The agent appends a dated block to its `journal.md` (chronological)
2. The operator (or a nudge hook) invokes `/dream` 1-3 times per week
3. The dreamer reads the journals + diffs and proposes MEMORY updates
4. The operator validates → `/dream` applies

**Exception**: if the agent identifies a locked decision during the session (e.g. "Stack locked: Next 14"), it MAY write directly to its lab MEMORY (never shared, never universal by default).

#### Promotion criteria (managed by the dreamer)

- **lab → universal**: a pattern that appeared in 2 different labs (same agent) → the dreamer proposes
- **universal → shared**: a pattern that appeared in 2 different agents (regardless of lab) → the dreamer proposes
- **Anti-inflation shared**: `_shared/MEMORY.md` ≤300 words strict, with delimited sections (cf. `_shared/README.md`)

### Limits

- The dreamer's proposals are not perfect. **Always validate** via `/dream` when in manual mode. No automatic apply in manual mode.
- The initial `_shared/MEMORY.md` is seeded minimally (stack versions, path conventions). It grows organically via dreamer promotions.
- The agent may write directly to lab MEMORY in case of a critical session ADR (documented exception). Universal and shared remain dreamer-only.

### Anti-patterns

- ❌ Writing everything at the shared level by default → shared MEMORY becomes a mess (agent forgets to scope). The dreamer must reject non-cross-agent patterns.
- ❌ Writing everything at the universal agent level → universal polluted with domain constraints
- ❌ Skipping the dreamer to write directly at the shared level → bypassing R009 v2
- ❌ Running `/dream` every session → costly and noisy (target cadence: 2-3×/week)
- ❌ Treating `pending-updates.md` as "apply as-is" without review — the dreamer makes suggestions
- ❌ Massive "migrate all agents in one session" refactor → breaks the method (cf. R005 — draft state for irreversible)
- ❌ Creating a project level after v2 → permanently abandoned, redundant with the meta-project
- ❌ **Widening the dreamer's scope to the registers (learnings/rules/bdr/eval)** → overlap with `traffic-controller`. The dreamer stays on MEMORY, the traffic-controller stays on registers.

### See also

- `doctrine/13-memory-scoping.md` — detailed v2 doctrine
- `agents/dreamer.md` — the consolidation agent
- `skills/dream/SKILL.md` — the validation workflow
- `agent-contexts/_shared/README.md` — shared writing convention
- `agent-contexts/_shared/MEMORY.md` — current shared state

---

## R010 — 3+ failed fix attempts on the same symptom → mandatory architecture pivot (stop patching)

```yaml
---
id: R010
type: rule
severity: high
domain: meta-method / debugging-workflow / architecture-decision
status: active
version: 1.0
---
```

### Rule

For any bug, behavioral failure, or persistent symptom that remains after **≥3 fix attempts on the same surface** (same file, same approach, same root-cause hypothesis), an architecture pivot becomes **mandatory**. It is forbidden to keep patching.

**Strict counter**:

| Attempt | Action |
|---|---|
| 1st fix fails | Test quickly, review if obvious |
| **2nd fix fails** | **Invoke `superpowers:systematic-debugging`** |
| **3rd fix fails** | **STOP** — mandatory architecture pivot decision, explicit capitalization |

### Why

This rule emerged from a real incident: a low-cost-model sub-agent that silently failed to see some of its tools. The bug was patched empirically several times over ~24h without questioning the architecture:

- Test #1 failed. Empirical diagnosis without method: "maybe the absolute vs relative palette" → patch → pushed without verification.
- Test #2 failed. Still empirical: a main-Claude workaround.
- Test #3 failed. This time `superpowers:systematic-debugging` was invoked → discovered several stacked root causes → fixed the syntax to simple names.
- Test #4 (post-restart + fix) → STILL FAILING. The fix was not enough — the low-cost model still did not see the tools.
- Finally: an **architecture pivot** — the low-cost sub-agent was DEPRECATED, the main Claude became the empirical executor.

**Observed cost of patching without a pivot**:
- 4 failed fix attempts over ~24h
- Doctrine partially corrupted (a learning marked "open" with the wrong root cause)
- Stacked patches (double pattern) obscuring the palette
- The bug capitalized as 5 successive learnings

**Observed gain after the pivot**:
- Bug instantly resolved (main Claude sees all its native tools)
- The pipeline functional on the first try
- A single capitalization learning + a clean deprecation

**Underlying meta-principle**: *"If 3+ fixes failed: STOP and question the architecture"* — official `superpowers:systematic-debugging` doc. Empirically validated within Vibeforge.

### How to apply

#### For main Claude (sub-agent orchestrator)

**Explicitly count** the number of fix attempts on the same symptom. As soon as **2 consecutive failures** → invoke `superpowers:systematic-debugging` BEFORE the 3rd fix. As soon as **3 consecutive failures** → announce the pivot and propose it to the operator.

**Red flag to watch**: *"My previous fix didn't work, I'll try something else"* without method → STOP. That is the signal to invoke systematic-debugging.

#### For Vibeforge sub-agents

Same — the counter is maintained in the session journal. On the 3rd failure, explicit output: *"R010 triggered: 3 fix attempts failed on <symptom>. Architecture pivot needed. Pivot hypotheses: <list>. Requesting operator validation."*

#### For humans

Same rule. If a bug needs more than 3 patches, it is an architecture signal, not a normal bug. The cost of the pivot is almost always lower than 5+ more patches.

#### Mandatory capitalization

After an R010-driven pivot, **systematically capitalize** a meta-learning of the form:
- Initial architecture = X (historical reason)
- Symptom = Y (bug description)
- Patches attempted = [N1, N2, N3] (why each failed)
- Chosen pivot = Z (new architecture)
- Pivot reason = root cause inaccessible at the original surface

### Limits / counter-examples

- **Trivial bugs resolved in 3 clean iterations** (each fixing a different aspect): not R010 scope. R010 targets the "3 fixes on the same root-cause hypothesis" pattern, not "3 fixes on 3 different root causes".
- **External bugs (upstream SDK, buggy dependency)**: R010 may trigger a pivot to an alternative dependency or a documented workaround, not necessarily an internal redesign.
- **Stacked-root-cause case**: if each fix reveals a new stacked root cause, that is **systematic-debugging investigation**, not blind patching. R010 distinguishes stacking root causes (acceptable) from surface patching (forbidden).

### Anti-patterns to avoid

- ❌ *"One more attempt, I'm almost there"* after 3 failures — a classic signal of attachment to the initial architecture
- ❌ Stacking patches without capitalizing the tested hypotheses — loss of traceability
- ❌ Skipping systematic-debugging on the 2nd attempt to "save time" — near-guaranteed cost down the line
- ❌ An architecture pivot without capitalizing the meta-learning — the next session falls into the same trap
- ❌ Treating "the LLM eventually got there" as a success — it is often a fragile patch that will re-break

### See also

- R005 (draft state for irreversible — analogous discipline for structuring risky actions)
- Superpowers `systematic-debugging` (the skill to invoke upstream of R010)

---

## R012 — Sub-agent frontmatter: `tools` AND `disallowedTools` using simple names only

```yaml
---
id: R012
type: rule
severity: critical
domain: agent-frontmatter / sdk / plugin-architecture
status: active
version: 1.0
---
```

### Rule

Every Vibeforge sub-agent frontmatter (files `<plugin>/agents/<agent>.md` and `<lab>/.claude/agents/<agent>.md`) MUST list tools using **simple names only**, both in `tools:` AND in `disallowedTools:`. The `Tool(pattern)` syntax (with parentheses + path pattern) is **forbidden** on both sides.

✅ **Allowed**:
```yaml
tools: Read, Grep, Glob, Write, Edit, Bash
disallowedTools: Task, WebSearch, WebFetch
```

❌ **Forbidden (silently blocks the tool)**:
```yaml
tools: Read, Grep, Bash(git log:*), Write(agent-contexts/**)
disallowedTools: Bash, Task, Write(../../**), Write(.claude/**)
```

### Why

**Documented double root cause**:

1. A `Tool(pattern)` pattern in `tools:` is interpreted by the SDK as a permission rule (settings.json allowlist style), not as exposure. Result: the tool does NOT appear in the agent's runtime palette despite being declared.

2. A `Tool(pattern)` pattern in `disallowedTools:` triggers a cautious SDK fallback = "deny the whole tool", not a scope on the pattern. Result: the tool is silently disabled, even if it appears in `tools:`.

**Massive impact observed**: a batch audit of 19 agents all carrying the same anti-pattern. Silent pattern: the agents appear to work but fail silently when they try to use the blocked tool. The bug is typically detected only during a critical Write in a live session.

A **"massive recurrence" exception** was applied to relax the usual stability criterion: 19 agents affected in 24h + a silent critical bug = immediate promotion justified.

**The effective scope** (limiting where the agent can write) must be guaranteed by:
- The system prompt (SOUL/USER) that explicitly STATES the scope
- The native Claude Code permission system (settings.json)
- NOT by the patterns in the sub-agent frontmatter (broken)

### How to apply

#### Creating a new agent

- The `/customize` wizard MUST validate that no `Tool(pattern)` appears in `tools:` or `disallowedTools:` (automatic enforcement)
- Agent onboarding doc: an R012-compliant frontmatter example
- Write/Edit scope expressed in the SOUL and/or USER prompt, not in the frontmatter

#### Auditing existing agents (check script)

```powershell
# Scan all agents for the R012 anti-pattern
$agents = Get-ChildItem -Recurse -Filter "*.md" -Path @(
  "<workspace>/vibeforge/agents",
  "<workspace>/lab-*/.claude/agents"
)

foreach ($agent in $agents) {
  $frontmatter = (Get-Content $agent.FullName -Raw) -split '---' | Select-Object -Index 1
  if ($frontmatter -match '(tools|disallowedTools):.*\w+\(') {
    Write-Warning "R012 anti-pattern detected: $($agent.FullName)"
  }
}
```

#### Diagnosing an agent that does not work

Mandatory order (sub-agent frontmatter bug family):
1. Was Claude Code restarted since the last edit?
2. `Tool(pattern)` syntax in `tools:`? (→ R012)
3. Valid and current model_id?
4. `Tool(...)` patterns in `disallowedTools:`? (→ R012)
5. A specific model with current SDK bugs? (architecture pivot if encountered)

### Limits / counter-examples

- **settings.json permissions**: the `Tool(pattern)` syntax is valid in `settings.json` (`permissions.allow`/`permissions.deny`). R012 concerns ONLY the sub-agent frontmatter.
- **Effective per-path restriction**: impossible at the sub-agent frontmatter level. If truly needed, options:
  1. Strict system prompt + audit trail
  2. An interceptor wrapper on the main Claude side that filters tool calls
  3. A sub-agent dispatched from main Claude that validates paths post-hoc

### Anti-patterns to avoid

- ❌ `tools: Bash(git log:*), Write(agent-contexts/**)` — tools absent from the runtime palette
- ❌ `disallowedTools: Write(../../**)` — Write entirely blocked
- ❌ Mixing pattern + simple: `tools: Read, Grep, Write(corpus/**), Edit` — unpredictable disabling
- ❌ Thinking `Tool(pattern)` works differently in tools vs disallowedTools — both are broken
- ❌ Relying on frontmatter patterns for Write security — use the prompt + permission system

---

## R013 — Frame 0 scoping: mandatory mature upstream OSS audit before building a framework/runtime

```yaml
---
id: R013
type: rule
severity: high
domain: scoping / architecture / strategy
status: active
version: 1.0
---
```

### Rule

Every Vibeforge project (internal, client, personal) that includes a **"framework / runtime / technical infra" component** (agent orchestrator, pipeline, execution runtime, custom framework) MUST be preceded by an **upstream OSS audit of ≥1h of research** BEFORE any decision to build from scratch.

**The final PRD MUST document**:

1. **Is there a mature OSS** (MIT/Apache/equivalent) that covers **≥80% of the need**?
2. The list of OSS audited + assessed coverage (in %)
3. A reasoned decision: **compose** (build on top) / **fork** (adapt) / **rebuild** (justify the 80%+ gap)

Without a documented OSS audit → incomplete scoping → reviewer-prd blocks (R001).

### Why

**Primary empirical source**: a real project initially estimated at 6-12 months to build from scratch. An upstream OSS audit discovered a mature MIT-licensed project whose core + plugins covered ~100% of the runtime + multi-model + multi-channel + native cron. Strategic pivot: **compose on top** instead of reimplementing. Revised estimate: 4-8 weeks. **Net gain ~5 months.**

**Industry strategic pattern**: Vercel on Next.js, Supabase on Postgres. Successful products add a **DX + UI + method layer** on top of mature commoditized infra.

**Documented inverse risk**: NIH syndrome (Not Invented Here). Engineer ego "we can do better ourselves" — often true technically, false economically.

### How to apply

#### During Phase 1 — Scoping (doctrine 12)

The `business-analyst` asks the discovery questions:
- *"What is this project's runtime / framework / infra need?"*
- *"Is there a mature OSS that covers this need?"*

The `architecte` runs the upstream OSS audit (≥1h research minimum):
- Searches GitHub trending + Awesome lists + recent papers
- Assesses maturity (commits/stars/issues/releases/license)
- Assesses need coverage (in % of the PRD)
- Documents it in `<meta-project>/docs/audit-oss-upstream.md`

#### Decision matrix

| OSS coverage | Default decision |
|---|---|
| ≥80% | **Compose** on top, do not rebuild |
| 60-80% | Explicit **cost-benefit evaluation**: fork vs compose vs rebuild |
| <60% | Continue normal scoping (4 doctrine patterns) — build justified |

#### During Phase 2 — PRD validation (R001)

The `reviewer-prd` checks:
- An "Upstream OSS audit" section present in the PRD
- The list of audited OSS documented
- A reasoned decision (compose/fork/rebuild) with justification
- If rebuild → justification of the ≥20% gap with the most mature OSS

If criteria are absent → **PRD NOT OK** (R001), return to scoping.

### Concrete example

**Before audit**: *"We build a custom agent runtime"* — estimate 6-12 months.

**After audit (1h research)**:
| OSS | License | Maturity | Coverage | Decision |
|---|---|---|---|---|
| Mature agent runtime (MIT) | MIT | core + plugins | ~100% runtime + multi-model + cron | **Compose** |
| Alternative framework A | MIT | mature | ~70% | Evaluated, discarded (vendor dependency) |
| Alternative framework B | MIT | mature | ~60% | Evaluated, discarded (too low-level) |

**Final decision**: compose on the mature runtime. Net gain ~5 months. Vibeforge focuses on what differentiates it (method + UI + scoping integration).

### Limits / counter-examples

- **Project with no framework/runtime component** (e.g. pure business backend, pure frontend, one-shot script): R013 does not apply
- **No mature OSS exists**: R013 is satisfied by the audit documenting "no OSS ≥60%". Not a blocker.
- **License-incompatible OSS** (GPL/AGPL blocking for a proprietary product): the audit must mention it, a justified rebuild decision
- **Exploration / R&D project**: the audit can be lightened (30min instead of 1h), but document it anyway

### Anti-patterns to avoid

- ❌ *"Let's start coding, we'll see if we hit an OSS later"* — near-guaranteed waste of time
- ❌ *"OSS X is too hyped / too new, we avoid it"* without factual maturity justification
- ❌ *"The client wants custom"* without comparing to OSS composition (the client often wants "something that works", not "custom")
- ❌ A rushed audit (15min Google) — not a real audit, must be ≥1h with docs/repos read
- ❌ Confusing "compose" with "vendor-lock" — an MIT OSS is NOT a vendor-lock (forking is possible)

### See also

- R001 (PRD coverage — R013 adds to the verified criteria)
- `doctrine/14-architecture-livraison-agent.md` § Frame 0 prerequisite (doctrinal frame)

---

## R014 — Upfront multi-sprint scoping when an upstream strategic backlog exists

```yaml
---
id: R014
type: rule
severity: high
domain: scoping / orchestration / workflow
status: active
version: 1.0
---
```

### Rule

When a project has an **upstream strategic backlog** (a multi-sprint v1 plan doc, an S0-Sn roadmap already written in `backlog/<project>-strategy-*`, or equivalent), the initial scoping MUST be **upfront multi-sprint**, not derived scope-by-scope:

- The **BA produces ONE PRD** that covers ALL planned sprints (S0-Sn).
- The **architect produces ONE end-to-end architecture** (stack locked for the entire v1 phase).
- The **audits** cover **the entire v1 phase**.
- The **prompt-engineer compiles ONE prompt for S0 only** at the start. Subsequent sprints will have their prompts generated at launch, from the already-locked PRD + architecture.

For subsequent sprints (S1, S2, ..., Sn), **only `prompt-engineer` + `reviewer-prd` are replayed** — not a new BA → architecture → audits cycle.

### Why

The default `/lead` workflow (BA → architect → audits → prompt-eng → reviewer-prd) is designed for **1 scoping = 1 sprint**. For multi-sprint projects documented upstream, this default forces re-scoping in a loop:

- **Cycle overload**: a real incident replayed all 6 phases even though the upstream plan already contained the S0-S11 plan — an upfront S0 scoping would have sufficed.
- **Scope-by-scope PRD** creates inconsistencies between sprints (e.g. decisions locked for S0 have to be re-affirmed and extended sprint by sprint).
- **Cost**: ~2-3× more in tokens/time vs 1 broad scoping + N targeted prompts.

Upfront scoping also enables:
- **Coherent global decisions** (stack, integration path, path conventions) made ONCE.
- **Early detection of inter-sprint dependencies** (e.g. a later sprint depends on an earlier one's backend → to be clarified in the initial scoping, not on arrival).
- **End-to-end visibility** for the sponsor: estimate the whole v1, not roughly sprint by sprint.

### How to apply

**At the initial Lead invocation for a new project**:

1. The Lead checks for the existence of an **upstream strategic backlog** (`backlog/<project>-strategy-*`, or equivalent in the lab).
2. **If YES** → mandatory multi-sprint scoping:
   - Explicit BA brief: *"PRD covers S0 to Sn (per the upstream backlog). No scope restricted to one sprint."*
   - Explicit architect brief: *"Stack locked for the entire v1 phase, not just S0."*
   - Audits cover the entire v1 phase.
3. **If NO** (a project without upstream backlog, exploratory or one-shot) → per-sprint scoping acceptable (current Vibeforge default).

**At the launch of each sprint after S0**:

1. Verify the sprint is covered by the upfront multi-sprint PRD.
2. **If YES** → invoke **ONLY** `prompt-engineer` + `reviewer-prd` (no re-BA, no re-architecture).
3. **If NO** (the sprint brings a truly new, unplanned scope, e.g. a pivot after S0 learning) → a **light** re-scoping (BA extension + targeted audits) — but this is the exception, not the rule.

### Limits / counter-examples

- **A genuinely complex project where S0 = viability check**: for work where S0 must validate infra that could invalidate the whole plan (e.g. Frame 0 OSS not yet empirically confirmed), you may start with an isolated S0 scoping, **BUT** the operator must explicitly declare "iterative mode" in a BDR at the start, with justification.
- **An upstream backlog that turns out to be wrong after S0**: if S0 learnings invalidate the upstream plan, mandatory multi-sprint re-scoping at that point, not sprint by sprint.
- **Very simple projects (1-2 planned sprints)**: upfront scoping can be oversized. The standard 1-sprint workflow suffices.

### Anti-patterns to avoid

- ❌ Deriving a "S0-only scope" PRD then "S0+S1 scope" then "S0+S1+S2 scope" sprint by sprint **when a multi-sprint plan already exists upstream**.
- ❌ Re-doing BA + architecture + audits at each sprint **without a "truly new scope" justification**.
- ❌ Considering the `/lead` default (1 sprint) = good practice for ALL projects (it suits simple 1-sprint work).
- ❌ A Lead that dives into the 6-phase cycle without **first questioning**: "is there an upstream strategic backlog? If so, upfront mode, not iterative mode."

### See also

- R001 (PRD coverage) — R014 complements R001 by stating *when* the PRD must cover what.
- R013 (Frame 0 OSS audit) — often a trigger for having an upstream strategic backlog that justifies R014.
- `doctrine/12-workflow-projet.md` (project workflow).

---

## R015 — Mandatory bootstrap ≤ 5 items + Edit in the palette of producer agents

```yaml
---
id: R015
type: rule
severity: high
domain: agents / plugin / bootstrap / palette
status: active
version: 1.0
---
```

### Rule

**1. Mandatory agent bootstrap ≤ 5 items.** Every Vibeforge agent (plugin or local lab) MUST have a mandatory bootstrap in its agent def `.md` limited to **5 critical items maximum**. The rest = on-demand per mission (the invoker provides the paths in the mission contract).

**The 5 typical critical items**:
1. `agent-contexts/<agent>/MEMORY.md` (personal historical knowledge)
2. `<workspace>/registres/rules.md` (relevant global rules)
3. `<lab>/CLAUDE.md` (lab constitution if invoked in a lab)
4. `<project>/HANDOVER.md` (project state if invoked on a project)
5. 1 mission-specific source (the relevant PRD section OR current architecture OR equivalent)

The rest (SOUL/USER, doctrine, eval, upstream backlog, etc.) = **on-demand**: the agent reads them only if the mission leads it there or if the invoker lists them in the contract.

**2. Mandatory Edit in the palette of producer agents.** Agents that produce or amend files (PRD, architecture, prompt, audit, validation note) MUST have `Edit` in `tools` AND NOT in `disallowedTools`:
- `business-analyst` ✅
- `architecte` ✅
- `prompt-engineer` ✅
- Audit agents (may want to update an audit-v2 → v3)
- Other future producer agents

Justification: without Edit, the agent must either Write the whole file (overwrites it — risk of breaking concurrent changes), or ask the main session to patch (= costly workaround). Edit allows targeted amendments.

### Why

**Empirical over several scoping sprints**:
- Bootstrap of 11-16 items → sub-agents saturate the tool budget within 5-7 turns on reads → premature termination without writing the deliverable
- The workaround pattern "SKIP YOUR BOOTSTRAP + inline context" became mandatory in EVERY mission contract
- Cost: ~30% of contract tokens spent explaining the workaround
- A BA without Edit → the main session had to patch the PRD itself

**Cost of continuing as before**: process friction at every dispatch, repeated workarounds, cognitive load on the dispatcher.

**R015 gain**: a light bootstrap by default = no workaround to write. Edit available = targeted amendments without rewriting. The mission contract becomes pure again (mission + sources + expected deliverable).

### How to apply

**For lab-specific agents** (`<lab>/.claude/agents/*.md`):
- The agent that creates agents (`lab-architect`) must apply R015 by default.
- Audit of existing lab agents: if bootstrap > 5 → patch.

**For Vibeforge plugin agents** (`.../agents/*.md`):
- Local patch of the plugin cache — durable until `claude plugin update`.
- Document in user memory that the patch is local (to redo after a plugin update OR push a marketplace PR to do it upstream).

**For future agents**: every new agent `.md` MUST respect R015 from creation.

### Limits / counter-examples

- **Read-only agents** (e.g. `reviewer-prd`, `traffic-controller`) — no need for Edit, just Read + Write. R015 §2 does not apply. R015 §1 (light bootstrap) always applies.
- **Orchestration agents** (e.g. `lead`) — may have a broader bootstrap because they orchestrate (need broad context to dispatch correctly). But ≤ 7 items max recommended.
- **If a mission truly needs 11+ docs read**: the invoker lists them in the mission contract, and the contract can provide a compact inline summary.

### Anti-patterns to avoid

- ❌ An exhaustive "read the whole project" bootstrap (= a recipe for saturation)
- ❌ Removing Edit "for safety" without an alternative (= chronic workaround)
- ❌ Patching an agent def without documenting it in user memory (= lost at the next plugin update with no trace)
- ❌ Recreating the "SKIP BOOTSTRAP" workaround in every contract when it could have been fixed once and for all

### See also

- R010 (3 fix attempts → architecture pivot) — R015 = architecture pivot after repeated workaround failures

---

## R016 — Agent MEMORY cap ≤ 500 words (HARD)

```yaml
---
id: R016
type: rule
severity: medium
domain: agents / memory / scoping / bootstrap-cost
status: active
version: 1.0
---
```

### Rule

**HARD cap**: every `MEMORY.md` under `agent-contexts/<agent>/` ≤ **500 words**.

### Context

R009 caps `_shared/MEMORY.md` at 300 words. No cap existed for agent-specific MEMORY files. An audit found drifts: agent MEMORY files reaching 1800-2300 words, loaded at every invocation of the sub-agent, sometimes pre-filled at creation and never pruned.

An agent MEMORY that grows without a cap = a growing re-bootstrap cost at every invocation of the sub-agent, with no demonstrated value.

### Mechanism

- **`/dream` (validator)**: before any write to an agent MEMORY, check the post-write word count. If > 500 → REJECT and defer the entry.
- **Mandatory pruning before write**: when an agent (or main Claude) wants to add an entry and MEMORY is already at ≥ 450 words, **prune the oldest / least-cited entries** BEFORE adding.
- **Archive**: pruned entries go to `agent-contexts/<agent>/journal.md` (append-only). Lets you find the history without weighing on the bootstrap.

### Verification (CI / hook)

The `session-start.ps1` hook can be extended to scan agent MEMORY files and log `[memory-bloat] <agent> = <words>` in .claude/logs/ when > 450 words (early warning before the HARD cap).

### Why not 300 (like `_shared`)?

`_shared` is loaded by ALL agents → cost ×N. An agent-specific MEMORY is loaded only when that agent is invoked. 500 words leaves room for the role's recurring patterns without blowing up the bootstrap.

---

## R017 — Skills auto-created by sub-agents on mission: skill-curator mandatory

```yaml
---
id: R017
type: rule
severity: low
domain: agents / skills / self-improvement / governance
status: active
version: 1.0
---
```

### Context

A doctrine rule stated "You can write skills ONLY after validation by `skill-curator`". An audit found several SKILL.md created but 0 skill-curator invocations. Diagnosis: the "You" of that rule targeted a *Vibeforge sub-agent on mission* (a scenario that had not occurred in practice), not the human operator in method-dev mode.

### Rule

**Strict scope**: R017 applies to the following scenario only.

- **A Vibeforge sub-agent** (lead, architecte, ux, prompt-engineer, business-analyst, code-reviewer, devil-advocate, etc.) **on mission via the Task tool or a slash command** identifies a missing skill for its domain.
- It prepares a draft but **does NOT do a direct Write** into `skills/` or `agent-contexts/<other-agent>/skills/`.
- It **mandatorily invokes skill-curator** via the Task tool (`subagent_type: "skill-curator"`) for validation of the 5 checks: duplicate, overlap, granularity, format, relevance.
- It may write into `agent-contexts/<self>/skills/` ONLY after the skill-curator OK.

### Out of scope

- Creation of root-method skills by the operator in dev mode (auditability via git diff, no runtime gate needed).
- Modification of an existing skill (handled by the owning agent or the operator).
- Creation of lab skills by the operator (handled by the lab-architect or the operator).

### Why `severity: low`

A rare scenario in practice. A useful guardrail for the future when an agent really starts proposing a skill. But not worth hardening the workflow (a blocking hook) while it remains theoretical.

---

## R018 — Persistent scoping memory (MEMORY-cadrage.md)

```yaml
---
id: R018
type: rule
severity: high
domain: scoping / memory / compaction / meta-projects
status: active
version: 1.0
---
```

### Context

The Vibeforge method is solid up to the build. But a long scoping session does not die when the build starts: it keeps living (daily feedback, adjustments, new needs), it swells, compaction strikes, and all the "why" context goes up in smoke because it was never written to disk first. This rule emerged from a real incident where a scoping session (100+ turns, several compactions) ended up with zero memory of the why and the roadmap. Costly reconstruction after the fact.

### Rule

Every meta-project maintains a **`MEMORY-cadrage.md`** file at its root: the long-term brain of the scoping, distinct from the HANDOVER.

- **HANDOVER.md** = the latest state, volatile, overwritten each session ("where we stopped, what to do next").
- **MEMORY-cadrage.md** = accumulated knowledge that must NEVER be lost, cumulative ("why the project, roadmap of sessions, structuring decisions, technical facts, uncertainty zones").

The two memories are **complementary**. The conversation memory remains the live working memory (fast, rich, used to the fullest while it is there). `MEMORY-cadrage.md` is the **durable foundation** that survives compactions. The rule is not to ignore the conversation, but to NEVER DEPEND on it alone: everything critical is ALSO written to disk, continuously, so a compaction never loses the essentials.

**400-line cap (HARD) + smart compaction.** On a large scoping, `MEMORY-cadrage.md` grows fast; full-read at every bootstrap, it is expensive. Cap = **400 lines**. Beyond that, NO archiving: `/save-cadrage` does a **smart compaction** in place (closed sessions summarized to one line, redundant/superseded decisions merged, deduplicated facts, resolved uncertainties removed), preserving all critical signal. This is R016 (agent MEMORY pruning) applied to scoping. **Tiered reading**: a `## SUMMARY` at the top, read first at startup with the core (why, current roadmap, uncertainties); detailed sections are grepped on demand. The pre-tool-use hook watches `MEMORY-cadrage.md` and blocks full-read beyond 500 lines (backstop).

### How to apply

- **At startup**: the meta-project bootstrap (CLAUDE.md) lists `MEMORY-cadrage.md` as a priority read. Every session reloads from disk.
- **During the session**: at each structuring decision, each daily/stakeholder handled, each new business need, update `MEMORY-cadrage.md` (reflex, or via `/save-cadrage`).
- **At end of turn (ACTIVE nudge)**: the `Stop` hook (hooks/stop.ps1) automatically detects (scoping context + significant activity + `MEMORY-cadrage.md` not flushed for >10 min) and **blocks the stop** by injecting the instruction to run `/save-cadrage` (`decision: block` + `reason`). The agent obeys, saves, then re-stops; this 2nd stop has `stop_hook_active=true` (the official Claude Code anti-loop guard), so no more block. This is the mechanism that means you do not have to think about it.
- **Before a compaction**: the `PreCompact` hook (hooks/pre-compact.ps1) reminds you to flush. When the trigger threshold is crossed in a scoping context, the harness can run `/save-cadrage` THEN `/compact` automatically.
- **At end of session**: `/save-cadrage` then `/cloture-session`.
- **Last resort** (memory lost anyway): `/recover-cadrage <session-id>` reconstructs from the transcript.

### Why

The cost of a `/recover-cadrage` (re-reading a 10+ MB transcript, even condensed) is incomparable to the cost of a regular `/save-cadrage` (a few targeted edits). The rule moves the effort upstream, where it is nearly free, and removes the risk of a hard loss of strategic information.

### Limits / counter-examples

- **Short projects** (1-2 sessions, no recurring daily): a HANDOVER suffices, `MEMORY-cadrage.md` can stay skeletal. The rule targets long, living scoping sessions.
- **R009 does not cover this**: R009 manages AGENT memory (cross-cutting learning). R018 manages a PROJECT's memory (the why/roadmap of a piece of work). Complementary, not redundant.

### Anti-patterns to avoid

- ❌ Keeping everything in the conversation and counting on compaction to "summarize" (it compresses blindly, without knowing what is critical).
- ❌ Writing secrets / tokens / client data in `MEMORY-cadrage.md` (aggregated counts only).
- ❌ Overwriting `MEMORY-cadrage.md` instead of merging (it is cumulative).
- ❌ Confusing it with the HANDOVER.

### See also

- `skills/save-cadrage/SKILL.md` (active save)
- `skills/recover-cadrage/SKILL.md` (last-resort reconstruction)
- `hooks/pre-compact.ps1` (pre-compaction nudge)
- `templates/projet-meta.template/MEMORY-cadrage.md.tpl` (template)

---

## Format for future rules

When traffic-controller promotes a learning into a rule, it uses the following format:

```markdown
## R<NN> — <short title>

​```yaml
---
id: R<NN>
type: rule
severity: <low|medium|high|critical>
domain: <domain>
status: active
version: 1.0
---
​```

### Rule

<normative statement>

### Why

<rationale, generic>

### How to apply

<concrete steps>

### Limits / counter-examples

<when the rule does not apply>

### Anti-patterns to avoid

<what to avoid>
```
