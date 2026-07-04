# scripts/upgrade-socle.ps1  (v1.0)
# Upgrades the METHOD LAYER of an existing standalone lab (doctrine frame 16) without
# touching its custom layer. Companion of new-lab-standalone.ps1 v1.1.
#
# What is method-owned (refreshed): _method/, socle agents/skills present in the socle
# inventory, hooks, tools/rebuild-catalog.ps1, VERSION.
# What is custom (NEVER touched): agents/skills NOT in the socle inventory, all
# registres content (rules.md/eval.md local additions preserved), agent-contexts
# (MEMORY are living), SOUL/CLAUDE/contexte-domaine, projects, store, etc.
#
# ASCII-safe (PowerShell 5.1). Fail-closed: stops on first error.

[CmdletBinding()]
param(
    # Path of the standalone lab to upgrade (required)
    [Parameter(Mandatory=$true)][string]$LabPath,
    # Socle source override. Default: sibling vibeforge-os of this script's repo, else
    # the repo this script lives in (self).
    [string]$SocleSource = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$today = Get-Date -Format "yyyy-MM-dd"
$SKILLS_EXCLUDED = @("new-lab")

if (-not (Test-Path $LabPath)) { Write-Error "Lab not found: $LabPath"; exit 1 }
$labName = Split-Path $LabPath -Leaf
$methodTxt = Join-Path $LabPath ".vibeforge\method.txt"
if (-not (Test-Path $methodTxt) -or ((Get-Content $methodTxt -Raw) -notmatch 'method\s*=\s*standalone')) {
    Write-Error "This lab is not standalone (method.txt missing or not 'standalone'). Upgrade aborted."
    exit 1
}

# Socle resolution: explicit > self (this script lives in <socle>/scripts/)
if ($SocleSource) {
    if (-not (Test-Path $SocleSource)) { Write-Error "SocleSource not found: $SocleSource"; exit 1 }
    $socleRepo = $SocleSource
} else {
    $socleRepo = Split-Path $PSScriptRoot -Parent
}
$socleRoot = if (Test-Path (Join-Path $socleRepo "plugin")) { Join-Path $socleRepo "plugin" } else { $socleRepo }
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
        $o = (git -C $gitProbe remote get-url origin 2>$null); if ($o) { $socleId = $o.Trim() }
    } catch { }
}

# Dynamic inventories: method-owned = present in socle. Custom = everything else.
$socleAgentNames = @(Get-ChildItem (Join-Path $socleRoot "agents") -Filter *.md -File | ForEach-Object { $_.Name })
$socleWorkerNames = @(Get-ChildItem (Join-Path $socleRoot "agents\_workers") -Filter *.md -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
$socleSkillNames = @(Get-ChildItem (Join-Path $socleRoot "skills") -Directory | Where-Object { $SKILLS_EXCLUDED -notcontains $_.Name } | ForEach-Object { $_.Name })
$labAgentsDir = Join-Path $LabPath ".claude\agents"
$labSkillsDir = Join-Path $LabPath ".claude\skills"
$customAgents = @(Get-ChildItem $labAgentsDir -Filter *.md -File -ErrorAction SilentlyContinue | Where-Object { $socleAgentNames -notcontains $_.Name } | ForEach-Object { $_.BaseName })
$customSkills = @(Get-ChildItem $labSkillsDir -Directory -ErrorAction SilentlyContinue | Where-Object { $socleSkillNames -notcontains $_.Name -and $SKILLS_EXCLUDED -notcontains $_.Name } | ForEach-Object { $_.Name })

Write-Host "=== /upgrade-socle : $labName -> socle $socleCommit ===" -ForegroundColor Cyan
Write-Host "    Custom PROTEGE : $($customAgents.Count) agents [$($customAgents -join ', ')]" -ForegroundColor Cyan
Write-Host "                     $($customSkills.Count) skills [$($customSkills -join ', ')]" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN - would refresh: _method/, $($socleAgentNames.Count) method agents (+$($socleWorkerNames.Count) workers)," -ForegroundColor Yellow
    Write-Host "$($socleSkillNames.Count) method skills, hooks + settings.json (if absent), tools/rebuild-catalog.ps1, CATALOG." -ForegroundColor Yellow
    exit 0
}

