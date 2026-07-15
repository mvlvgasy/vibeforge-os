# check-compiled.ps1 - conformity lint of a lab's COMPILED/CUSTOM layer (agents + skills).
# Born from the first real lab-factory run (2026-07-15): the LLM compilation produced
# almost-conform files (YAML-list tools, missing SKILL frontmatter) despite explicit prose
# instructions. Axiom 1: enforcement > prose - so this lint is the machine gate of
# /lab-factory step 6. ASCII-only patterns (PS 5.1 reads BOM-less .ps1 as ANSI).
#
# Scope: files NOT listed in _method/manifest.json = the custom layer (compiled agents/skills).
# Without a manifest, lints everything under .claude/agents + .claude/skills (-All forces that too).
#
# Checks - agents (*.md, README excluded):
#   A1 frontmatter block present (--- ... ---)
#   A2 name + description non-empty
#   A3 model present
#   A4 tools/disallowedTools on ONE line, simple names (no YAML block list, no Tool(pattern))
# Checks - skills (SKILL.md):
#   S1 frontmatter block present
#   S2 name + description non-empty
#   S3 frontmatter name == folder name
#
# Output: LINT-ERROR <relpath>: <code> <detail> ; STATUS: CONFORM | NONCONFORM (n)
# Exit codes: 0 conform, 1 nonconform, 3 bad input.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LabPath,
    [switch]$All   # lint the whole .claude layer, manifest or not
)
$ErrorActionPreference = "Stop"
$LabPath = (Resolve-Path $LabPath).Path

# Custom-layer detection via manifest (absent entry = compiled/custom)
$tracked = @{}
$manifestPath = Join-Path $LabPath "_method\manifest.json"
$useManifest = (Test-Path $manifestPath) -and (-not $All)
if ($useManifest) {
    $manifest = Get-Content $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
    foreach ($e in $manifest.files.PSObject.Properties) { $tracked[$e.Name] = $true }
}

function Get-Frontmatter([string[]]$lines) {
    # returns lines between the first '---' pair, or $null if no block
    if ($lines.Count -lt 3 -or $lines[0].Trim() -ne "---") { return $null }
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq "---") { $end = $i; break } }
    if ($end -lt 1) { return $null }
    return $lines[1..($end - 1)]
}
function Get-FmValue([string[]]$fm, [string]$key) {
    foreach ($l in $fm) { if ($l -match "^${key}:\s*(.*)$") { return $Matches[1].Trim() } }
    return $null
}

$problems = @()
$checked = 0

# === Agents ===
$agentsDir = Join-Path $LabPath ".claude\agents"
if (Test-Path $agentsDir) {
    Get-ChildItem $agentsDir -Filter *.md -File -Recurse | Where-Object Name -ne "README.md" | ForEach-Object {
        $rel = $_.FullName.Substring($LabPath.Length + 1).Replace('\', '/')
        if ($useManifest -and $tracked[$rel]) { return }   # socle file: not our scope
        $script:checked++
        $lines = Get-Content $_.FullName -Encoding utf8
        $fm = Get-Frontmatter $lines
        if ($null -eq $fm) { $script:problems += "${rel}: A1 no frontmatter block (--- ... ---)"; return }
        foreach ($k in @("name", "description")) {
            $v = Get-FmValue $fm $k
            if (-not $v) { $script:problems += "${rel}: A2 empty or missing '$k'" }
        }
        if (-not (Get-FmValue $fm "model")) { $script:problems += "${rel}: A3 missing 'model'" }
        foreach ($k in @("tools", "disallowedTools")) {
            $v = Get-FmValue $fm $k
            if ($null -eq $v) { continue }                     # key absent: acceptable
            if ($v -eq "" -or $v -eq "[]") {
                # empty value followed by indented '- item' lines = YAML block list
                $idx = -1
                for ($i = 0; $i -lt $fm.Count; $i++) { if ($fm[$i] -match "^${k}:") { $idx = $i; break } }
                if ($idx -ge 0 -and ($idx + 1) -lt $fm.Count -and $fm[$idx + 1] -match '^\s+-\s') {
                    $script:problems += "${rel}: A4 '$k' is a YAML block list - use ONE line of comma-separated simple names"
                }
            }
            if ($v -match '\w+\s*\(') { $script:problems += "${rel}: A4 '$k' contains Tool(pattern) syntax - simple names only (silently breaks the tool palette)" }
        }
    }
}

# === Skills ===
$skillsDir = Join-Path $LabPath ".claude\skills"
if (Test-Path $skillsDir) {
    Get-ChildItem $skillsDir -Directory | ForEach-Object {
        $sk = Join-Path $_.FullName "SKILL.md"
        if (-not (Test-Path $sk)) { return }
        $rel = $sk.Substring($LabPath.Length + 1).Replace('\', '/')
        if ($useManifest -and $tracked[$rel]) { return }
        $script:checked++
        $lines = Get-Content $sk -Encoding utf8
        $fm = Get-Frontmatter $lines
        if ($null -eq $fm) { $script:problems += "${rel}: S1 no frontmatter block (skill will NEVER register)"; return }
        $name = Get-FmValue $fm "name"
        if (-not $name) { $script:problems += "${rel}: S2 empty or missing 'name'" }
        if (-not (Get-FmValue $fm "description")) { $script:problems += "${rel}: S2 empty or missing 'description'" }
        if ($name -and $name -ne $_.Name) { $script:problems += "${rel}: S3 frontmatter name '$name' != folder '$($_.Name)'" }
    }
}

$scopeLabel = if ($useManifest) { "custom layer via manifest" } else { "full .claude layer" }
if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Output "LINT-ERROR $_" }
    Write-Output "STATUS: NONCONFORM ($($problems.Count) error(s) on $checked file(s), $scopeLabel)"
    exit 1
}
Write-Output "STATUS: CONFORM ($checked file(s) checked, $scopeLabel)"
exit 0
