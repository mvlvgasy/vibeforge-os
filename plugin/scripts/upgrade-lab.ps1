# upgrade-lab.ps1 - applies pending method migrations to a standalone lab, DB-migration
# style: idempotent, ordered, journaled (_method/migration-journal.json).
#
# Safety contract:
#   1. FULL backup of _method/ + every file a migration will touch, BEFORE anything is
#      applied -> <lab>/.upgrade-backups/<timestamp>/  (rollback: -Rollback).
#   2. A file in drift (client customization, per manifest sha) is NEVER overwritten or
#      removed: it is reported as CONFLICT for human arbitration, the rest still applies.
#   3. Already-applied migrations (journal) are skipped; re-running is a no-op.
#
# Migration format (in <socle-repo>/migrations/<YYYY-MM-DD>-<slug>/migration.json):
#   { "id": "...", "from_version": "0.2.0", "to_version": "0.3.0", "description": "...",
#     "add":     [ { "source": "plugin/skills/x/SKILL.md", "target": ".claude/skills/x/SKILL.md" } ],
#     "replace": [ { "source": "...", "target": "..." } ],
#     "remove":  [ ".claude/skills/old/SKILL.md" ],
#     "script":  "apply.ps1" }            // optional, run after file ops, receives -LabPath
#
# Usage: powershell -ExecutionPolicy Bypass -File upgrade-lab.ps1 -LabPath <lab>
#        [-SocleSource <vibeforge-os repo>] [-DryRun] [-Rollback]
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LabPath,
    [string]$SocleSource = "",
    [switch]$DryRun,
    [switch]$Rollback
)
$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$LabPath = (Resolve-Path $LabPath).Path
$methodPath = Join-Path $LabPath "_method"
$manifestPath = Join-Path $methodPath "manifest.json"
$journalPath = Join-Path $methodPath "migration-journal.json"
$backupsRoot = Join-Path $LabPath ".upgrade-backups"
if (-not $SocleSource) { $SocleSource = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
$SocleSource = (Resolve-Path $SocleSource).Path
$migrationsRoot = Join-Path $SocleSource "migrations"

function Get-Sha([string]$path) { (Get-FileHash $path -Algorithm SHA256).Hash.ToLower() }

# === Rollback mode: restore the most recent backup, verbatim ===
if ($Rollback) {
    if (-not (Test-Path $backupsRoot)) { Write-Error "No backup found under $backupsRoot"; exit 3 }
    $latest = Get-ChildItem $backupsRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $latest) { Write-Error "No backup found under $backupsRoot"; exit 3 }
    Write-Host "Rolling back from backup $($latest.Name)..." -ForegroundColor Yellow
    Get-ChildItem $latest.FullName -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($latest.FullName.Length + 1)
        $dest = Join-Path $LabPath $rel
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Copy-Item $_.FullName $dest -Force
    }
    Write-Host "Rollback complete (files restored from $($latest.FullName))."
    Write-Host "Note: files ADDED by the rolled-back upgrade are not deleted automatically - see the upgrade report in the backup folder."
    exit 0
}

# === Preconditions ===
if (-not (Test-Path $manifestPath)) { Write-Error "No manifest.json - run build-manifest.ps1 first (baseline required to protect customizations)."; exit 3 }
if (-not (Test-Path $migrationsRoot)) { Write-Error "No migrations/ directory in socle source: $migrationsRoot"; exit 3 }
$manifest = Get-Content $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json

$journal = @{ applied = @() }
if (Test-Path $journalPath) {
    $j = Get-Content $journalPath -Raw -Encoding utf8 | ConvertFrom-Json
    if ($j.applied) { $journal.applied = @($j.applied) }
}
$appliedIds = @($journal.applied | ForEach-Object { $_.id })

