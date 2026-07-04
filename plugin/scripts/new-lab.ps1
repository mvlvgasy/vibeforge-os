# scripts/new-lab.ps1
# Create a new lab from the lab.template/ shipped with the Vibeforge plugin.
#
# Paths are resolved relative to this script ($PSScriptRoot), so the plugin
# works wherever it is installed. The lab is created in the current working
# directory by default (override with -TargetDir).
#
# ASCII-safe code to avoid PowerShell 5.1 encoding bugs on Windows. The
# generated user content (.md files) may still contain UTF-8 accents.

[CmdletBinding()]
param(
    # Short domain name (without the lab- prefix). E.g. "client-acme", "freelance-web"
    [string]$Name = "",

    # Legacy alias: -Type can also be used.
    [string]$Type = "",

    # Lab category. Determines where the deliverables of this lab's projects go:
    # -> <TargetDir>/projets/<category>/<project>/
    # Format: kebab-case alpha-num. Common values: client | freelance | perso | content | custom
    [string]$Category = "custom",

    # Optional client (for freelance / business labs)
    [string]$Client = "",

    # Where to create the lab. Defaults to the current directory.
    [string]$TargetDir = "",

    # Git init after creation
    [switch]$GitInit,

    # Dry-run (preview without creating anything)
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# === Normalize input ===
# Accept -Name or -Type as alias. -Name takes priority.
$rawName = if ($Name) { $Name } elseif ($Type) { $Type } else { "" }

if (-not $rawName) {
    Write-Error "Required argument: -Name <lab-name>. E.g. -Name 'client-acme'"
    exit 1
}

# Strip "lab-" prefix if passed as argument
if ($rawName -like "lab-*") {
    $rawName = $rawName.Substring(4)
}

# Sanitize: kebab-case, alphanumeric + dashes
if ($rawName -notmatch '^[a-z][a-z0-9-]{1,40}$') {
    Write-Error "Invalid name: '$rawName'. Expected format: kebab-case, 2-40 chars, must start with a letter."
    exit 1
}

$labName = "lab-$rawName"

# === Paths ===
# Templates ship with the plugin, next to this script's parent (plugin/templates).
$templateBase = Join-Path $PSScriptRoot "..\templates\lab.template"
# The lab is created in the current directory unless -TargetDir is given.
if (-not $TargetDir) { $TargetDir = (Get-Location).Path }
$labPath = Join-Path $TargetDir $labName
$today = Get-Date -Format "yyyy-MM-dd"

# Auto-infer the category from the lab name if not explicitly provided
if ($Category -eq "custom") {
    if ($rawName -like "*client*") {
        $Category = "client"
    } elseif ($rawName -like "freelance*" -or $rawName -like "*-freelance*") {
        $Category = "freelance"
    } elseif ($rawName -like "perso*" -or $rawName -like "*-perso*") {
        $Category = "perso"
    } elseif ($rawName -like "content*" -or $rawName -like "*-content*") {
        $Category = "content"
    }
}

# Validate the final category (after auto-inference or explicit override)
if ($Category -notmatch '^[a-z][a-z0-9-]{1,30}$') {
    Write-Error "Invalid category: '$Category'. Expected format: kebab-case alpha-num, 2-30 chars, must start with a letter."
    exit 1
}

# Substitution variables for the templates.
# The method (doctrine, rules, registers) lives inside the installed plugin,
# reachable at runtime via the CLAUDE_PLUGIN_ROOT environment variable.
$pluginRootRef = '${CLAUDE_PLUGIN_ROOT}'
$displayDomain = (Get-Culture).TextInfo.ToTitleCase($rawName.Replace("-", " "))
$variables = @{
    "{{LAB_NAME}}"       = $labName
    "{{LAB_DOMAIN}}"     = $displayDomain
    "{{LAB_CLIENT}}"     = $Client
    "{{LAB_CATEGORY}}"   = $Category
    "{{LAB_CREATED}}"    = $today
    "{{LAB_PARENT}}"     = $pluginRootRef
    "{{VIBEFORGE_PATH}}" = $pluginRootRef
}

Write-Host "=== /new-lab: creating '$labName' (category: $Category) ===" -ForegroundColor Cyan
Write-Host ""

# === Checks ===
if (-not (Test-Path $templateBase)) {
    Write-Error "Template not found: $templateBase"
    exit 1
}

if (Test-Path $labPath) {
    Write-Error "Lab '$labName' already exists at $labPath. Remove it manually to recreate."
    exit 1
}

# === DRY RUN preview ===
if ($DryRun) {
    Write-Host "DRY RUN -- preview:" -ForegroundColor Yellow
    Write-Host "  Lab path     : $labPath"
    Write-Host "  Template src : $templateBase"
    Write-Host "  Variables    :"
    foreach ($key in $variables.Keys) {
        Write-Host "    $key = $($variables[$key])"
    }
    if ($GitInit) { Write-Host "  + Git init" }
    Write-Host ""
    Write-Host "No execution. Re-run without -DryRun to create." -ForegroundColor Yellow
    exit 0
}

# === Step 1: copy the template ===
Write-Host "[1/5] Copying the template..." -ForegroundColor Green
New-Item -Path $labPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "$templateBase\*" -Destination $labPath -Recurse -Force

# === Step 2: rename .tpl to .md (and others) ===
Write-Host "[2/5] Renaming .tpl files..." -ForegroundColor Green
Get-ChildItem -Path $labPath -Recurse -File -Filter "*.tpl" | ForEach-Object {
    $newName = $_.FullName -replace '\.tpl$', ''
    Move-Item -Path $_.FullName -Destination $newName -Force
}

# === Step 3: substitute variables ===
# Includes .txt to allow substitution in .vibeforge/category.txt.
# UTF-8 without BOM:
# - Get-Content -Encoding utf8: otherwise PS 5.1 reads as cp1252 -> mojibake
# - WriteAllText with UTF8Encoding(false): no BOM (EF BB BF)
Write-Host "[3/5] Substituting variables..." -ForegroundColor Green
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
Get-ChildItem -Path $labPath -Recurse -File -Include @("*.md", "*.json", "*.gitignore", "*.txt") | ForEach-Object {
    $content = Get-Content -Path $_.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    if ($content) {
        foreach ($key in $variables.Keys) {
            $content = $content.Replace($key, $variables[$key])
        }
        # Simple conditional handling {{#LAB_CLIENT}}...{{/LAB_CLIENT}}
        if ($Client) {
            $content = $content -replace '\{\{#LAB_CLIENT\}\}', ''
            $content = $content -replace '\{\{/LAB_CLIENT\}\}', ''
        } else {
            $content = $content -replace '\{\{#LAB_CLIENT\}\}[\s\S]*?\{\{/LAB_CLIENT\}\}', ''
        }
        [System.IO.File]::WriteAllText($_.FullName, $content, $utf8NoBom)
    }
}

# === Step 4: rename .gitignore.tpl (special case) ===
$gitignoreSource = Join-Path $labPath ".gitignore.tpl"
if (Test-Path $gitignoreSource) {
    Move-Item -Path $gitignoreSource -Destination (Join-Path $labPath ".gitignore") -Force
}

# === Step 5: optional git init ===
if ($GitInit) {
    Write-Host "[4/6] Git init..." -ForegroundColor Green
    Push-Location $labPath
    try {
        git init | Out-Null
        git add . | Out-Null
        git commit -m "feat: bootstrap lab $labName" | Out-Null
        Write-Host "  Git initialized + first commit OK"
    } catch {
        Write-Warning "Git error: $_"
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[4/6] Git init skipped (use -GitInit to enable)" -ForegroundColor Yellow
}

# === Step 5: seed the workspace-global WRITABLE layer ===
# The plugin ships registres/ and agent-contexts/ as READ-ONLY seeds (overwritten
# on every `claude plugin update`). The operator's own promoted rules and agent
# memory must live in a writable location they own: <workspace>/registres/ and
# <workspace>/agent-contexts/ (siblings of the labs). Seeded once, on the first
# lab created in this workspace; NEVER overwritten afterwards (would clobber data).
Write-Host "[5/6] Seeding workspace-global writable layer..." -ForegroundColor Green
$pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
foreach ($seed in @("registres", "agent-contexts")) {
    $src = Join-Path $pluginRoot $seed
    $dst = Join-Path $TargetDir $seed
    if (Test-Path $dst) {
        Write-Host "  $seed/ already in workspace -> kept (no overwrite)" -ForegroundColor Yellow
    } elseif (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Recurse -Force
        Write-Host "  $seed/ seeded -> $dst"
    } else {
        Write-Warning "  seed source not found: $src"
    }
}

# === Recap ===
Write-Host "[6/6] Lab created." -ForegroundColor Green
Write-Host ""
Write-Host "OK  Lab '$labName' created at: $labPath" -ForegroundColor Cyan
Write-Host ""

# Verify the Vibeforge plugin is installed (prerequisite for /lead, /architecte, etc.)
$claudeExe = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeExe) {
    $pluginList = & claude plugin list 2>&1 | Out-String
    if ($pluginList -match "vibeforge@vibeforge-marketplace") {
        Write-Host "OK  Plugin vibeforge installed (the /lead, /architecte, ... agents are available)" -ForegroundColor Green
    } else {
        Write-Host "WARN  Plugin vibeforge NOT installed!" -ForegroundColor Yellow
        Write-Host "      Without it, /lead, /architecte, etc. will not work in this lab." -ForegroundColor Yellow
        Write-Host "      Install:" -ForegroundColor Yellow
        Write-Host "        claude plugin marketplace add mvlvgasy/vibeforge-os" -ForegroundColor Yellow
        Write-Host "        claude plugin install vibeforge@vibeforge-marketplace" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Customize $labPath\SOUL.md (lab identity)"
Write-Host "  2. Fill in $labPath\contexte-domaine.md (domain corpus)"
Write-Host "  3. Customize $labPath\CLAUDE.md (specific rules)"
Write-Host "  4. If needed, create complementary agents in $labPath\.claude\agents\"
Write-Host "  5. To create an associated project: /new-projet -Name <name> -AffiliatedLab $labName"
Write-Host ""
Write-Host "To start a session: cd $labPath then run claude" -ForegroundColor Green

exit 0
