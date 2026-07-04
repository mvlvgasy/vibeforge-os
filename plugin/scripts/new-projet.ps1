# scripts/new-projet.ps1
#
# Create a new project with the deliverable / meta split:
#   - Deliverable: <BaseDir>/projets/<category>/<project>/   (pure code, pushable to a client GitHub)
#   - Meta       : <lab>/projets-meta/<project>/             (method + tracking, inside the lab)
#
# Paths are resolved relative to the current directory (-BaseDir, default cwd)
# and to this script's plugin templates ($PSScriptRoot). ASCII-safe code to
# avoid PowerShell 5.1 encoding bugs on Windows.
#
# AffiliatedLab is MANDATORY: every project is attached to a methodological lab.
# The meta-project lives in the lab; the top-level deliverable holds only code
# (no Vibeforge method inside).

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$AffiliatedLab,
    # Base directory containing the lab (and where projets/ will be created). Defaults to cwd.
    [string]$BaseDir = "",
    [switch]$GitInit,
    [string]$GithubRepo = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# === Sanitize name ===
$Name = $Name.ToLower().Trim()
if ($Name -notmatch '^[a-z][a-z0-9-]{1,60}$') {
    Write-Error "Invalid name: '$Name'. Expected format: kebab-case alpha-num, 2-60 chars, must start with a letter."
    exit 1
}

$forbidden = @("vibeforge", "node_modules", "clients")
if ($forbidden -contains $Name -or $Name -like "lab-*") {
    Write-Error "Reserved name: '$Name'. Avoid vibeforge, lab-*, node_modules, etc."
    exit 1
}

# === Validate affiliated lab ===
if ($AffiliatedLab -notmatch '^lab-[a-z0-9-]+$') {
    Write-Error "Invalid affiliated lab name: '$AffiliatedLab'. Expected format: 'lab-<name>'."
    exit 1
}

# === Paths ===
# Templates ship with the plugin, next to this script's parent (plugin/templates).
$projetTemplate     = Join-Path $PSScriptRoot "..\templates\projet.template"
$projetMetaTemplate = Join-Path $PSScriptRoot "..\templates\projet-meta.template"

# Base directory holds the lab and the deliverables tree. Defaults to cwd.
if (-not $BaseDir) { $BaseDir = (Get-Location).Path }
$labPath = Join-Path $BaseDir $AffiliatedLab

# Read the lab category (from <lab>/.vibeforge/category.txt). Fallback: "custom".
$categoryFile = Join-Path $labPath ".vibeforge\category.txt"
$category = if (Test-Path $categoryFile) {
    $rawCat = (Get-Content $categoryFile -Raw -ErrorAction SilentlyContinue)
    if ($rawCat) { $rawCat.Trim() } else { "custom" }
} else {
    "custom"
}

# Simple validation (allow any kebab-case alpha-num to permit custom)
if ($category -notmatch '^[a-z][a-z0-9-]*$') {
    Write-Warning "Invalid category in $categoryFile : '$category'. Falling back to 'custom'."
    $category = "custom"
}

# Deliverable: <BaseDir>/projets/<category>/<name>/
$livrableParent = Join-Path $BaseDir "projets\$category"
$livrablePath   = Join-Path $livrableParent $Name
$metaPath       = Join-Path $labPath "projets-meta\$Name"

$today = Get-Date -Format "yyyy-MM-dd"

# === Checks ===
foreach ($t in @($projetTemplate, $projetMetaTemplate)) {
    if (-not (Test-Path $t)) {
        Write-Error "Template not found: $t"
        exit 1
    }
}

if (-not (Test-Path $labPath)) {
    Write-Error "Affiliated lab does not exist: $labPath. Create it first via /new-lab."
    exit 1
}

if (Test-Path $livrablePath) {
    Write-Error "Deliverable already exists: $livrablePath. Remove it manually to recreate."
    exit 1
}

if (Test-Path $metaPath) {
    Write-Error "Meta-project already exists: $metaPath. Remove it manually to recreate."
    exit 1
}

