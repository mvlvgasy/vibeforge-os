# check-drift.ps1 - compares a standalone lab's vendored files against _method/manifest.json.
# A DRIFTED file = client customization to PRESERVE (upgrade-lab.ps1 will never overwrite it
# silently). A MISSING file = vendored file deleted on disk.
# Files present on disk but absent from the manifest are the lab's CUSTOM layer: ignored.
#
# Typed output (one line per finding + final STATUS line), machine-parsable:
#   DRIFTED <relpath>
#   MISSING <relpath>
#   STATUS: OK | DRIFTED | MISSING
# Exit codes: 0 = OK, 1 = DRIFTED only, 2 = MISSING (possibly + DRIFTED), 3 = no manifest.
#
# Usage: powershell -ExecutionPolicy Bypass -File check-drift.ps1 -LabPath <lab> [-Json]
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LabPath,
    [switch]$Json
)
$ErrorActionPreference = "Stop"

$LabPath = (Resolve-Path $LabPath).Path
$manifestPath = Join-Path $LabPath "_method\manifest.json"
if (-not (Test-Path $manifestPath)) {
    if ($Json) { Write-Output (@{ status = "NO_MANIFEST"; drifted = @(); missing = @() } | ConvertTo-Json) }
    else { Write-Output "STATUS: NO_MANIFEST ($manifestPath not found - run build-manifest.ps1)" }
    exit 3
}
$manifest = Get-Content $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json

$drifted = @()
$missing = @()
foreach ($entry in $manifest.files.PSObject.Properties) {
    $rel = $entry.Name
    $expected = $entry.Value
    $full = Join-Path $LabPath ($rel.Replace('/', '\'))
    if (-not (Test-Path $full)) { $missing += $rel; continue }
    $actual = (Get-FileHash $full -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expected) { $drifted += $rel }
}

$status = "OK"
if ($drifted.Count -gt 0) { $status = "DRIFTED" }
if ($missing.Count -gt 0) { $status = "MISSING" }

if ($Json) {
    Write-Output (@{ status = $status; socle_version = $manifest.socle_version; drifted = $drifted; missing = $missing } | ConvertTo-Json)
} else {
    foreach ($d in $drifted) { Write-Output "DRIFTED $d" }
    foreach ($m in $missing) { Write-Output "MISSING $m" }
    $detail = "$($manifest.files.PSObject.Properties.Name.Count) tracked, $($drifted.Count) drifted, $($missing.Count) missing (socle $($manifest.socle_version))"
    Write-Output "STATUS: $status ($detail)"
}
if ($status -eq "MISSING") { exit 2 } elseif ($status -eq "DRIFTED") { exit 1 } else { exit 0 }
