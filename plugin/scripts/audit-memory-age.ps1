# audit-memory-age.ps1
# Support script for the /audit-memory-age skill.
# Scans every MEMORY.md (3 levels per R009), computes age, cross-checks metrics.
# Also checks the R016 word-count ceiling (WARNING >=450, VIOLATION >=500).
# Output: a markdown report in <BaseDir>/vibeforge/metrics/memory-audit-<timestamp>.md
# Exit code: 1 if at least one MEMORY.md is in R016 VIOLATION (>=500 words), else 0.
#
# Paths point at the USER workspace, not the plugin. By default the scan runs
# from the current directory; override with -BaseDir to point at your stack root
# (the folder that contains your method repo and your lab-* folders).

param(
    [int]$Threshold = 14,
    [int]$WordWarnThreshold = 450,
    [int]$WordViolationThreshold = 500,
    # Root of your workspace: the folder containing the method repo and lab-* dirs.
    # Defaults to the current working directory.
    [string]$BaseDir = (Get-Location).Path
)

$ErrorActionPreference = "SilentlyContinue"

$now = Get-Date
$reportDate = $now.ToString("yyyy-MM-dd HH:mm")
$reportSlug = $now.ToString("yyyy-MM-dd-HHmm")
$vibeforgeRoot = Join-Path $BaseDir "vibeforge"

function Get-MemoryWordCount {
    param([string]$Path)
    $content = Get-Content -Path $Path -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) { return 0 }
    $words = $content -split '\s+' | Where-Object { $_.Length -gt 0 }
    return $words.Count
}

# ===========================================
# Step 1 - Scan MEMORY.md at 3 levels
# ===========================================

$memoryFiles = @()

# Universal level
$universalDir = Join-Path $vibeforgeRoot "agent-contexts"
if (Test-Path $universalDir) {
    Get-ChildItem -Path $universalDir -Recurse -Filter "MEMORY.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $agentName = Split-Path -Leaf (Split-Path -Parent $_.FullName)
        $memoryFiles += [PSCustomObject]@{
            Path = $_.FullName
            Agent = $agentName
            Level = "universal"
            Mtime = $_.LastWriteTime
            Words = Get-MemoryWordCount -Path $_.FullName
        }
    }
}

# Lab level
Get-ChildItem -Path $BaseDir -Filter "lab-*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $labRoot = $_.FullName
    $labName = $_.Name
    $labCtx = Join-Path $labRoot "agent-contexts"
    if (Test-Path $labCtx) {
        Get-ChildItem -Path $labCtx -Recurse -Filter "MEMORY.md" -ErrorAction SilentlyContinue | ForEach-Object {
            $agentName = Split-Path -Leaf (Split-Path -Parent $_.FullName)
            $memoryFiles += [PSCustomObject]@{
                Path = $_.FullName
                Agent = $agentName
                Level = "lab ($labName)"
                Mtime = $_.LastWriteTime
                Words = Get-MemoryWordCount -Path $_.FullName
            }
        }
    }
}

# Project level
Get-ChildItem -Path $BaseDir -Filter "lab-*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $labRoot = $_.FullName
    $labName = $_.Name
    $projectsMetaDir = Join-Path $labRoot "projets-meta"
    if (Test-Path $projectsMetaDir) {
        Get-ChildItem -Path $projectsMetaDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $projectName = $_.Name
            $projectCtx = Join-Path $_.FullName "agent-contexts"
            if (Test-Path $projectCtx) {
                Get-ChildItem -Path $projectCtx -Recurse -Filter "MEMORY.md" -ErrorAction SilentlyContinue | ForEach-Object {
                    $agentName = Split-Path -Leaf (Split-Path -Parent $_.FullName)
                    $memoryFiles += [PSCustomObject]@{
                        Path = $_.FullName
                        Agent = $agentName
                        Level = "project ($labName/$projectName)"
                        Mtime = $_.LastWriteTime
                        Words = Get-MemoryWordCount -Path $_.FullName
                    }
                }
            }
        }
    }
}

# ===========================================
# Step 2 - Cross-check metrics
# ===========================================

$metricsFile = Join-Path $vibeforgeRoot "metrics\events.jsonl"
$invocationsByAgent = @{}

if (Test-Path $metricsFile) {
    $cutoff = $now.AddDays(-$Threshold)
    Get-Content $metricsFile -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $evt = $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($evt.kind -eq "agent_delegated" -and $evt.agent) {
                $ts = [datetime]$evt.ts
                if ($ts -gt $cutoff) {
                    $agentName = $evt.agent -replace "^vibeforge:", ""
                    if (-not $invocationsByAgent.ContainsKey($agentName)) {
                        $invocationsByAgent[$agentName] = 0
                    }
                    $invocationsByAgent[$agentName]++
                }
            }
        } catch {}
    }
}

# ===========================================
# Step 3 - Pending markers
# ===========================================

