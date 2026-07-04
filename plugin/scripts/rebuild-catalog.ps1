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