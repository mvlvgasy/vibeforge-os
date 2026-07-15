# check-brief.ps1 - the completeness gate of the lab factory. MACHINE-ENFORCED (axiom 1:
# a guardrail the machine does not execute does not exist): generation is blocked while
# the brief is incomplete. Three deterministic checks:
#   1. zero remaining [À CLARIFIER] markers (accent-insensitive: [A CLARIFIER] too)
#   2. every required section header present
#   3. every capability row (| Cn | ...) has a NON-EMPTY justification column
# Typed output + exit codes: 0 = READY, 1 = BLOCKED, 3 = bad input.
#
# Usage: powershell -ExecutionPolicy Bypass -File check-brief.ps1 -BriefPath <LAB_BRIEF.md>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$BriefPath)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $BriefPath)) { Write-Output "STATUS: NO_BRIEF ($BriefPath not found)"; exit 3 }

$lines = Get-Content $BriefPath -Encoding utf8
$problems = @()

# NOTE encoding: this script stays ASCII-only in its patterns (PS 5.1 reads BOM-less .ps1
# as ANSI -> accented literals in regexes silently stop matching UTF-8 file content).

# 1. Clarification markers: any remaining '...CLARIFIER]' token is a hole
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'CLARIFIER\]') {
        $problems += "MARKER line $($i + 1): $($lines[$i].Trim())"
    }
}

# 2. Required sections: the 8 numbered headers must all exist (ASCII-safe check on '## N.')
$raw = $lines -join "`n"
foreach ($n in 1..8) {
    if ($raw -notmatch "(?m)^## $n\.") { $problems += "SECTION missing: '## $n.' (fixed template header)" }
}

# 3. Capability rows: | Cn | capacité | justification | compilée en |
$capCount = 0
foreach ($l in $lines) {
    if ($l -match '^\s*\|\s*C\d+\s*\|') {
        $capCount++
        $cols = ($l -split '\|') | ForEach-Object { $_.Trim() }
        # cols[0] empty, [1]=Cn, [2]=capacité, [3]=justification, [4]=cible
        if ($cols.Count -lt 5 -or -not $cols[3]) { $problems += "CAPABILITY $($cols[1]): empty justification (no justification = no generated skill/agent)" }
        elseif ($cols[3].Length -lt 15) { $problems += "CAPABILITY $($cols[1]): justification too thin ('$($cols[3])') - say WHY, from the brief/context" }
    }
}
if ($capCount -eq 0) { $problems += "CAPABILITY table empty: at least one justified capability required (section 4)" }

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Output "BLOCKED $_" }
    Write-Output "STATUS: BLOCKED ($($problems.Count) issue(s) - generation refused until the brief is complete)"
    exit 1
}
Write-Output "STATUS: READY ($capCount justified capabilities, all sections present, zero marker)"
exit 0