# 1. _method/ full refresh (regenerable by doctrine)
Write-Host "[1/6] Refreshing _method/..." -ForegroundColor Green
$methodPath = Join-Path $LabPath "_method"
if (Test-Path $methodPath) { Remove-Item $methodPath -Recurse -Force }
New-Item -Path $methodPath -ItemType Directory -Force | Out-Null
foreach ($f in @("CLAUDE.md","DOCTRINE.md")) {
    $src = Join-Path $socleRoot $f
    if (Test-Path $src) { Copy-Item $src (Join-Path $methodPath $f) -Force }
}
foreach ($d in @("registres","doctrine","templates","scripts","agent-contexts")) {
    $src = Join-Path $socleRoot $d
    if (Test-Path $src) { Copy-Item $src (Join-Path $methodPath $d) -Recurse -Force }
}
New-Item -Path (Join-Path $methodPath "metrics") -ItemType Directory -Force | Out-Null
New-Item -Path (Join-Path $methodPath "metrics\events.jsonl") -ItemType File -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $methodPath "README.md"), "# _method/ - FROZEN governance socle`n`nUpgraded on $today by upgrade-socle.ps1 (socle $socleCommit). Do NOT hand-edit (overwritten at upgrade).`nLiving registers: registres/ at the lab root.`n", $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $methodPath "VERSION"), "socle_source: $socleId`nsocle_commit: $socleCommit`nvendored_on: $today`ngenerator: upgrade-socle.ps1 v1.0`n", $utf8NoBom)

# 2. Method agents + workers (overwrite; custom untouched by construction)
Write-Host "[2/6] Refreshing method agents..." -ForegroundColor Green
New-Item -Path $labAgentsDir -ItemType Directory -Force | Out-Null
Get-ChildItem (Join-Path $socleRoot "agents") -Filter *.md -File | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $labAgentsDir $_.Name) -Force
}
if ($socleWorkerNames.Count -gt 0) {
    $wd = Join-Path $labAgentsDir "_workers"
    New-Item -Path $wd -ItemType Directory -Force | Out-Null
    Get-ChildItem (Join-Path $socleRoot "agents\_workers") -Filter *.md -File | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $wd $_.Name) -Force
    }
}

# 3. Method skills (overwrite; custom untouched)
Write-Host "[3/6] Refreshing method skills..." -ForegroundColor Green
New-Item -Path $labSkillsDir -ItemType Directory -Force | Out-Null
Get-ChildItem (Join-Path $socleRoot "skills") -Directory | Where-Object { $SKILLS_EXCLUDED -notcontains $_.Name } | ForEach-Object {
    $dst = Join-Path $labSkillsDir $_.Name
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    Copy-Item $_.FullName $dst -Recurse -Force
}

# 4. Hooks (overwrite scripts; settings.json only if absent) + missing agent-contexts
Write-Host "[4/6] Hooks + missing agent-contexts..." -ForegroundColor Green
$labHooksDir = Join-Path $LabPath ".claude\hooks"
New-Item -Path $labHooksDir -ItemType Directory -Force | Out-Null
Get-ChildItem (Join-Path $socleRoot "hooks") -Filter *.ps1 -File -ErrorAction SilentlyContinue | ForEach-Object {
    $c = Get-Content $_.FullName -Raw -Encoding utf8
    $c = $c.Replace('$env:CLAUDE_PLUGIN_ROOT', '$env:CLAUDE_PROJECT_DIR')
    [System.IO.File]::WriteAllText((Join-Path $labHooksDir $_.Name), $c, $utf8NoBom)
}
$settingsPath = Join-Path $LabPath ".claude\settings.json"
if (-not (Test-Path $settingsPath)) {
    $wiring = Get-Content (Join-Path $socleRoot "hooks\hooks.json") -Raw -Encoding utf8
    $wiring = $wiring.Replace('${CLAUDE_PLUGIN_ROOT}\\hooks\\', '${CLAUDE_PROJECT_DIR}\\.claude\\hooks\\')
    [System.IO.File]::WriteAllText($settingsPath, $wiring, $utf8NoBom)
}
$labCtxDir = Join-Path $LabPath "agent-contexts"
New-Item -Path $labCtxDir -ItemType Directory -Force | Out-Null
Get-ChildItem (Join-Path $socleRoot "agent-contexts") -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $dst = Join-Path $labCtxDir $_.Name
    if (-not (Test-Path $dst)) { Copy-Item $_.FullName $dst -Recurse -Force }
}