$pendingMarkers = @()
Get-ChildItem -Path $universalDir -Recurse -Filter ".memory-update-pending.md" -ErrorAction SilentlyContinue -Force | ForEach-Object {
    $agentName = Split-Path -Leaf (Split-Path -Parent $_.FullName)
    $pendingMarkers += [PSCustomObject]@{
        Agent = $agentName
        Path = $_.FullName
        Mtime = $_.LastWriteTime
    }
}

# ===========================================
# Step 4 - Classify agents
# ===========================================

$amnesicAgents = @()
$healthyAgents = @()
$inactiveAgents = @()

foreach ($m in $memoryFiles) {
    $ageDays = [int]($now - $m.Mtime).TotalDays
    $invokes = if ($invocationsByAgent.ContainsKey($m.Agent)) { $invocationsByAgent[$m.Agent] } else { 0 }

    if ($ageDays -gt $Threshold -and $invokes -gt 3) {
        $amnesicAgents += $m
    } elseif ($invokes -eq 0) {
        $inactiveAgents += $m
    } else {
        $healthyAgents += $m
    }
}

# ===========================================
# Step 4bis - R016 word-count ceiling (WARNING >= 450, VIOLATION >= 500)
# ===========================================

$wordViolations = @($memoryFiles | Where-Object { $_.Words -ge $WordViolationThreshold })
$wordWarnings = @($memoryFiles | Where-Object { $_.Words -ge $WordWarnThreshold -and $_.Words -lt $WordViolationThreshold })

$wordcountStatus = "OK"
if ($wordViolations.Count -gt 0) {
    $wordcountStatus = "VIOLATION"
} elseif ($wordWarnings.Count -gt 0) {
    $wordcountStatus = "WARNING"
}

# Pyramid
$pyramidUniv = ($memoryFiles | Where-Object { $_.Level -eq "universal" }).Count
$pyramidLab = ($memoryFiles | Where-Object { $_.Level -like "lab*" }).Count
$pyramidProj = ($memoryFiles | Where-Object { $_.Level -like "project*" }).Count

$pyramidTotal = [Math]::Max(1, $pyramidUniv + $pyramidLab + $pyramidProj)
$pctUniv = [Math]::Round($pyramidUniv * 100.0 / $pyramidTotal, 1)
$pctLab = [Math]::Round($pyramidLab * 100.0 / $pyramidTotal, 1)
$pctProj = [Math]::Round($pyramidProj * 100.0 / $pyramidTotal, 1)

# ===========================================
# Step 5 - Build markdown report
# ===========================================

$totalMemories = $memoryFiles.Count

$lines = @(
    "# MEMORY audit report -- $reportDate",
    "",
    "Threshold applied: $Threshold days",
    "",
    "## Summary",
    "",
    "- **Agents audited**: $totalMemories MEMORY.md found (all 3 levels)",
    "- **Healthy agents** (age <= ${Threshold}d AND >0 invocations): $($healthyAgents.Count)",
    "- **Amnesic agents** (age > ${Threshold}d AND >3 invocations in the window): $($amnesicAgents.Count)",
    "- **Inactive agents** (0 invocations in the window): $($inactiveAgents.Count)",
    "- **Pending R009 markers unresolved**: $($pendingMarkers.Count)",
    "- **R016 word-count ceiling**: STATUS $wordcountStatus ($($wordViolations.Count) VIOLATION >= $WordViolationThreshold words, $($wordWarnings.Count) WARNING >= $WordWarnThreshold words)",
    "",
    "## Current pyramid (R009 target: ~5/15/80%)",
    "",
    "- Universal level: $pyramidUniv MEMORY ($pctUniv %)",
    "- Lab level: $pyramidLab MEMORY ($pctLab %)",
    "- Project level: $pyramidProj MEMORY ($pctProj %)",
    "",
    "**Pyramid verdict**: "
)

if ($pyramidProj -eq 0 -and $pyramidLab -eq 0) {
    $lines += "Everything is at the universal level -- R009 not yet implemented in practice (expected state in phase 1 of progressive migration)."
} elseif ($pctUniv -gt 30) {
    $lines += "Inverted pyramid -- lots of universal, little project. Drift detected, dispatch traffic-controller for demotions."
} else {
    $lines += "Healthy pyramid."
}

$lines += @(
    "",
    "## Detail per agent",
    "",
    "| Agent | Level | Age (d) | Invocations | Words | Status |",
    "|-------|-------|---------|-------------|-------|--------|"
)

foreach ($a in ($memoryFiles | Sort-Object Agent, Level)) {
    $ageDays = [int]($now - $a.Mtime).TotalDays
    $invokes = if ($invocationsByAgent.ContainsKey($a.Agent)) { $invocationsByAgent[$a.Agent] } else { 0 }
    if ($ageDays -gt $Threshold -and $invokes -gt 3) {
        $status = "AMNESIC"
    } elseif ($invokes -eq 0) {
        $status = "inactive"
    } else {
        $status = "OK"
    }
    if ($a.Words -ge $WordViolationThreshold) {
        $status = "$status + word VIOLATION"
    } elseif ($a.Words -ge $WordWarnThreshold) {
        $status = "$status + word WARNING"
    }
    $lines += "| $($a.Agent) | $($a.Level) | $ageDays | $invokes | $($a.Words) | $status |"
}

