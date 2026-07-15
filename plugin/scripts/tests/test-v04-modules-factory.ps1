# test-v04-modules-factory.ps1 - tests the v0.4 pair:
#   resolve-modules.ps1 (registry validation, transitive closure, unknown id)
#   check-brief.ps1     (marker gate, empty justification, clean brief)
#   new-lab-standalone.ps1 -Modules (modular generation end-to-end)
$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$scriptsDir = Split-Path $PSScriptRoot -Parent

$failed = 0
function Assert([bool]$cond, [string]$label) {
    if ($cond) { Write-Host "  PASS $label" -ForegroundColor Green }
    else { Write-Host "  FAIL $label" -ForegroundColor Red; $script:failed++ }
}

$sandbox = Join-Path $env:TEMP ("vfos-v04-" + (Get-Date -Format "yyyyMMddHHmmss"))
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
try {
    # === 1. resolve-modules ===
    Write-Host "[1] resolve-modules.ps1..." -ForegroundColor Cyan
    $out = & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "resolve-modules.ps1") -Validate
    Assert ($LASTEXITCODE -eq 0 -and ($out -join "`n") -match "STATUS: VALID") "registry valid (full coverage, single ownership)"
    $json = (& powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "resolve-modules.ps1") -Modules "contenu") -join "`n" | ConvertFrom-Json
    $ids = @($json.modules.id)
    Assert (($ids -contains "core") -and ($ids -contains "cadrage") -and ($ids -contains "contenu")) "transitive closure: contenu pulls cadrage + core"
    Assert ($ids.Count -eq 3) "closure is minimal (no unrequested module)"
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try { & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "resolve-modules.ps1") -Modules "nimporte-quoi" 2>&1 | Out-Null } catch {}
    $ErrorActionPreference = $prevEap
    Assert ($LASTEXITCODE -ne 0) "unknown module id rejected"

    # === 2. check-brief ===
    Write-Host "[2] check-brief.ps1..." -ForegroundColor Cyan
    $brief = Join-Path $sandbox "LAB_BRIEF-test.md"
    Copy-Item (Join-Path (Split-Path $scriptsDir -Parent) "templates\LAB_BRIEF.md.tpl") $brief
    $out = & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-brief.ps1") -BriefPath $brief
    Assert ($LASTEXITCODE -eq 1 -and ($out -join "`n") -match "STATUS: BLOCKED") "fresh template -> BLOCKED (markers everywhere)"
    # clean brief: replace all markers (ASCII-safe pattern), fill one justified capability
    $content = (Get-Content $brief -Raw -Encoding utf8) -replace '\[[^\]]*CLARIFIER\]', 'renseigne pour le test'
    $content = $content -replace '\| C1 \|[^\r\n]*', '| C1 | détecter les marchés publics | le client vit des appels d''offres, source de 80% du CA | agent |'
    [System.IO.File]::WriteAllText($brief, $content, $utf8NoBom)
    $out = & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-brief.ps1") -BriefPath $brief
    Assert ($LASTEXITCODE -eq 0 -and ($out -join "`n") -match "STATUS: READY") "completed brief -> READY (exit 0)"
    # empty justification blocks
    $bad = $content -replace '\| C1 \|[^\r\n]*', '| C1 | envoyer des emails | | skill |'
    [System.IO.File]::WriteAllText($brief, $bad, $utf8NoBom)
    $out = & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-brief.ps1") -BriefPath $brief
    Assert ($LASTEXITCODE -eq 1 -and ($out -join "`n") -match "CAPABILITY C1") "capability without justification -> BLOCKED"

    # === 3. modular generation ===
    Write-Host "[3] new-lab-standalone.ps1 -Modules 'build-review'..." -ForegroundColor Cyan
    & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "new-lab-standalone.ps1") -Name "toy-modular" -DestBase $sandbox -Modules "build-review" | Out-Null
    $lab = Join-Path $sandbox "lab-toy-modular"
    Assert (Test-Path (Join-Path $lab ".claude\skills\code-reviewer\SKILL.md")) "selected module skill present (code-reviewer)"
    Assert (Test-Path (Join-Path $lab ".claude\skills\dream\SKILL.md")) "mandatory core skill present (dream)"
    Assert (-not (Test-Path (Join-Path $lab ".claude\skills\business-analyst"))) "unselected module skill ABSENT (business-analyst / cadrage)"
    Assert (-not (Test-Path (Join-Path $lab ".claude\agents\ux.md"))) "unselected module agent ABSENT (ux)"
    $mi = Join-Path $lab "_method\modules-installed.json"
    Assert (Test-Path $mi) "modules-installed.json written"
    if (Test-Path $mi) {
        $miJson = Get-Content $mi -Raw -Encoding utf8 | ConvertFrom-Json
        Assert ((@($miJson.modules.id) -contains "build-review") -and (@($miJson.modules.id) -contains "core") -and (@($miJson.modules.id).Count -eq 2)) "installed modules = core + build-review exactly"
    }
    Assert (Test-Path (Join-Path $lab "_method\manifest.json")) "manifest still written on modular generation"
    $out = & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-drift.ps1") -LabPath $lab
    Assert ($LASTEXITCODE -eq 0) "modular lab pristine (check-drift OK)"
    # CATALOG must not list ghost skills from excluded modules
    $catalog = Get-Content (Join-Path $lab "registres\CATALOG.md") -Raw -Encoding utf8
    Assert ($catalog -notmatch 'business-analyst') "CATALOG has no ghost entry from excluded module"
} finally {
    Remove-Item $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($failed -gt 0) { Write-Host "RESULT: $failed assertion(s) FAILED" -ForegroundColor Red; exit 1 }
Write-Host "RESULT: all assertions passed" -ForegroundColor Green
exit 0
