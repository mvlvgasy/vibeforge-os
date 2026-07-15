# scripts/new-lab-standalone.ps1  (v1.3)
#
# v1.3 (2026-07-15, vibeforge-os v0.4): modular generation. -Modules "cadrage,contenu"
# vendors only the selected modules + transitive requires (resolve-modules.ps1,
# registry plugin/modules.json); mandatory modules (core) always ship. Default: all.
# Installed modules recorded in _method/modules-installed.json (hashed by the manifest).
#
# v1.2 (2026-07-14, vibeforge-os v0.3): writes _method/manifest.json at generation
# (sha256 of every vendored file, via build-manifest.ps1) -> drift detection
# (check-drift.ps1) and journaled upgrades (upgrade-lab.ps1 + migrations/).
# Generates a STANDALONE lab: frozen method embedded + FULL GOVERNANCE, zero external
# dependency (no plugin, no sibling clone). Doctrine frame 16.
#
# v1.1 (2026-07-04): a real-lab audit showed v1.0 vendored the skeleton (doctrine, rules,
# 9 agents, 3 skills) but NOT the immune system: capitalization (promote-*), memory
# consolidation (dream), session closure, framing memory (save-cadrage), lifecycle hooks,
# real indexing (CATALOG). v1.1 vendors EVERYTHING dynamically:
#   - ALL socle agents (+ _workers) and ALL skills (except new-lab, deprecated)
#   - hooks/*.ps1 + a wired .claude/settings.json (${CLAUDE_PROJECT_DIR})
#   - seeded living structure: metrics/, audits/, backlog/, registres/_archived/,
#     registres/rules.md and eval.md seeded from the socle (inherited section + a local
#     section for promotions -> _method stays frozen, the living layer is the lab's)
#   - the lab's CATALOG.md generated from vendored REALITY (zero ghost skills) via an
#     embedded tools/rebuild-catalog.ps1 the lab can re-run itself
#   - <workspace> ref rewriting: living -> lab root ; doctrine|scripts -> _method/
#
# SELF-VENDORING: the default socle source is THIS repo itself.
# ASCII-safe code (PowerShell 5.1). Generated .md content may contain UTF-8 accents.

