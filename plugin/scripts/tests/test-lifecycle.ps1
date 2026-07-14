# test-lifecycle.ps1 - end-to-end test of the v0.3 lab lifecycle trio:
#   build-manifest.ps1 (via new-lab-standalone.ps1) / check-drift.ps1 / upgrade-lab.ps1
#
# Scenario (the one that matters): generate a toy lab -> verify manifest sha by hand ->
# customize one vendored file (artificial drift) -> apply a toy migration -> assert the
# customization was PRESERVED, the rest applied, backup + journal exist, re-run = no-op.
#
# Usage: powershell -ExecutionPolicy Bypass -File test-lifecycle.ps1
$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$scriptsDir = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path (Split-Path $scriptsDir -Parent) -Parent

$failed = 0
function Assert([bool]$cond, [string]$label) {
    if ($cond) { Write-Host "  PASS $label" -ForegroundColor Green }
    else { Write-Host "  FAIL $label" -ForegroundColor Red; $script:failed++ }
}

$sandbox = Join-Path $env:TEMP ("vfos-test-" + (Get-Date -Format "yyyyMMddHHmmss"))
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
try {
    # === 1. build-manifest (via generator) ===
    Write-Host "[1] Generating toy lab (new-lab-standalone.ps1)..." -ForegroundColor Cyan
    & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "new-lab-standalone.ps1") -Name "toy-test" -DestBase $sandbox | Out-Null
    $lab = Join-Path $sandbox "lab-toy-test"
    $manifestPath = Join-Path $lab "_method\manifest.json"
    Assert (Test-Path $manifestPath) "manifest.json exists after generation"
    $manifest = Get-Content $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert ($manifest.files.PSObject.Properties.Name.Count -gt 50) "manifest tracks >50 vendored files ($($manifest.files.PSObject.Properties.Name.Count))"
    # sha verifiable by hand: recompute one entry independently
    $probe = $manifest.files.PSObject.Properties | Where-Object { $_.Name -like ".claude/agents/*" } | Select-Object -First 1
    $recomputed = (Get-FileHash (Join-Path $lab $probe.Name.Replace('/','\')) -Algorithm SHA256).Hash.ToLower()
    Assert ($recomputed -eq $probe.Value) "manifest sha256 matches independent recompute ($($probe.Name))"

    # === 2. check-drift ===
    Write-Host "[2] check-drift.ps1..." -ForegroundColor Cyan
    $out = & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-drift.ps1") -LabPath $lab
    Assert ($LASTEXITCODE -eq 0 -and ($out -join "`n") -match "STATUS: OK") "pristine lab -> STATUS: OK (exit 0)"
    # artificial drift: client customizes a vendored skill
    $customized = Join-Path $lab ".claude\skills\cloture-session\SKILL.md"
    Add-Content -Path $customized -Value "`n<!-- client customization -->" -Encoding UTF8
    $customizedRel = ".claude/skills/cloture-session/SKILL.md"
    # artificial missing: client deletes a vendored hook
    $deleted = Get-ChildItem (Join-Path $lab ".claude\hooks") -Filter *.ps1 | Select-Object -First 1
    $deletedRel = $deleted.FullName.Substring($lab.Length + 1).Replace('\','/')
    Remove-Item $deleted.FullName -Force
    $out = & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "check-drift.ps1") -LabPath $lab
    $txt = $out -join "`n"
    Assert ($txt -match [regex]::Escape("DRIFTED $customizedRel")) "customized file listed as DRIFTED"
    Assert ($txt -match [regex]::Escape("MISSING $deletedRel")) "deleted file listed as MISSING"
    Assert ($LASTEXITCODE -eq 2) "exit code 2 when MISSING present"

    # === 3. upgrade-lab with a toy migration ===
    Write-Host "[3] upgrade-lab.ps1 (toy migration)..." -ForegroundColor Cyan
    # toy socle source: real repo layout, own migrations dir
    $toySocle = Join-Path $sandbox "toy-socle"
    New-Item -ItemType Directory -Force -Path (Join-Path $toySocle "payload") | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $toySocle "payload\NEW-SKILL.md"), "new vendored skill v2`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $toySocle "payload\REPLACEMENT.md"), "upgraded content`n", $utf8NoBom)
    $migDir = Join-Path $toySocle "migrations\2026-07-14-toy"
    New-Item -ItemType Directory -Force -Path $migDir | Out-Null
    $migration = @{
        id = "2026-07-14-toy"; from_version = "0.3.0"; to_version = "0.3.1"
        description = "toy: add one file, replace one pristine file, replace one CUSTOMIZED file"
        add = @(@{ source = "payload/NEW-SKILL.md"; target = ".claude/skills/toy-new/SKILL.md" })
        replace = @(
            @{ source = "payload/REPLACEMENT.md"; target = ".claude/skills/dream/SKILL.md" },      # pristine -> applied
            @{ source = "payload/REPLACEMENT.md"; target = $customizedRel }                        # drifted  -> preserved
        )
        remove = @()
    }
    [System.IO.File]::WriteAllText((Join-Path $migDir "migration.json"), ($migration | ConvertTo-Json -Depth 5), $utf8NoBom)

    $customContentBefore = Get-Content $customized -Raw
    $out = & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "upgrade-lab.ps1") -LabPath $lab -SocleSource $toySocle
    $txt = $out -join "`n"
    Assert ($LASTEXITCODE -eq 1 -and $txt -match "APPLIED-WITH-CONFLICTS") "upgrade reports APPLIED-WITH-CONFLICTS (exit 1)"
    Assert (Test-Path (Join-Path $lab ".claude\skills\toy-new\SKILL.md")) "added file exists"
    Assert ((Get-Content (Join-Path $lab ".claude\skills\dream\SKILL.md") -Raw) -match "upgraded content") "pristine file replaced"
    Assert ((Get-Content $customized -Raw) -eq $customContentBefore) "CUSTOMIZED file untouched (preserved)"
    $backup = Get-ChildItem (Join-Path $lab ".upgrade-backups") -Directory | Select-Object -First 1
    Assert ($null -ne $backup -and (Test-Path (Join-Path $backup.FullName "_method"))) "full _method/ backup exists"
    Assert (Test-Path (Join-Path $backup.FullName "upgrade-report.md")) "upgrade-report.md written next to backup"
    $journal = Get-Content (Join-Path $lab "_method\migration-journal.json") -Raw -Encoding utf8 | ConvertFrom-Json
    Assert (@($journal.applied).id -contains "2026-07-14-toy") "migration journaled"
    $manifest2 = Get-Content $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert ($manifest2.socle_version -eq "0.3.1") "manifest socle_version advanced to to_version"
    # idempotence
    $out = & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "upgrade-lab.ps1") -LabPath $lab -SocleSource $toySocle
    Assert ($LASTEXITCODE -eq 0 -and ($out -join "`n") -match "UP-TO-DATE") "re-run is a no-op (UP-TO-DATE)"

    # === 4. rollback ===
    Write-Host "[4] upgrade-lab.ps1 -Rollback..." -ForegroundColor Cyan
    & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "upgrade-lab.ps1") -LabPath $lab -SocleSource $toySocle -Rollback | Out-Null
    Assert ((Get-Content (Join-Path $lab ".claude\skills\dream\SKILL.md") -Raw) -notmatch "upgraded content") "rollback restored the replaced file"
} finally {
    Remove-Item $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($failed -gt 0) { Write-Host "RESULT: $failed assertion(s) FAILED" -ForegroundColor Red; exit 1 }
Write-Host "RESULT: all assertions passed" -ForegroundColor Green
exit 0