# === Substitution variables (relative paths from the META-project) ===
# The session cwd will be: <lab>/projets-meta/<project>/
# So:
#   ..        -> <lab>/projets-meta/
#   ../..     -> <lab>/  (= parent lab)
#   ../../../projets/<category>/<name> -> <BaseDir>/projets/<category>/<name>/ (= deliverable)
# The method (doctrine, rules, registers) lives inside the installed plugin,
# reachable at runtime via the CLAUDE_PLUGIN_ROOT environment variable.
$pluginRootRef = '${CLAUDE_PLUGIN_ROOT}'
$variables = @{
    "{{PROJET_NAME}}"             = $Name
    "{{PROJET_CREATED}}"          = $today
    "{{LAB_NAME}}"                = $AffiliatedLab
    "{{LAB_CATEGORY}}"            = $category
    "{{LAB_PATH_RELATIVE}}"       = "../.."
    "{{VIBEFORGE_PATH_RELATIVE}}" = $pluginRootRef
    "{{LIVRABLE_PATH_RELATIVE}}"  = "../../../projets/$category/$Name"
}

Write-Host "=== /new-projet: '$Name' ===" -ForegroundColor Cyan
Write-Host "  Category    : $category (inherited from the lab)" -ForegroundColor Cyan
Write-Host "  Deliverable : $livrablePath" -ForegroundColor Cyan
Write-Host "  Meta-project: $metaPath" -ForegroundColor Cyan
Write-Host "  Affil. lab  : $AffiliatedLab" -ForegroundColor Cyan
Write-Host ""

# === DRY RUN ===
if ($DryRun) {
    Write-Host "DRY RUN -- preview:" -ForegroundColor Yellow
    Write-Host "  Templates used:"
    Write-Host "    deliverable -> $projetTemplate"
    Write-Host "    meta        -> $projetMetaTemplate"
    Write-Host "  Substitution variables:"
    foreach ($key in $variables.Keys) {
        Write-Host "    $key = $($variables[$key])"
    }
    if ($GitInit) { Write-Host "  + Git init on deliverable" }
    if ($GithubRepo) { Write-Host "  + GitHub remote: $GithubRepo" }
    Write-Host ""
    Write-Host "No execution. Re-run without -DryRun to create." -ForegroundColor Yellow
    exit 0
}

# === STEP 1: create the DELIVERABLE (minimal) in projets/<category>/<name>/ ===
Write-Host "[1/4] Creating the deliverable (pure code folder)..." -ForegroundColor Green

# Ensure the parent projets/<category>/ exists
if (-not (Test-Path $livrableParent)) {
    New-Item -Path $livrableParent -ItemType Directory -Force | Out-Null
    Write-Host "  Category folder created: $livrableParent"
}

New-Item -Path $livrablePath -ItemType Directory -Force | Out-Null
Copy-Item -Path "$projetTemplate\*" -Destination $livrablePath -Recurse -Force

# Rename .tpl to finals
Get-ChildItem -Path $livrablePath -Recurse -File -Filter "*.tpl" | ForEach-Object {
    $newName = $_.FullName -replace '\.tpl$', ''
    Move-Item -Path $_.FullName -Destination $newName -Force
}

# Substitute variables. UTF-8 without BOM:
# - Get-Content -Encoding utf8: otherwise PS 5.1 reads as cp1252 -> mojibake
# - WriteAllText with UTF8Encoding(false): no BOM (EF BB BF)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
Get-ChildItem -Path $livrablePath -Recurse -File -Include @("*.md", "*.json", "*.gitignore") | ForEach-Object {
    $content = Get-Content -Path $_.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    if ($content) {
        foreach ($key in $variables.Keys) {
            $content = $content.Replace($key, $variables[$key])
        }
        [System.IO.File]::WriteAllText($_.FullName, $content, $utf8NoBom)
    }
}

Write-Host "  Deliverable created."

# === STEP 2: create the META-PROJECT inside the lab ===
Write-Host "[2/4] Creating the meta-project inside the lab..." -ForegroundColor Green

New-Item -Path $metaPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "$projetMetaTemplate\*" -Destination $metaPath -Recurse -Force

# Rename .tpl to finals
Get-ChildItem -Path $metaPath -Recurse -File -Filter "*.tpl" | ForEach-Object {
    $newName = $_.FullName -replace '\.tpl$', ''
    Move-Item -Path $_.FullName -Destination $newName -Force
}

# Substitute variables (UTF-8 without BOM)
Get-ChildItem -Path $metaPath -Recurse -File -Include @("*.md", "*.json") | ForEach-Object {
    $content = Get-Content -Path $_.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    if ($content) {
        foreach ($key in $variables.Keys) {
            $content = $content.Replace($key, $variables[$key])
        }
        [System.IO.File]::WriteAllText($_.FullName, $content, $utf8NoBom)
    }
}