[CmdletBinding()]
param(
    [string]$Name = "",
    [string]$Category = "custom",
    [string]$Client = "",
    # Socle override: path to another vibeforge-os checkout. Default: THIS repo.
    [string]$SocleSource = "",
    # Destination root. Default: current directory.
    [string]$DestBase = "",
    [switch]$GitInit,
    [switch]$DryRun,
    # Module selection (v0.4): comma-separated ids from plugin/modules.json, or "all" (default).
    # Mandatory modules + transitive requires are always added.
    [string]$Modules = "all"
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Socle skills NOT vendored
$SKILLS_EXCLUDED = @("new-lab")   # deprecated (the OS creates standalone labs only)
# Socle subtrees copied into _method/ (frozen reference)
$SOCLE_DIRS = @("registres", "doctrine", "templates", "scripts", "agent-contexts")
$SOCLE_FILES = @("CLAUDE.md", "DOCTRINE.md", "modules.json")

# === Validation ===
if (-not $Name) { Write-Error "Required argument: -Name <lab-name>."; exit 1 }
if ($Name -like "lab-*") { $Name = $Name.Substring(4) }
if ($Name -notmatch '^[a-z][a-z0-9-]{1,40}$') { Write-Error "Invalid name: '$Name' (kebab-case, 2-40 chars)."; exit 1 }
if ($Category -notmatch '^[a-z][a-z0-9-]{1,30}$') { Write-Error "Invalid category: '$Category'."; exit 1 }

$labName = "lab-$Name"
if (-not $DestBase) { $DestBase = (Get-Location).Path }
$labPath = Join-Path $DestBase $labName
$today = Get-Date -Format "yyyy-MM-dd"
if (Test-Path $labPath) { Write-Error "Lab '$labName' already exists at $labPath."; exit 1 }

# === Socle resolution (SELF by default) ===
if ($SocleSource) {
    if (-not (Test-Path $SocleSource)) { Write-Error "SocleSource not found: $SocleSource"; exit 1 }
    $socleRepo = $SocleSource
} else {
    $socleRepo = Split-Path $PSScriptRoot -Parent
}
$socleRoot = if (Test-Path (Join-Path $socleRepo "plugin")) { Join-Path $socleRepo "plugin" } else { $socleRepo }

# Traceability: git commit if available, else plugin.json version
$socleCommit = "unknown"
$socleId = "vibeforge-os"
$gitProbe = $socleRoot
while ($gitProbe -and -not (Test-Path (Join-Path $gitProbe ".git"))) {
    $parent = Split-Path $gitProbe -Parent
    if ($parent -eq $gitProbe) { $gitProbe = $null } else { $gitProbe = $parent }
}
if ($gitProbe) {
    try {
        $socleCommit = (git -C $gitProbe rev-parse --short HEAD 2>$null).Trim()
        $originUrl = (git -C $gitProbe remote get-url origin 2>$null)
        if ($originUrl) { $socleId = $originUrl.Trim() }
    } catch { }
} else {
    $pluginJson = Join-Path $socleRoot ".claude-plugin\plugin.json"
    if (Test-Path $pluginJson) {
        try {
            $pj = Get-Content $pluginJson -Raw -Encoding utf8 | ConvertFrom-Json
            $socleCommit = "plugin-v$($pj.version)"
        } catch { }
    }
}

$templateBase = Join-Path $socleRoot "templates\lab.template"
$displayDomain = (Get-Culture).TextInfo.ToTitleCase($Name.Replace("-", " "))
$variables = @{
    "{{LAB_NAME}}"       = $labName
    "{{LAB_DOMAIN}}"     = $displayDomain
    "{{LAB_CLIENT}}"     = $Client
    "{{LAB_CATEGORY}}"   = $Category
    "{{LAB_CREATED}}"    = $today
    "{{LAB_PARENT}}"     = "_method"
    "{{VIBEFORGE_PATH}}" = "_method"
}

Write-Host "=== /new-lab-standalone v1.2 : generating '$labName' (category: $Category) ===" -ForegroundColor Cyan
Write-Host "    Socle : $socleRoot ($socleCommit)" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $templateBase)) { Write-Error "Lab template not found in socle: $templateBase"; exit 1 }

# Dynamic socle inventory
$socleAgentFiles = Get-ChildItem (Join-Path $socleRoot "agents") -Filter *.md -File -ErrorAction SilentlyContinue
$socleWorkerFiles = Get-ChildItem (Join-Path $socleRoot "agents\_workers") -Filter *.md -File -ErrorAction SilentlyContinue
$socleSkillDirs = Get-ChildItem (Join-Path $socleRoot "skills") -Directory -ErrorAction SilentlyContinue | Where-Object { $SKILLS_EXCLUDED -notcontains $_.Name }
$socleHookFiles = Get-ChildItem (Join-Path $socleRoot "hooks") -Filter *.ps1 -File -ErrorAction SilentlyContinue

# === Module resolution (v0.4) — filters the inventory when -Modules is not "all" ===
$resolvedModules = $null
$resolverPath = Join-Path $PSScriptRoot "resolve-modules.ps1"
if (Test-Path $resolverPath) {
    $resolvedJson = & powershell.exe -ExecutionPolicy Bypass -File $resolverPath -Modules $Modules -PluginRoot $socleRoot
    if ($LASTEXITCODE -ne 0) { Write-Error "Module resolution failed for '-Modules $Modules' (see above)."; exit 1 }
    $resolvedModules = ($resolvedJson -join "`n") | ConvertFrom-Json
    $socleSkillDirs   = @($socleSkillDirs   | Where-Object { $resolvedModules.skills  -contains $_.Name })
    $socleAgentFiles  = @($socleAgentFiles  | Where-Object { $resolvedModules.agents  -contains $_.BaseName })
    $socleWorkerFiles = @($socleWorkerFiles | Where-Object { $_.Name -eq "README.md" -or $resolvedModules.workers -contains $_.BaseName })
} elseif ($Modules.Trim().ToLower() -ne "all") {
    Write-Error "-Modules requires resolve-modules.ps1 next to this script (not found)."; exit 1
}

