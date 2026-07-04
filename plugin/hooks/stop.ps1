# Stop hook -- Vibeforge
# Capitalization reminder if registers were not modified despite significant
# activity. Appends to the log + writes a reminder into
# .claude/last-stop-reminder.md if relevant.

$ErrorActionPreference = "SilentlyContinue"

$cwd = (Get-Location).Path
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Logs setup
$logDir = Join-Path $cwd ".claude\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "stop-hook.log"

"$timestamp [Stop] Turn finished in $cwd" | Out-File -FilePath $logFile -Append -Encoding utf8

# === Verification flag -- completion-claim detection ===
# Reads the session transcript to match claim patterns, drops a flag in
# <cwd>/.claude/verification-required.md (read by /verify-completion).
# Append-only. Non-blocking.
try {
    $rawStopInput = [Console]::In.ReadToEnd()
    if ($rawStopInput) {
        $stopPayload = $rawStopInput | ConvertFrom-Json
        $transcriptPath = $stopPayload.transcript_path
        if ($transcriptPath -and (Test-Path $transcriptPath)) {
            # Tail of the last lines (60 is enough for the last assistant turn)
            $tail = Get-Content -Path $transcriptPath -Tail 60 -ErrorAction SilentlyContinue
            # Filter assistant messages and concatenate the text
            $assistantText = ""
            foreach ($line in $tail) {
                try {
                    $obj = $line | ConvertFrom-Json
                    if ($obj.type -eq "assistant" -and $obj.message.content) {
                        foreach ($block in $obj.message.content) {
                            if ($block.type -eq "text" -and $block.text) {
                                $assistantText += $block.text + "`n"
                            }
                        }
                    }
                } catch { continue }
            }
            # Patterns FR+EN, whole words, case-insensitive
            $patterns = @(
                "j'ai implemente", "j'ai cree", "j'ai modifie",
                "j'ai ajoute", "j'ai corrige", "fix applique",
                "tests passent", "fonctionne maintenant",
                "implemented", "fixed it", "tests pass", "task complete", "all done"
            )
            # IMPORTANT: do not use $matches (automatic PS variable overwritten by -match).
            $claimMatches = @()
            foreach ($p in $patterns) {
                $idx = $assistantText.IndexOf($p, [System.StringComparison]::OrdinalIgnoreCase)
                if ($idx -ge 0) {
                    $ctxStart = [Math]::Max(0, $idx - 80)
                    $ctxLen = [Math]::Min(200, $assistantText.Length - $ctxStart)
                    $ctx = $assistantText.Substring($ctxStart, $ctxLen) -replace "`r?`n", " "
                    $claimMatches += [PSCustomObject]@{ pattern = $p; context = $ctx }
                }
            }
            if ($claimMatches.Count -gt 0) {
                $vrFile = Join-Path $cwd ".claude\verification-required.md"
                if (-not (Test-Path $vrFile)) {
                    $header = @(
                        "# Verification required (auto-detected by Stop hook)",
                        "",
                        "> Completion patterns detected in the agent's response.",
                        "> Invoke /verify-completion to validate each claim with concrete evidence.",
                        ""
                    ) -join "`n"
                    Set-Content -Path $vrFile -Value $header -Encoding utf8
                }
                $entry = @("", "## $timestamp")
                foreach ($m in $claimMatches) {
                    $entry += "- Matched pattern: ``$($m.pattern)``"
                    $entry += "- Context: ``$($m.context)``"
                }
                $entry += ""
                Add-Content -Path $vrFile -Value ($entry -join "`n") -Encoding utf8
                "$timestamp [Stop] $($claimMatches.Count) completion claim(s) detected -> $vrFile" | Out-File -FilePath $logFile -Append -Encoding utf8
                # Event metrics
                try {
                    $metricsDir = Join-Path $cwd ".claude\metrics"
                    if (-not (Test-Path $metricsDir)) {
                        New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
                    }
                    $evt = [ordered]@{
                        ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                        kind = "completion_claim"
                        cwd = "$cwd"
                        session = $env:CLAUDE_CODE_SESSION_ID
                        claims_count = $claimMatches.Count
                    }
                    Add-Content -Path (Join-Path $metricsDir "events.jsonl") -Value ($evt | ConvertTo-Json -Compress -Depth 4) -Encoding utf8
                } catch {}
            }
        }
    }
} catch {
    "$timestamp [Stop] verification check failed: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append -Encoding utf8
}