# 5. Ref rewriting on refreshed files (idempotent on the rest) + living seeds if missing
Write-Host "[5/6] Ref rewriting + living seeds..." -ForegroundColor Green
Get-ChildItem -Path $LabPath -Recurse -File -Include @("*.md","*.json") |
    Where-Object { $_.FullName -notmatch '\\_method\\' -and $_.FullName -notmatch '\\\.git\\' } | ForEach-Object {
    $c = Get-Content $_.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    if ($c) {
        $o = $c
        $c = $c.Replace('${CLAUDE_PLUGIN_ROOT}/.claude/skills/', '.claude/skills/')
        $c = $c.Replace('${CLAUDE_PLUGIN_ROOT}/', '_method/')
        $c = $c.Replace('${CLAUDE_PLUGIN_ROOT}', '_method')
        $c = $c.Replace('<workspace>/doctrine/', '_method/doctrine/')
        $c = $c.Replace('<workspace>/scripts/', '_method/scripts/')
        $c = $c.Replace('<workspace>\scripts\', '_method\scripts\')
        $c = $c.Replace('<workspace>/', '')
        $c = $c.Replace('<workspace>\', '')
        $c = $c.Replace('<workspace>', '.')
        $c = $c.Replace('../../vibeforge/', '_method/')
        $c = $c.Replace('../vibeforge/', '_method/')
        $c = [regex]::Replace($c, 'vibeforge:([a-z][a-z0-9-]*)', '$1')
        $c = $c.Replace('vibeforge@vibeforge-marketplace', '_method (embedded socle, standalone)')
        if ($c -ne $o) { [System.IO.File]::WriteAllText($_.FullName, $c, $utf8NoBom) }
    }
}
foreach ($d in @("metrics","audits","registres\_archived","tools")) { New-Item -Path (Join-Path $LabPath $d) -ItemType Directory -Force | Out-Null }
if (-not (Test-Path (Join-Path $LabPath "metrics\events.jsonl"))) { New-Item -Path (Join-Path $LabPath "metrics\events.jsonl") -ItemType File -Force | Out-Null }
$tj = Join-Path $LabPath "registres\traffic-journal.md"
if (-not (Test-Path $tj)) { [System.IO.File]::WriteAllText($tj, "# Traffic journal - $labName`n`n> Local promotions (learning -> lab rule). Append-only.`n", $utf8NoBom) }
# registres/rules.md: seed only if missing (existing local additions are sacred)
$labRules = Join-Path $LabPath "registres\rules.md"
if (-not (Test-Path $labRules)) {
    $inh = Get-Content (Join-Path $socleRoot "registres\rules.md") -Raw -Encoding utf8
    foreach ($pair in @(@('${CLAUDE_PLUGIN_ROOT}/','_method/'),@('<workspace>/doctrine/','_method/doctrine/'),@('<workspace>/scripts/','_method/scripts/'),@('<workspace>/',''),@('<workspace>','.'),@('../vibeforge/','_method/'))) { $inh = $inh.Replace($pair[0], $pair[1]) }
    [System.IO.File]::WriteAllText($labRules, ("# rules - $labName (living)`n`n> SEEDED on $today from socle $socleCommit.`n`n## Lab-local additions`n`n(none yet)`n`n## Inherited from the socle ($socleCommit)`n`n" + $inh), $utf8NoBom)
}

# 6. tools/rebuild-catalog.ps1 refresh + CATALOG regen + verification
Write-Host "[6/6] rebuild-catalog + CATALOG + verification..." -ForegroundColor Green
$rebuildSrc = Join-Path $socleRoot "scripts\rebuild-catalog.ps1"
$rebuildDst = Join-Path $LabPath "tools\rebuild-catalog.ps1"
if (Test-Path $rebuildSrc) { Copy-Item $rebuildSrc $rebuildDst -Force }
if (Test-Path $rebuildDst) {
    powershell.exe -ExecutionPolicy Bypass -File $rebuildDst -LabPath $LabPath | Out-Null
}
$viol = @()
Get-ChildItem -Path $LabPath -Recurse -File -Include @("*.md","*.json","*.txt") |
    Where-Object { $_.FullName -notmatch '\\_method\\' -and $_.FullName -notmatch '\\\.git\\' } | ForEach-Object {
    $c = Get-Content $_.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    if ($c -and (($c -match '\.\./vibeforge/') -or ($c -match 'CLAUDE_PLUGIN_ROOT') -or ($c -match 'vibeforge@vibeforge-marketplace') -or ($c -match '<workspace>'))) { $viol += $_.FullName.Replace("$LabPath\","") }
}
if ($viol.Count -gt 0) { Write-Warning "Residual refs: $($viol -join ' | ')" } else { Write-Host "  OK - zero external reference" -ForegroundColor Green }
$protectOk = $true
foreach ($ca in $customAgents) { if (-not (Test-Path (Join-Path $labAgentsDir "$ca.md"))) { Write-Warning "CUSTOM AGENT LOST: $ca"; $protectOk = $false } }
foreach ($cs in $customSkills) { if (-not (Test-Path (Join-Path $labSkillsDir $cs))) { Write-Warning "CUSTOM SKILL LOST: $cs"; $protectOk = $false } }
if ($protectOk) { Write-Host "  OK - custom layer intact ($($customAgents.Count) agents, $($customSkills.Count) skills)" -ForegroundColor Green }

Write-Host ""
Write-Host "OK  Socle upgraded: $labName -> $socleId @ $socleCommit (see _method\VERSION)" -ForegroundColor Cyan
Write-Host "    Restart Claude Code sessions in this lab to load refreshed agents/skills." -ForegroundColor Cyan
exit 0