$lines += @(
    "",
    "## R016 word-count ceiling (WARNING >= $WordWarnThreshold, VIOLATION >= $WordViolationThreshold)",
    "",
    "STATUS: $wordcountStatus",
    ""
)
if ($wordViolations.Count -eq 0 -and $wordWarnings.Count -eq 0) {
    $lines += "*(no MEMORY.md above $WordWarnThreshold words -- good sign)*"
} else {
    $lines += "| Agent | Level | Words | Status |"
    $lines += "|-------|-------|-------|--------|"
    foreach ($v in ($wordViolations | Sort-Object -Property Words -Descending)) {
        $lines += "| $($v.Agent) | $($v.Level) | $($v.Words) | VIOLATION |"
    }
    foreach ($w in ($wordWarnings | Sort-Object -Property Words -Descending)) {
        $lines += "| $($w.Agent) | $($w.Level) | $($w.Words) | WARNING |"
    }
}

$lines += @("", "## Pending R009 markers", "")
if ($pendingMarkers.Count -eq 0) {
    $lines += "*(no pending markers -- good sign)*"
} else {
    $lines += "| Agent | Marker date | Path |"
    $lines += "|-------|-------------|------|"
    foreach ($p in $pendingMarkers) {
        $lines += "| $($p.Agent) | $($p.Mtime.ToString('yyyy-MM-dd HH:mm')) | $($p.Path) |"
    }
}

$lines += @(
    "",
    "## Actionable recommendations",
    ""
)

if ($amnesicAgents.Count -gt 0) {
    $lines += "### Amnesic agents to refresh"
    $lines += ""
    foreach ($a in $amnesicAgents | Select-Object -First 5) {
        $ageDays = [int]($now - $a.Mtime).TotalDays
        $invokes = if ($invocationsByAgent.ContainsKey($a.Agent)) { $invocationsByAgent[$a.Agent] } else { 0 }
        $lines += "- **$($a.Agent)** ($($a.Level), ${ageDays}d without update, ${invokes} invocations): invoke in explicit update mode"
    }
    $lines += ""
}

if ($wordViolations.Count -gt 0) {
    $lines += "### MEMORY in R016 VIOLATION (>= $WordViolationThreshold words) to prune"
    $lines += ""
    foreach ($v in $wordViolations | Sort-Object -Property Words -Descending) {
        $lines += "- **$($v.Agent)** ($($v.Level), $($v.Words) words): prune the oldest / least-cited entries to $($v.Path -replace 'MEMORY\.md$', 'journal.md') BEFORE any new write"
    }
    $lines += ""
}

if ($pendingMarkers.Count -gt 0) {
    $lines += "### Pending R009 markers to handle"
    $lines += ""
    foreach ($p in $pendingMarkers) {
        $lines += "- **$($p.Agent)**: invoke to process $($p.Path) then delete the marker"
    }
    $lines += ""
}

if ($amnesicAgents.Count -eq 0 -and $pendingMarkers.Count -eq 0 -and $wordViolations.Count -eq 0) {
    $lines += "No action required. MEMORY system is healthy."
    $lines += ""
}

$lines += @(
    "---",
    "",
    "*Report generated by scripts/audit-memory-age.ps1 (skill /audit-memory-age).*",
    "*R009: agent MEMORY scoped across 3 levels. R008: tri-layer session close.*"
)

# ===========================================
# Write report
# ===========================================

$reportDir = Join-Path $vibeforgeRoot "metrics"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$reportPath = Join-Path $reportDir "memory-audit-$reportSlug.md"
Set-Content -Path $reportPath -Value ($lines -join "`n") -Encoding utf8

Write-Output "Report written: $reportPath"
Write-Output "- $totalMemories MEMORY audited"
Write-Output "- $($healthyAgents.Count) healthy / $($amnesicAgents.Count) amnesic / $($inactiveAgents.Count) inactive"
Write-Output "- $($pendingMarkers.Count) pending markers"
Write-Output "STATUS: $wordcountStatus"
Write-Output "- R016 word-count ceiling: $($wordViolations.Count) VIOLATION (>= $WordViolationThreshold words) / $($wordWarnings.Count) WARNING (>= $WordWarnThreshold words)"
foreach ($v in $wordViolations | Sort-Object -Property Words -Descending) {
    Write-Output "  [VIOLATION] $($v.Agent) ($($v.Level)): $($v.Words) words -- $($v.Path)"
}
foreach ($w in $wordWarnings | Sort-Object -Property Words -Descending) {
    Write-Output "  [WARNING]   $($w.Agent) ($($w.Level)): $($w.Words) words -- $($w.Path)"
}

if ($wordViolations.Count -gt 0) {
    exit 1
}
exit 0