# === DRY RUN ===
if ($DryRun) {
    Write-Host "DRY RUN -- preview:" -ForegroundColor Yellow
    Write-Host "  Lab path     : $labPath"
    Write-Host "  Socle source : $socleRoot"
    if ($resolvedModules) {
        Write-Host "  Modules      : $(($resolvedModules.modules.id) -join ', ') (selection '$Modules' + mandatory + requires)"
        Write-Host "  Vendored     : $($socleSkillDirs.Count) skills, $($socleAgentFiles.Count) agents, $(@($socleWorkerFiles | Where-Object Name -ne 'README.md').Count) workers,"
    } else {
        Write-Host "  Vendored     : ALL agents + workers, ALL skills except [$($SKILLS_EXCLUDED -join ', ')],"
    }
    Write-Host "                 hooks/*.ps1 + settings.json, living seeds (local rules/eval, metrics, audits),"
    Write-Host "                 real lab CATALOG + tools/rebuild-catalog.ps1."
    if ($GitInit) { Write-Host "  + Git init" }
    Write-Host ""
    Write-Host "No execution. Re-run without -DryRun to create." -ForegroundColor Yellow
    exit 0
}

# === Step 1/9: template ===
Write-Host "[1/9] Copying lab template..." -ForegroundColor Green
New-Item -Path $labPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "$templateBase\*" -Destination $labPath -Recurse -Force
Get-ChildItem -Path $labPath -Recurse -File -Filter "*.tpl" | ForEach-Object {
    Move-Item -Path $_.FullName -Destination ($_.FullName -replace '\.tpl$', '') -Force
}
$gitignoreTpl = Join-Path $labPath ".gitignore.tpl"
if (Test-Path $gitignoreTpl) { Move-Item $gitignoreTpl (Join-Path $labPath ".gitignore") -Force }

# === Step 2/9: _method/ socle ===
Write-Host "[2/9] Vendoring the _method/ socle..." -ForegroundColor Green
$methodPath = Join-Path $labPath "_method"
New-Item -Path $methodPath -ItemType Directory -Force | Out-Null
foreach ($f in $SOCLE_FILES) {
    $src = Join-Path $socleRoot $f
    if (Test-Path $src) { Copy-Item $src (Join-Path $methodPath $f) -Force }
}
foreach ($d in $SOCLE_DIRS) {
    $src = Join-Path $socleRoot $d
    if (Test-Path $src) { Copy-Item $src (Join-Path $methodPath $d) -Recurse -Force }
}
$methodReadme = @"
# _method/ - FROZEN governance socle

Copy of the public vibeforge-os method, vendored on $today by new-lab-standalone.ps1 v1.2.

This lab is STANDALONE (doctrine frame 16): no external dependency. Agents live in
.claude/agents/, skills in .claude/skills/, hooks in .claude/hooks/. The lab's LIVING
registers are at the lab root (registres/); _method/ is the frozen method reference.

Socle upgrade: regenerate _method/ from vibeforge-os (see VERSION). Do NOT hand-edit
these files (overwritten at upgrade).
"@
[System.IO.File]::WriteAllText((Join-Path $methodPath "README.md"), $methodReadme, $utf8NoBom)
$versionContent = @"
socle_source: $socleId
socle_commit: $socleCommit
vendored_on: $today
generator: new-lab-standalone.ps1 v1.2 (vibeforge-os)
"@
[System.IO.File]::WriteAllText((Join-Path $methodPath "VERSION"), $versionContent, $utf8NoBom)
# Installed modules (v0.4) — read by upgrade-lab/check-drift consumers and the future hub
if ($resolvedModules) {
    $modulesInstalled = [ordered]@{
        selected_on = $today
        selection   = $Modules
        modules     = $resolvedModules.modules
    }
    [System.IO.File]::WriteAllText((Join-Path $methodPath "modules-installed.json"), ($modulesInstalled | ConvertTo-Json -Depth 4), $utf8NoBom)
}