# Create docs/prd-coverage-reports/ (placeholder for reviewer-prd reports)
$prdReportsDir = Join-Path $metaPath "docs\prd-coverage-reports"
New-Item -Path $prdReportsDir -ItemType Directory -Force | Out-Null
Set-Content -Path (Join-Path $prdReportsDir ".gitkeep") -Value "" -Encoding utf8

Write-Host "  Meta-project created."

# === STEP 3: git init on the DELIVERABLE (optional) ===
if ($GitInit) {
    Write-Host "[3/4] Git init on the deliverable..." -ForegroundColor Green
    Push-Location $livrablePath
    try {
        git init | Out-Null
        if ($GithubRepo) {
            git remote add origin $GithubRepo | Out-Null
            Write-Host "  Remote origin added: $GithubRepo"
        }
        git add . | Out-Null
        git commit -m "feat: bootstrap $Name (deliverable)" | Out-Null
        Write-Host "  Git initialized + first commit OK"
    } catch {
        Write-Warning "Git error: $_"
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[3/4] Deliverable git init skipped (-GitInit to enable)" -ForegroundColor Yellow
}

# === STEP 4: branch protection guidance ===
# Branch protection cannot be set up HERE because:
#   - main has no pushed commit yet (the first push happens at sprint 0)
#   - The CI job name does not exist yet (added at sprint 0 via .github/workflows/test.yml)
# So we PRINT the commands to run right after the first push.

Write-Host "[4/5] Branch protection guidance..." -ForegroundColor Green
if ($GithubRepo) {
    # Extract owner/repo from the GitHub URL.
    # Expected: https://github.com/<owner>/<repo>.git or git@github.com:<owner>/<repo>.git
    $ghMatch = [regex]::Match($GithubRepo, 'github\.com[:/]([^/]+)/([^/.]+)')
    if ($ghMatch.Success) {
        $ghOwner = $ghMatch.Groups[1].Value
        $ghRepo = $ghMatch.Groups[2].Value
        Write-Host "  GitHub repo detected: $ghOwner/$ghRepo" -ForegroundColor Cyan
    } else {
        $ghOwner = "<owner>"
        $ghRepo = "<repo>"
        Write-Warning "Could not extract owner/repo from '$GithubRepo'. Replace manually in the command below."
    }
} else {
    $ghOwner = "<owner>"
    $ghRepo = "<repo>"
}

Write-Host "  Branch protection becomes applicable AFTER the first push." -ForegroundColor Yellow
Write-Host "  Command to run right after merging the first PR:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  gh api repos/$ghOwner/$ghRepo/branches/main/protection -X PUT --input - <<'EOF'" -ForegroundColor Magenta
Write-Host "  {" -ForegroundColor Magenta
Write-Host "    \"required_status_checks\": {" -ForegroundColor Magenta
Write-Host "      \"strict\": true," -ForegroundColor Magenta
Write-Host "      \"contexts\": [\"<EXACT CI JOB NAME>\"]" -ForegroundColor Magenta
Write-Host "    }," -ForegroundColor Magenta
Write-Host "    \"enforce_admins\": false," -ForegroundColor Magenta
Write-Host "    \"required_pull_request_reviews\": null," -ForegroundColor Magenta
Write-Host "    \"restrictions\": null," -ForegroundColor Magenta
Write-Host "    \"allow_force_pushes\": false," -ForegroundColor Magenta
Write-Host "    \"allow_deletions\": false" -ForegroundColor Magenta
Write-Host "  }" -ForegroundColor Magenta
Write-Host "  EOF" -ForegroundColor Magenta
Write-Host ""
Write-Host "  To find the exact CI job name:" -ForegroundColor Yellow
Write-Host "    grep '^\s*name:' $livrablePath/.github/workflows/test.yml" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Verify after setup:" -ForegroundColor Yellow
Write-Host "    gh api repos/$ghOwner/$ghRepo/branches/main/protection -q '.required_status_checks.contexts'" -ForegroundColor Yellow
Write-Host ""

# === STEP 5: recap ===
Write-Host "[5/5] OK." -ForegroundColor Green
Write-Host ""
Write-Host "Project '$Name' created:" -ForegroundColor Cyan
Write-Host "  Deliverable : $livrablePath" -ForegroundColor Cyan
Write-Host "  Meta-project: $metaPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. cd $metaPath (the session cwd = meta-project)."
Write-Host "  2. Run claude and /lead to discover and scope $Name."
Write-Host "  3. Code is written into $livrablePath (via additionalDirectories)."
Write-Host "  4. AFTER merging the first PR: run the branch protection command above."
Write-Host ""

exit 0
