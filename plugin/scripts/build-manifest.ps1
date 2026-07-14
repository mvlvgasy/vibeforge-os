# build-manifest.ps1 - writes <lab>/_method/manifest.json : socle version + sha256 of every
# vendored method file. The manifest is the baseline that check-drift.ps1 and upgrade-lab.ps1
# compare against: a file whose on-disk sha differs from its manifest sha is a CLIENT
# CUSTOMIZATION (to preserve), never something to overwrite silently.
#
# Called by new-lab-standalone.ps1 at generation time (baseline = freshly stamped files).
# Can be run on an existing lab: the CURRENT state becomes the baseline (warns about it).
#
# Usage: powershell -ExecutionPolicy Bypass -File build-manifest.ps1 -LabPath <lab>
#        [-SocleVersion <x.y.z>] [-SocleCommit <hash>] [-Baseline]
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LabPath,
    [string]$SocleVersion = "",
    [string]$SocleCommit = "",
    [switch]$Baseline   # explicit opt-in when manifesting an EXISTING lab (not at generation)
)
$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$LabPath = (Resolve-Path $LabPath).Path
$methodPath = Join-Path $LabPath "_method"
if (-not (Test-Path $methodPath)) { Write-Error "Not a standalone lab (no _method/): $LabPath"; exit 3 }
$manifestPath = Join-Path $methodPath "manifest.json"
if ((Test-Path $manifestPath) -and -not $Baseline) {
    Write-Error "manifest.json already exists. Re-baselining an existing lab erases drift history - re-run with -Baseline if that is intended."
    exit 3
}

# Vendored method layer = exactly what new-lab-standalone.ps1 stamps and what
# upgrade-lab.ps1 is allowed to touch. The living layer (registres/ content, SOUL,
# CLAUDE.md, projets, agent-contexts) is NEVER in the manifest.
$scopes = @(
    @{ Root = "_method";              Filter = "*" },
    @{ Root = ".claude\agents";       Filter = "*.md" },
    @{ Root = ".claude\skills";       Filter = "*" },
    @{ Root = ".claude\hooks";        Filter = "*" },
    @{ Root = "tools";                Filter = "rebuild-catalog.ps1" }
)
$singleFiles = @(".claude\settings.json")
# _method/ files that describe install state, not vendored content:
$excluded = @("_method/manifest.json", "_method/migration-journal.json")

$files = [ordered]@{}
foreach ($scope in $scopes) {
    $root = Join-Path $LabPath $scope.Root
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -Recurse -File -Filter $scope.Filter | Sort-Object FullName | ForEach-Object {
        $rel = $_.FullName.Substring($LabPath.Length + 1).Replace('\', '/')
        if ($excluded -contains $rel) { return }
        $files[$rel] = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    }
}
foreach ($sf in $singleFiles) {
    $p = Join-Path $LabPath $sf
    if (Test-Path $p) {
        $files[$sf.Replace('\', '/')] = (Get-FileHash $p -Algorithm SHA256).Hash.ToLower()
    }
}
if ($files.Count -eq 0) { Write-Error "No vendored file found under $LabPath - wrong path?"; exit 3 }

# Traceability defaults from the socle repo this script lives in
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $SocleCommit) {
    try { $SocleCommit = (git -C $repoRoot rev-parse --short HEAD 2>$null).Trim() } catch { $SocleCommit = "unknown" }
    if (-not $SocleCommit) { $SocleCommit = "unknown" }
}
if (-not $SocleVersion) {
    $pluginJson = Join-Path (Split-Path $PSScriptRoot -Parent) ".claude-plugin\plugin.json"
    if (Test-Path $pluginJson) {
        try { $SocleVersion = (Get-Content $pluginJson -Raw -Encoding utf8 | ConvertFrom-Json).version } catch { $SocleVersion = "unknown" }
    } else { $SocleVersion = "unknown" }
}

$manifest = [ordered]@{
    manifest_version = 1
    socle_version    = $SocleVersion
    socle_commit     = $SocleCommit
    generated_on     = (Get-Date -Format "yyyy-MM-dd HH:mm")
    generator        = "build-manifest.ps1 v1.0 (vibeforge-os)"
    baseline_mode    = [bool]$Baseline
    files            = $files
}
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), $utf8NoBom)

if ($Baseline) { Write-Warning "Baseline mode: current on-disk state recorded as pristine (any pre-existing customization is now invisible to check-drift)." }
Write-Host "manifest.json written: $($files.Count) files hashed (socle $SocleVersion @ $SocleCommit)"
exit 0