# === Step 3/9: ALL agents (+ workers) ===
Write-Host "[3/9] Vendoring ALL agents ($($socleAgentFiles.Count) + $($socleWorkerFiles.Count) workers)..." -ForegroundColor Green
$labAgentsDir = Join-Path $labPath ".claude\agents"
New-Item -Path $labAgentsDir -ItemType Directory -Force | Out-Null
foreach ($a in $socleAgentFiles) { Copy-Item $a.FullName (Join-Path $labAgentsDir $a.Name) -Force }
if ($socleWorkerFiles.Count -gt 0) {
    $workersDir = Join-Path $labAgentsDir "_workers"
    New-Item -Path $workersDir -ItemType Directory -Force | Out-Null
    foreach ($w in $socleWorkerFiles) { Copy-Item $w.FullName (Join-Path $workersDir $w.Name) -Force }
}

# === Step 4/9: ALL skills (except excluded) ===
Write-Host "[4/9] Vendoring ALL skills ($($socleSkillDirs.Count), excluded: $($SKILLS_EXCLUDED -join ', '))..." -ForegroundColor Green
$labSkillsDir = Join-Path $labPath ".claude\skills"
New-Item -Path $labSkillsDir -ItemType Directory -Force | Out-Null
foreach ($s in $socleSkillDirs) { Copy-Item $s.FullName (Join-Path $labSkillsDir $s.Name) -Recurse -Force }

# === Step 5/9: agent-contexts seeds (dynamic) ===
Write-Host "[5/9] Seeding agent-contexts..." -ForegroundColor Green
$labCtxDir = Join-Path $labPath "agent-contexts"
New-Item -Path $labCtxDir -ItemType Directory -Force | Out-Null
$socleCtx = Join-Path $socleRoot "agent-contexts"
if (Test-Path $socleCtx) {
    Get-ChildItem $socleCtx -Directory | ForEach-Object {
        $dst = Join-Path $labCtxDir $_.Name
        if (-not (Test-Path $dst)) { Copy-Item $_.FullName $dst -Recurse -Force }
    }
}