# === Discover pending migrations (lexicographic order = chronological, dated folders) ===
$pending = @()
Get-ChildItem $migrationsRoot -Directory | Sort-Object Name | ForEach-Object {
    $mj = Join-Path $_.FullName "migration.json"
    if (-not (Test-Path $mj)) { Write-Warning "Skipping $($_.Name): no migration.json"; return }
    $m = Get-Content $mj -Raw -Encoding utf8 | ConvertFrom-Json
    if ($appliedIds -contains $m.id) { return }
    $pending += @{ Dir = $_.FullName; Def = $m }
}
if ($pending.Count -eq 0) {
    Write-Host "STATUS: UP-TO-DATE (0 pending migration, $($appliedIds.Count) already applied, socle $($manifest.socle_version))"
    exit 0
}
Write-Host "Pending migrations: $($pending.Count)" -ForegroundColor Cyan
$pending | ForEach-Object { Write-Host "  - $($_.Def.id) : $($_.Def.from_version) -> $($_.Def.to_version) ($($_.Def.description))" }

# === Plan all file operations, classifying against drift ===
function Get-DriftState([string]$targetRel) {
    # returns PRISTINE | DRIFTED | ABSENT | UNTRACKED
    $full = Join-Path $LabPath ($targetRel.Replace('/', '\'))
    $entry = $manifest.files.PSObject.Properties[$targetRel]
    if (-not (Test-Path $full)) { return "ABSENT" }
    if (-not $entry) { return "UNTRACKED" }
    if ((Get-Sha $full) -ne $entry.Value) { return "DRIFTED" }
    return "PRISTINE"
}

$ops = @()       # planned: @{Migration; Kind; Source; Target; Action; Reason}
foreach ($p in $pending) {
    $m = $p.Def
    foreach ($op in @($m.add)) {
        if (-not $op) { continue }
        $state = Get-DriftState $op.target
        $src = Join-Path $SocleSource ($op.source.Replace('/', '\'))
        $action = switch ($state) {
            "ABSENT"    { "APPLY" }
            "PRISTINE"  { if ((Get-Sha $src) -eq (Get-Sha (Join-Path $LabPath ($op.target.Replace('/','\'))))) { "NOOP" } else { "APPLY" } }
            "UNTRACKED" { "CONFLICT" }   # a custom file already lives at the add-target
            "DRIFTED"   { "CONFLICT" }
        }
        $ops += @{ Migration = $m.id; Kind = "add"; Source = $src; Target = $op.target; Action = $action; Reason = $state }
    }
    foreach ($op in @($m.replace)) {
        if (-not $op) { continue }
        $state = Get-DriftState $op.target
        $src = Join-Path $SocleSource ($op.source.Replace('/', '\'))
        $action = switch ($state) {
            "DRIFTED"   { "CONFLICT" }   # client customization: PRESERVE
            "UNTRACKED" { "CONFLICT" }
            "ABSENT"    { "APPLY" }      # vendored file deleted: restore
            "PRISTINE"  { "APPLY" }
        }
        $ops += @{ Migration = $m.id; Kind = "replace"; Source = $src; Target = $op.target; Action = $action; Reason = $state }
    }
    foreach ($target in @($m.remove)) {
        if (-not $target) { continue }
        $state = Get-DriftState $target
        $action = switch ($state) {
            "DRIFTED"   { "CONFLICT" }
            "UNTRACKED" { "CONFLICT" }
            "ABSENT"    { "NOOP" }
            "PRISTINE"  { "APPLY" }
        }
        $ops += @{ Migration = $m.id; Kind = "remove"; Source = $null; Target = $target; Action = $action; Reason = $state }
    }
    foreach ($o in $ops | Where-Object { $_.Migration -eq $m.id -and $_.Kind -ne "remove" -and $_.Action -eq "APPLY" }) {
        if (-not (Test-Path $o.Source)) { Write-Error "Migration $($m.id): source file missing in socle: $($o.Source)"; exit 3 }
    }
}

Write-Host ""
foreach ($o in $ops) { Write-Host ("  [{0,-8}] {1,-7} {2}  ({3})" -f $o.Action, $o.Kind, $o.Target, $o.Reason) }
$conflicts = @($ops | Where-Object { $_.Action -eq "CONFLICT" })

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN - nothing applied. $($conflicts.Count) conflict(s) would be preserved for human arbitration." -ForegroundColor Yellow
    exit 0
}

# === Backup BEFORE applying: full _method/ + every target that will be touched ===
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $backupsRoot $ts
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item $methodPath (Join-Path $backupDir "_method") -Recurse -Force
foreach ($o in $ops | Where-Object { $_.Action -eq "APPLY" -and $_.Target }) {
    $full = Join-Path $LabPath ($o.Target.Replace('/', '\'))
    if (Test-Path $full) {
        $dest = Join-Path $backupDir ($o.Target.Replace('/', '\'))
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Copy-Item $full $dest -Force
    }
}
Write-Host ""
Write-Host "Backup written: $backupDir" -ForegroundColor Green

# === Apply ===
$appliedOps = 0
foreach ($o in $ops | Where-Object { $_.Action -eq "APPLY" }) {
    $full = Join-Path $LabPath ($o.Target.Replace('/', '\'))
    if ($o.Kind -eq "remove") {
        Remove-Item $full -Force
        $manifest.files.PSObject.Properties.Remove($o.Target)
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $full -Parent) | Out-Null
        Copy-Item $o.Source $full -Force
        $newSha = Get-Sha $full
        if ($manifest.files.PSObject.Properties[$o.Target]) { $manifest.files.($o.Target) = $newSha }
        else { $manifest.files | Add-Member -NotePropertyName $o.Target -NotePropertyValue $newSha }
    }
    $appliedOps++
}

# Optional per-migration script, then journal entry
$lastVersion = $manifest.socle_version
foreach ($p in $pending) {
    $m = $p.Def
    if ($m.script) {
        $scriptPath = Join-Path $p.Dir $m.script
        if (Test-Path $scriptPath) {
            Write-Host "Running migration script $($m.id)/$($m.script)..." -ForegroundColor Cyan
            & powershell.exe -ExecutionPolicy Bypass -File $scriptPath -LabPath $LabPath
            if ($LASTEXITCODE -ne 0) { Write-Error "Migration script failed ($($m.id)) - lab left as-is, rollback available: upgrade-lab.ps1 -LabPath `"$LabPath`" -Rollback"; exit 4 }
        }
    }
    $journal.applied += @{ id = $m.id; from_version = $m.from_version; to_version = $m.to_version; applied_on = (Get-Date -Format "yyyy-MM-dd HH:mm"); backup = $ts }
    $lastVersion = $m.to_version
}
$manifest.socle_version = $lastVersion
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), $utf8NoBom)
[System.IO.File]::WriteAllText($journalPath, (@{ applied = $journal.applied } | ConvertTo-Json -Depth 5), $utf8NoBom)

# Report (also dropped next to the backup for traceability)
$reportLines = @("# Upgrade report $ts", "", "Applied: $($pending.Count) migration(s), $appliedOps file op(s). Socle now $lastVersion.", "")
if ($conflicts.Count -gt 0) {
    $reportLines += "## CONFLICTS - customized files PRESERVED, human arbitration required:"
    $conflicts | ForEach-Object { $reportLines += "- [$($_.Kind)] $($_.Target) ($($_.Reason)) - socle version NOT applied on this file" }
}
[System.IO.File]::WriteAllText((Join-Path $backupDir "upgrade-report.md"), (($reportLines -join "`n") + "`n"), $utf8NoBom)

Write-Host ""
if ($conflicts.Count -gt 0) {
    Write-Host "STATUS: APPLIED-WITH-CONFLICTS ($($pending.Count) migration(s), $appliedOps op(s), $($conflicts.Count) preserved customization(s) - see $backupDir\upgrade-report.md)" -ForegroundColor Yellow
    exit 1
}
Write-Host "STATUS: APPLIED ($($pending.Count) migration(s), $appliedOps op(s), socle -> $lastVersion)" -ForegroundColor Green
exit 0
