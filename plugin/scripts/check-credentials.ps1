# scripts/check-credentials.ps1
# Verify that the Vibeforge credentials are in place and complete.
#
# Paths are resolved relative to this script ($PSScriptRoot), so the plugin
# works wherever it is installed. The credentials file is expected at
# <plugin-root>/credentials/.env (override with -EnvFile).
#
# Usage: pwsh check-credentials.ps1
#        OR: powershell.exe -File check-credentials.ps1
#
# Output: colored table present / missing / placeholder
# Exit code: 0 if all required keys are present, 1 otherwise.

param(
    # Path to the .env file. Defaults to <plugin-root>/credentials/.env
    [string]$EnvFile = ""
)

$ErrorActionPreference = "Continue"

$pluginRoot = Join-Path $PSScriptRoot ".."
if (-not $EnvFile) {
    $EnvFile = Join-Path $pluginRoot "credentials/.env"
}
$envFile = $EnvFile
$envExample = Join-Path $pluginRoot "credentials/.env.example"

Write-Host "Vibeforge - Check credentials" -ForegroundColor Cyan
Write-Host ("File: " + $envFile) -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $envFile)) {
    Write-Host "  .env does not exist." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To create it:" -ForegroundColor Yellow
    Write-Host ("  Copy-Item " + $envExample + " " + $envFile) -ForegroundColor White
    Write-Host "  notepad <path>  # or your editor of choice"
    Write-Host ""
    Write-Host "Then paste your real keys from your vault (1Password / Bitwarden / etc.)." -ForegroundColor Gray
    exit 1
}

# Parse .env (KEY=VALUE format)
# Split on the first = to avoid regex issues in PS 5.1
$envVars = @{}
Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line) { return }
    if ($line.StartsWith("#")) { return }
    $idx = $line.IndexOf("=")
    if ($idx -lt 1) { return }
    $key = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim()
    $envVars[$key] = $value
}

# Detect if Voyage was used recently (presence of a non-mock skills-index.embeddings.json)
$voyageRequired = $false
$embedFile = Join-Path $pluginRoot "skills-index.embeddings.json"
if (Test-Path $embedFile) {
    try {
        $embedContent = Get-Content $embedFile -Raw -ErrorAction Stop
        $mockMarker1 = [char]34 + "provider" + [char]34 + ":" + [char]34 + "mock" + [char]34
        $mockMarker2 = [char]34 + "provider" + [char]34 + ": " + [char]34 + "mock" + [char]34
        $isMock = $false
        if ($embedContent) {
            if ($embedContent.IndexOf($mockMarker1) -ge 0) { $isMock = $true }
            if ($embedContent.IndexOf($mockMarker2) -ge 0) { $isMock = $true }
        }
        if ($embedContent -and -not $isMock) {
            $voyageRequired = $true
        }
    } catch {
        # Cannot read it; assume Voyage is not required
    }
}

$requiredKeys = @(
    @{ Name = "ANTHROPIC_API_KEY"; Required = $false; Purpose = "Fallback if OAuth Pro/Max is unavailable" },
    @{ Name = "VOYAGE_API_KEY"; Required = $voyageRequired; Purpose = "Embeddings for skill-curator (otherwise Grep fallback)" }
)

$missing = 0
$placeholder = 0
$ok = 0

Write-Host ("{0,-25} {1,-13} {2}" -f "Key", "State", "Usage") -ForegroundColor Gray
Write-Host ("-" * 80) -ForegroundColor Gray

foreach ($entry in $requiredKeys) {
    $name = $entry.Name
    $required = $entry.Required
    $purpose = $entry.Purpose
    $value = $envVars[$name]

    $isPlaceholder = $false
    if ($value) {
        if ($value.EndsWith("XXXXX")) {
            $isPlaceholder = $true
        }
    }

    if (-not $value) {
        if ($required) {
            $state = "MISSING"
            $color = "Red"
            $missing++
        } else {
            $state = "absent (OK)"
            $color = "Yellow"
        }
    }
    elseif ($isPlaceholder) {
        $state = "PLACEHOLDER"
        $color = "Yellow"
        $placeholder++
    }
    else {
        $state = "OK"
        $color = "Green"
        $ok++
    }

    Write-Host ("{0,-25} {1,-13} {2}" -f $name, $state, $purpose) -ForegroundColor $color
}

Write-Host ""
$summary = "Summary: " + $ok + " OK | " + $placeholder + " placeholders | " + $missing + " required missing"
Write-Host $summary -ForegroundColor Gray

if ($missing -gt 0) {
    Write-Host ""
    Write-Host ("Action: open " + $envFile + " and fill in the missing keys from your vault.") -ForegroundColor Yellow
    exit 1
}

if ($placeholder -gt 0) {
    Write-Host ""
    Write-Host "Note: some keys are still placeholders (XXXXX). Not blocking if you do not use those features." -ForegroundColor Yellow
}

exit 0