# === Step 6/9: variable substitution + ref rewriting ===
Write-Host "[6/9] Variable substitution + standalone ref rewriting..." -ForegroundColor Green
# 6a. Template variables. Exclusions: _method/ + ALL vendored skills (their docs contain
#     literal {{LAB_*}} placeholders that must stay literal).
Get-ChildItem -Path $labPath -Recurse -File -Include @("*.md", "*.json", "*.gitignore", "*.txt") |
    Where-Object { $_.FullName -notmatch '\\_method\\' -and $_.FullName -notmatch '\\\.claude\\skills\\' } | ForEach-Object {
    $content = Get-Content -Path $_.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    if ($content) {
        foreach ($key in $variables.Keys) { $content = $content.Replace($key, $variables[$key]) }
        if ($Client) {
            $content = $content -replace '\{\{#LAB_CLIENT\}\}', ''
            $content = $content -replace '\{\{/LAB_CLIENT\}\}', ''
        } else {
            $content = $content -replace '\{\{#LAB_CLIENT\}\}[\s\S]*?\{\{/LAB_CLIENT\}\}', ''
        }
        [System.IO.File]::WriteAllText($_.FullName, $content, $utf8NoBom)
    }
}
# 6b. Ref rewriting on LAB files (vendored agents/skills included, _method/ excluded).
#     Order: most specific first. <workspace> semantics: FROZEN (doctrine, scripts) ->
#     _method ; LIVING (everything else) -> lab root.
Get-ChildItem -Path $labPath -Recurse -File -Include @("*.md", "*.json") |
    Where-Object { $_.FullName -notmatch '\\_method\\' } | ForEach-Object {
    $content = Get-Content -Path $_.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    if ($content) {
        $orig = $content
        $content = $content.Replace('${CLAUDE_PLUGIN_ROOT}/.claude/skills/', '.claude/skills/')
        $content = $content.Replace('${CLAUDE_PLUGIN_ROOT}/', '_method/')
        $content = $content.Replace('${CLAUDE_PLUGIN_ROOT}', '_method')
        $content = $content.Replace('<workspace>/doctrine/', '_method/doctrine/')
        $content = $content.Replace('<workspace>/scripts/', '_method/scripts/')
        $content = $content.Replace('<workspace>\scripts\', '_method\scripts\')
        $content = $content.Replace('<workspace>/', '')
        $content = $content.Replace('<workspace>\', '')
        $content = $content.Replace('<workspace>', '.')
        $content = $content.Replace('../../vibeforge/', '_method/')
        $content = $content.Replace('../vibeforge/', '_method/')
        $content = [regex]::Replace($content, 'vibeforge:([a-z][a-z0-9-]*)', '$1')
        $standaloneNote = '**Standalone**: this lab embeds its method (agents in `.claude/agents/`, skills in `.claude/skills/`, hooks in `.claude/hooks/`, governance socle in `_method/`). It runs on plain Claude Code - NO plugin required, no sibling clone.'
        $content = [regex]::Replace($content, '(?m)^\*\*Prerequisite\*\*.*vibeforge@vibeforge-marketplace.*$', $standaloneNote)
        $content = [regex]::Replace($content, '(?m)^\*\*Prerequis\S*\*\*.*vibeforge@vibeforge-marketplace.*$', $standaloneNote)
        $content = $content.Replace('vibeforge@vibeforge-marketplace', '_method (embedded socle, standalone)')
        if ($content -ne $orig) {
            [System.IO.File]::WriteAllText($_.FullName, $content, $utf8NoBom)
        }
    }
}

# === Step 7/9: lifecycle hooks + settings.json ===
Write-Host "[7/9] Lifecycle hooks + .claude/settings.json..." -ForegroundColor Green
$labHooksDir = Join-Path $labPath ".claude\hooks"
New-Item -Path $labHooksDir -ItemType Directory -Force | Out-Null
foreach ($h in $socleHookFiles) {
    $content = Get-Content $h.FullName -Raw -Encoding utf8
    # post-tool-use resolves agent-contexts via CLAUDE_PLUGIN_ROOT -> in a standalone lab
    # those contexts live at the lab root (CLAUDE_PROJECT_DIR).
    $content = $content.Replace('$env:CLAUDE_PLUGIN_ROOT', '$env:CLAUDE_PROJECT_DIR')
    [System.IO.File]::WriteAllText((Join-Path $labHooksDir $h.Name), $content, $utf8NoBom)
}
$socleHooksJson = Join-Path $socleRoot "hooks\hooks.json"
if (Test-Path $socleHooksJson) {
    $wiring = Get-Content $socleHooksJson -Raw -Encoding utf8
    $wiring = $wiring.Replace('${CLAUDE_PLUGIN_ROOT}\\hooks\\', '${CLAUDE_PROJECT_DIR}\\.claude\\hooks\\')
    $wiring = $wiring.Replace('loaded automatically when the vibeforge plugin is installed. Uses CLAUDE_PLUGIN_ROOT (Claude Code resolves the plugin path) to point at the PowerShell scripts.', 'standalone lab wiring - points at the lab-local .claude/hooks scripts via CLAUDE_PROJECT_DIR.')
    [System.IO.File]::WriteAllText((Join-Path $labPath ".claude\settings.json"), $wiring, $utf8NoBom)
}

# === Step 8/9: living structure + method.txt + real CATALOG ===
Write-Host "[8/9] Living seeds (registers, metrics, audits) + method.txt + CATALOG..." -ForegroundColor Green
foreach ($d in @("metrics", "audits", "backlog", "registres\_archived")) {
    New-Item -Path (Join-Path $labPath $d) -ItemType Directory -Force | Out-Null
}
New-Item -Path (Join-Path $labPath "metrics\events.jsonl") -ItemType File -Force | Out-Null
$tjPath = Join-Path $labPath "registres\traffic-journal.md"
if (-not (Test-Path $tjPath)) {
    [System.IO.File]::WriteAllText($tjPath, "# Traffic journal - $labName`n`n> Local promotions (learning -> lab rule). Append-only.`n", $utf8NoBom)
}
# Local rules.md and eval.md seeded with socle content: agents read the LAB's living
# copies (promotions possible), _method/ stays the frozen reference.
foreach ($reg in @("rules", "eval")) {
    $socleReg = Join-Path $socleRoot "registres\$reg.md"
    $labReg = Join-Path $labPath "registres\$reg.md"
    $header = "# $reg - $labName (living)`n`n> SEEDED on $today from the vibeforge-os socle $socleCommit (inherited section below).`n> The lab's LOCAL additions (promotions, patterns) go ON TOP, above the inherited section.`n> At socle upgrade: the inherited section may be refreshed, local additions are preserved.`n`n## Lab-local additions`n`n(none yet)`n`n## Inherited from the socle (vibeforge-os $socleCommit)`n`n"
    $inherited = ""
    if (Test-Path $socleReg) {
        $inherited = Get-Content $socleReg -Raw -Encoding utf8
        # Same standalone rewriting as 6b: inherited content must read correctly in the
        # LAB context (no unresolved <workspace>/... left behind).
        $inherited = $inherited.Replace('${CLAUDE_PLUGIN_ROOT}/.claude/skills/', '.claude/skills/')
        $inherited = $inherited.Replace('${CLAUDE_PLUGIN_ROOT}/', '_method/')
        $inherited = $inherited.Replace('${CLAUDE_PLUGIN_ROOT}', '_method')
        $inherited = $inherited.Replace('<workspace>/doctrine/', '_method/doctrine/')
        $inherited = $inherited.Replace('<workspace>/scripts/', '_method/scripts/')
        $inherited = $inherited.Replace('<workspace>\scripts\', '_method\scripts\')
        $inherited = $inherited.Replace('<workspace>/', '')
        $inherited = $inherited.Replace('<workspace>\', '')
        $inherited = $inherited.Replace('<workspace>', '.')
        $inherited = $inherited.Replace('../../vibeforge/', '_method/')
        $inherited = $inherited.Replace('../vibeforge/', '_method/')
        $inherited = $inherited.Replace('vibeforge@vibeforge-marketplace', '_method (embedded socle, standalone)')
    }
    [System.IO.File]::WriteAllText($labReg, ($header + $inherited), $utf8NoBom)
}
# method.txt
$dotVibeforge = Join-Path $labPath ".vibeforge"
New-Item -Path $dotVibeforge -ItemType Directory -Force | Out-Null
$methodTxt = @"
# Method this lab depends on.
# First non-commented line = active value, read by the bootstrap.
#
# STATE $today : lab generated STANDALONE by new-lab-standalone.ps1 v1.2 (doctrine frame 16).
# Frozen method in _method/ (socle $socleCommit) + FULL governance vendored: all agents
# (.claude/agents/), all skills (.claude/skills/), lifecycle hooks (.claude/hooks/ +
# settings.json), seeded living registers. No external dependency.
method = standalone
"@
[System.IO.File]::WriteAllText((Join-Path $dotVibeforge "method.txt"), $methodTxt, $utf8NoBom)
$catFile = Join-Path $dotVibeforge "category.txt"
if (-not (Test-Path $catFile)) { [System.IO.File]::WriteAllText($catFile, $Category, $utf8NoBom) }
# Standalone note in the lab's CLAUDE.md
$labClaude = Join-Path $labPath "CLAUDE.md"
if (Test-Path $labClaude) {
    $note = @"


## Standalone mode (doctrine frame 16) - full governance

This lab is INDEPENDENT and embeds the WHOLE Vibeforge governance:
- Frozen method: ``_method/`` (socle $socleCommit, see ``_method/VERSION``). Do not edit.
- Agents (all): ``.claude/agents/`` - Skills (all): ``.claude/skills/`` - Hooks: ``.claude/hooks/`` + ``.claude/settings.json``.
- LIVING registers at the lab root (``registres/``): ``rules.md`` and ``eval.md`` are seeded from the socle
  (inherited section) and receive LOCAL additions on top (learning->rule promotions via traffic-controller,
  patterns via promote-pattern-to-eval). ``_method/registres/`` = frozen reference.
- Capitalization: /cloture-session, /save-cadrage, /dream, /promote-learning, /promote-decision-to-bdr
  all work LOCALLY (nothing syncs back to any external method).
- ``registres/CATALOG.md`` = the REAL list of this lab's skills/agents (anti-hallucination).
  Regenerate with ``tools/rebuild-catalog.ps1`` after adding custom skills/agents.
Runs on plain Claude Code - no plugin, no sibling clone. ``.vibeforge/method.txt`` is authoritative.
"@
    Add-Content -Path $labClaude -Value $note -Encoding UTF8
}
# tools/rebuild-catalog.ps1: the lab can regenerate its own CATALOG (indexing fix).
# Single source: the engine writes this script THEN runs it for the initial CATALOG.
$toolsDir = Join-Path $labPath "tools"
New-Item -Path $toolsDir -ItemType Directory -Force | Out-Null
$rebuildScript = @'
# tools/rebuild-catalog.ps1 - regenerates registres/CATALOG.md from the lab's REALITY
# (zero ghost skills/agents). Re-run after any skill or agent addition/removal.
# Usage: powershell -ExecutionPolicy Bypass -File tools\rebuild-catalog.ps1 [-LabPath <path>]
[CmdletBinding()]
param([string]$LabPath = "")
$ErrorActionPreference = "Stop"
if (-not $LabPath) { $LabPath = Split-Path $PSScriptRoot -Parent }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$labName = Split-Path $LabPath -Leaf
$today = Get-Date -Format "yyyy-MM-dd"
$lines = @("# CATALOG - $labName", "", "> Generated on $today by tools/rebuild-catalog.ps1. ANTI-HALLUCINATION source of truth:", "> only the skills/agents listed here exist in THIS lab. Regenerate after any addition.", "", "## Skills", "", "| Skill | Description |", "|---|---|")
Get-ChildItem (Join-Path $LabPath ".claude\skills") -Directory | Sort-Object Name | ForEach-Object {
    $sk = Join-Path $_.FullName "SKILL.md"
    $desc = ""
    if (Test-Path $sk) {
        $m = Select-String -Path $sk -Pattern '^description:\s*(.+)$' | Select-Object -First 1
        if ($m) { $desc = $m.Matches[0].Groups[1].Value.Trim('"',' ') }
        if ($desc.Length -gt 140) { $desc = $desc.Substring(0, 137) + "..." }
    }
    $lines += "| ``/$($_.Name)`` | $desc |"
}
$lines += @("", "## Agents", "", "| Agent | Description |", "|---|---|")
Get-ChildItem (Join-Path $LabPath ".claude\agents") -Filter *.md -File -Recurse | Where-Object Name -ne "README.md" | Sort-Object Name | ForEach-Object {
    $m = Select-String -Path $_.FullName -Pattern '^description:\s*(.+)$' | Select-Object -First 1
    $desc = ""
    if ($m) { $desc = $m.Matches[0].Groups[1].Value.Trim('"',' ') }
    if ($desc.Length -gt 140) { $desc = $desc.Substring(0, 137) + "..." }
    $aname = $_.BaseName
    if ($_.DirectoryName -like "*_workers*") { $aname = "_workers/$aname" }
    $lines += "| ``$aname`` | $desc |"
}
[System.IO.File]::WriteAllText((Join-Path $LabPath "registres\CATALOG.md"), (($lines -join "`n") + "`n"), $utf8NoBom)
Write-Host "CATALOG regenerated: $(Join-Path $LabPath 'registres\CATALOG.md')"
'@
[System.IO.File]::WriteAllText((Join-Path $toolsDir "rebuild-catalog.ps1"), $rebuildScript, $utf8NoBom)
powershell.exe -ExecutionPolicy Bypass -File (Join-Path $toolsDir "rebuild-catalog.ps1") -LabPath $labPath | Out-Null

# Install manifest: sha256 baseline of every vendored file (drift detection + upgrades, v0.3)
Write-Host "[8bis] Writing install manifest (_method/manifest.json)..." -ForegroundColor Green
& powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build-manifest.ps1") -LabPath $labPath -SocleCommit $socleCommit
if ($LASTEXITCODE -ne 0) { Write-Warning "build-manifest.ps1 failed - lab generated WITHOUT manifest (drift detection unavailable)." }

# === Step 9/9: verification + git ===
Write-Host "[9/9] Dependency-free + governance verification..." -ForegroundColor Green
$violations = @()
Get-ChildItem -Path $labPath -Recurse -File -Include @("*.md", "*.json", "*.txt") |
    Where-Object { $_.FullName -notmatch '\\_method\\' } | ForEach-Object {
    $content = Get-Content -Path $_.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    if ($content -and (($content -match '\.\./vibeforge/') -or ($content -match 'CLAUDE_PLUGIN_ROOT') -or ($content -match 'vibeforge@vibeforge-marketplace') -or ($content -match '<workspace>'))) {
        $violations += $_.FullName.Replace("$labPath\", "")
    }
}
if ($violations.Count -gt 0) {
    Write-Warning "Residual external refs ($($violations.Count) file(s)):"
    $violations | ForEach-Object { Write-Warning "  $_" }
} else {
    Write-Host "  OK - zero external reference outside _method/" -ForegroundColor Green
}
$govChecks = @{
    "skill /dream"            = Test-Path (Join-Path $labPath ".claude\skills\dream\SKILL.md")
    "skill /cloture-session"  = Test-Path (Join-Path $labPath ".claude\skills\cloture-session\SKILL.md")
    "skill /save-cadrage"     = Test-Path (Join-Path $labPath ".claude\skills\save-cadrage\SKILL.md")
    "skill /promote-learning" = Test-Path (Join-Path $labPath ".claude\skills\promote-learning\SKILL.md")
    "agent dream-validator"   = Test-Path (Join-Path $labPath ".claude\agents\dream-validator.md")
    "hooks + settings.json"   = (Test-Path (Join-Path $labPath ".claude\settings.json")) -and ((Get-ChildItem (Join-Path $labPath ".claude\hooks") -Filter *.ps1 -ErrorAction SilentlyContinue).Count -gt 0)
    "seeded registres/rules.md" = Test-Path (Join-Path $labPath "registres\rules.md")
    "real CATALOG"            = Test-Path (Join-Path $labPath "registres\CATALOG.md")
    "install manifest"        = Test-Path (Join-Path $labPath "_method\manifest.json")
}
$govFail = $false
foreach ($k in $govChecks.Keys | Sort-Object) {
    if ($govChecks[$k]) { Write-Host "  OK   $k" -ForegroundColor Green }
    else { Write-Warning "  MISS $k"; $govFail = $true }
}

if ($GitInit) {
    Push-Location $labPath
    try {
        git init | Out-Null
        git add . | Out-Null
        git commit -m "feat: bootstrap standalone lab $labName (socle vibeforge-os $socleCommit, full governance v1.2)" | Out-Null
        Write-Host "  Git initialized + first commit OK" -ForegroundColor Green
    } catch { Write-Warning "Git error: $_" } finally { Pop-Location }
}

Write-Host ""
Write-Host "OK  STANDALONE lab '$labName' created at: $labPath" -ForegroundColor Cyan
Write-Host "    Socle : $socleId @ $socleCommit - FULL governance embedded (v1.2)" -ForegroundColor Cyan
Write-Host "    No plugin required - plain Claude Code." -ForegroundColor Cyan
if ($govFail) { Write-Warning "At least one governance element is MISS - check the socle source." }
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Customize SOUL.md / contexte-domaine.md / CLAUDE.md (via lab-architect)"
Write-Host "  2. Create the domain's custom agents/skills in .claude\ (then re-run tools\rebuild-catalog.ps1)"
Write-Host "  3. cd $labPath then claude"

exit 0