# === R018: ACTIVE /save-cadrage nudge at end of turn (decision block + reason) ===
# If framing context (MEMORY-cadrage.md present) + significant activity + memory
# not flushed recently -> we BLOCK the stop and inject the instruction to run
# /save-cadrage. Claude obeys then re-stops; that 2nd stop has
# stop_hook_active=true (official Claude Code anti-loop guard) -> we no longer
# block. Secondary guard: if MEMORY-cadrage modified < 10 min ago, no block.
try {
    $stopHookActive = $false
    if ($stopPayload -and $stopPayload.stop_hook_active) { $stopHookActive = $true }

    if (-not $stopHookActive) {
        $memFiles = @()
        $rootMem = Join-Path $cwd "MEMORY-cadrage.md"
        if (Test-Path $rootMem) { $memFiles += (Get-Item $rootMem) }
        $metaDir = Join-Path $cwd "projets-meta"
        if (Test-Path $metaDir) {
            $memFiles += Get-ChildItem -Path $metaDir -Recurse -Filter "MEMORY-cadrage.md" -ErrorAction SilentlyContinue
        }

        if ($memFiles.Count -gt 0) {
            $oneHourAgo = (Get-Date).AddHours(-1)
            $recentWork = Get-ChildItem -Path $cwd -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                $_.LastWriteTime -gt $oneHourAgo -and
                $_.FullName -notmatch "\\\.git\\" -and
                $_.FullName -notmatch "\\\.claude\\" -and
                $_.FullName -notmatch "\\node_modules\\" -and
                $_.Name -ne "MEMORY-cadrage.md"
            }
            $workCount = ($recentWork | Measure-Object).Count
            $mostRecentMem = ($memFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
            $memAgeMin = ((Get-Date) - $mostRecentMem.LastWriteTime).TotalMinutes

            if ($workCount -ge 5 -and $memAgeMin -gt 10) {
                $reason = "R018: framing activity detected ($workCount files touched in the last hour) but MEMORY-cadrage.md has not been updated for $([int]$memAgeMin) min. Before stopping, run /save-cadrage to flush decisions, roadmap and key facts to disk (merge, not overwrite). If there is genuinely nothing new to save, ignore this reminder and stop."
                $blockObj = [ordered]@{ decision = "block"; reason = $reason }
                "$timestamp [Stop] R018 BLOCK -> nudge /save-cadrage (work=$workCount, memAge=$([int]$memAgeMin)min)" | Out-File -FilePath $logFile -Append -Encoding utf8
                Write-Output ($blockObj | ConvertTo-Json -Compress)
                exit 0
            } else {
                "$timestamp [Stop] R018 no block (work=$workCount, memAge=$([int]$memAgeMin)min)" | Out-File -FilePath $logFile -Append -Encoding utf8
            }
        }
    } else {
        "$timestamp [Stop] stop_hook_active=true, skip R018 block (anti-loop)" | Out-File -FilePath $logFile -Append -Encoding utf8
    }
} catch {
    "$timestamp [Stop] R018 block check failed: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append -Encoding utf8
}

# === Heuristic: are we in a lab or a project? ===
$inLabOrProject = $false
$registresDir = $null
$contextLabel = "vibeforge-root"

# Case 1: we are in a lab (has its own /registres/ or /registers/)
$registresCandidate = Join-Path $cwd "registres"
$registersCandidate = Join-Path $cwd "registers"
if (Test-Path $registresCandidate) {
    $registresDir = $registresCandidate
    $inLabOrProject = $true
    $contextLabel = if ($cwd -match "([^\\/]+)$") { $Matches[1] } else { "lab" }
} elseif (Test-Path $registersCandidate) {
    $registresDir = $registersCandidate
    $inLabOrProject = $true
    $contextLabel = if ($cwd -match "([^\\/]+)$") { $Matches[1] } else { "lab" }
}

# Case 2: we are in a project under a generic deliverable layout (projets/<X> or projects/<X>)
if (-not $inLabOrProject -and ($cwd -match "proje(?:ts|cts)[\\/]([^\\/]+)")) {
    $projName = $Matches[1]
    $registresDir = Join-Path $cwd "registres"
    if (-not (Test-Path $registresDir)) { $registresDir = Join-Path $cwd "registers" }
    if (-not (Test-Path $registresDir)) {
        # The project does not yet have local registers, that is OK, skip
        $inLabOrProject = $false
    } else {
        $inLabOrProject = $true
        $contextLabel = "project-$projName"
    }
}

# === If we are in the pure method root, no check ===
if (-not $inLabOrProject) {
    "$timestamp [Stop] CWD not in a lab/project, skip capitalization check" | Out-File -FilePath $logFile -Append -Encoding utf8
    exit 0
}

# === Significant-activity detection in this session ===
# Simple heuristic: how many files modified in the CWD in the last hour?
$oneHourAgo = (Get-Date).AddHours(-1)
$modifiedFiles = Get-ChildItem -Path $cwd -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $_.LastWriteTime -gt $oneHourAgo -and
    $_.FullName -notmatch "\\\.git\\" -and
    $_.FullName -notmatch "\\\.claude\\logs\\" -and
    $_.FullName -notmatch "\\node_modules\\"
}

$activityCount = $modifiedFiles.Count
$registresModified = $modifiedFiles | Where-Object { $_.FullName -match "\\registe?r?s\\" -or $_.FullName -match "\\registres\\" } | Measure-Object | Select-Object -ExpandProperty Count

"$timestamp [Stop] context=$contextLabel activity=$activityCount registers_modif=$registresModified" | Out-File -FilePath $logFile -Append -Encoding utf8

# === Reminder if activity BUT no register update ===
if ($activityCount -ge 5 -and $registresModified -eq 0) {
    $reminderFile = Join-Path $cwd ".claude\last-stop-reminder.md"
    $reminderContent = @"
# Capitalization reminder -- $timestamp

Activity detected in this session ($activityCount files modified) but NO local register was updated.

**You should probably:**
1. At minimum: append an entry to \`registers/journal.md\`
2. If you hit friction -> append to \`registers/blockers.md\`
3. If you learned a lesson -> append to \`registers/learnings.md\`
4. If you detected a hallucination -> append to \`registers/eval.md\`

**Or**: run \`/cloture-session\` for a full audit (recommended at the end of a significant session).

> This file is auto-generated by the stop.ps1 hook. It will be re-read at the next session start if not deleted.

## Detected activity (top 10)
$($modifiedFiles | Select-Object -First 10 | ForEach-Object { "- $($_.FullName.Substring($cwd.Length+1)) ($($_.LastWriteTime.ToString('HH:mm')))" } | Out-String)
"@
    Set-Content -Path $reminderFile -Value $reminderContent -Encoding utf8
    "$timestamp [Stop] capitalization REMINDER written in last-stop-reminder.md" | Out-File -FilePath $logFile -Append -Encoding utf8
}

exit 0
