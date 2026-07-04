# PostToolUse hook -- Vibeforge
# Automatic error detection (non-zero exit codes) and append of a candidate
# blocker in <cwd>/.claude/pending-blockers.md (reviewed at session close).
#
# Note: all internal comments and messages are ASCII to avoid any PowerShell
# encoding issues on Windows. Content written into .md files may contain
# accented characters (UTF-8).

$ErrorActionPreference = "SilentlyContinue"

# === Logs setup ===
$cwd = (Get-Location).Path
$logDir = Join-Path $cwd ".claude\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "post-tool-use-hook.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# === Read stdin JSON (sent by Claude Code) ===
$rawInput = [Console]::In.ReadToEnd()

# Parse JSON. On failure, log and exit cleanly.
try {
    $payload = $rawInput | ConvertFrom-Json
} catch {
    "$timestamp [PostToolUse] No parsable JSON, skip" | Out-File -FilePath $logFile -Append -Encoding utf8
    exit 0
}

# Extract useful fields
$toolName = $payload.tool_name
$toolResponse = $payload.tool_response
$exitCode = $null
$stderr = ""

# Depending on the tool, the exit code is in different places
if ($toolName -eq "Bash" -or $toolName -eq "PowerShell") {
    $exitCode = $toolResponse.exit_code
    $stderr = $toolResponse.stderr
}

"$timestamp [PostToolUse] tool=$toolName exit=$exitCode" | Out-File -FilePath $logFile -Append -Encoding utf8

# === Metrics logging -- append-only, never break ===
try {
    $metricsDir = Join-Path $cwd ".claude\metrics"
    if (-not (Test-Path $metricsDir)) {
        New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
    }
    $kind = "tool"
    $extra = @{}
    if ($exitCode -ne $null -and $exitCode -ne 0) {
        $kind = "tool_error"
    } elseif ($toolName -eq "Task") {
        $kind = "agent_delegated"
        $extra["agent"] = $payload.tool_input.subagent_type
    } elseif ($toolName -eq "Skill") {
        $kind = "skill_invoked"
        $extra["skill"] = $payload.tool_input.skill
    }
    $event = [ordered]@{
        ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        kind = $kind
        tool = $toolName
        cwd = $cwd
        session = $env:CLAUDE_CODE_SESSION_ID
    }
    if ($exitCode -ne $null) { $event["exit_code"] = $exitCode }
    foreach ($k in $extra.Keys) { $event[$k] = $extra[$k] }
    $eventJson = ($event | ConvertTo-Json -Compress -Depth 4)
    Add-Content -Path (Join-Path $metricsDir "events.jsonl") -Value $eventJson -Encoding utf8
} catch {
    # Silent: metrics must never break the session
    "$timestamp [PostToolUse] metrics write failed: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append -Encoding utf8
}

# === R009 -- Memory update pending marker for long sub-agents ===
# If the Task tool dispatched a sub-agent that ran for a long time OR made many
# tool calls, write a .memory-update-pending marker in its agent-contexts dir to
# force it to update its MEMORY at the next bootstrap.
try {
    if ($toolName -eq "Task") {
        $subagentType = $payload.tool_input.subagent_type
        $duration = $toolResponse.duration_ms
        $toolUses = $toolResponse.tool_uses

        # Thresholds: 5 min OR 20 tool calls
        $longRun = ($duration -ne $null -and $duration -gt 300000) -or ($toolUses -ne $null -and $toolUses -gt 20)

        if ($longRun -and $subagentType) {
            # Strip prefix "vibeforge:" if present (e.g. vibeforge:lead -> lead)
            $agentName = $subagentType -replace "^vibeforge:", ""
            $vibeforgeRoot = $env:CLAUDE_PLUGIN_ROOT
            if ($vibeforgeRoot -and (Test-Path $vibeforgeRoot)) {
                $agentCtx = Join-Path $vibeforgeRoot "agent-contexts\$agentName"
                if (Test-Path $agentCtx) {
                    $markerFile = Join-Path $agentCtx ".memory-update-pending.md"
                    $markerContent = @(
                        "# Memory update pending - auto-detected by post-tool-use hook",
                        "",
                        "> Sub-agent $agentName ran for a long time or made many actions.",
                        "> At the next bootstrap, it MUST update its MEMORY.md before any other work.",
                        "",
                        "## Detection",
                        "- Detection date: $timestamp",
                        "- Sub-agent: $agentName",
                        "- Duration ms: $duration",
                        "- Tool uses: $toolUses",
                        "- Parent cwd: $cwd",
                        "- Session: $env:CLAUDE_CODE_SESSION_ID",
                        "",
                        "## Expected action at next bootstrap",
                        "1. Read the current MEMORY.md",
                        "2. Identify 1-3 insights from the session marked above",
                        "3. Decide the scope (universal/lab/project) per R009",
                        "4. Append the new entry to the MEMORY.md at the right level",
                        "5. Delete this marker file"
                    ) -join "`n"
                    Set-Content -Path $markerFile -Value $markerContent -Encoding utf8
                    "$timestamp [PostToolUse] R009 marker written for sub-agent $agentName (dur=$duration ms, uses=$toolUses)" | Out-File -FilePath $logFile -Append -Encoding utf8
                }
            }
        }
    }
} catch {
    "$timestamp [PostToolUse] R009 marker write failed: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append -Encoding utf8
}

# === Context-monitor -- WARN-ONLY ===
# Non-blocking detection of scope creep (> 20 files edited) and tool loops
# (>= 3 consecutive repetitions of the same tool). Writes warnings into a
# session-visible file. NEVER blocking (exit 0 guaranteed below). Context%/cost
# are not tracked here as they are not reliable from the PostToolUse payload.
try {
    $sessId = $env:CLAUDE_CODE_SESSION_ID
    if ([string]::IsNullOrWhiteSpace($sessId)) { $sessId = "nosession" }
    $safeSess = ($sessId -replace "[^A-Za-z0-9_-]", "_")
    $stateFile = Join-Path $logDir "context-monitor-$safeSess.json"

    $state = $null
    if (Test-Path $stateFile) {
        try { $state = Get-Content -Path $stateFile -Raw | ConvertFrom-Json } catch { $state = $null }
    }
    if ($null -eq $state) {
        $state = [ordered]@{ files = @(); lastTool = ""; repeatCount = 0; warnedScope = $false; warnedLoop = $false }
    }

    # Mutable list of edited files (scope creep)
    $files = @()
    if ($state.files) { $files = @($state.files) }
    if ($toolName -eq "Edit" -or $toolName -eq "Write" -or $toolName -eq "MultiEdit") {
        $fp = $payload.tool_input.file_path
        if (-not [string]::IsNullOrWhiteSpace($fp) -and ($files -notcontains $fp)) {
            $files += $fp
        }
    }

    # Consecutive repetition counter for the same tool (tool loop)
    $lastTool = [string]$state.lastTool
    $repeat = [int]$state.repeatCount
    if ($toolName -eq $lastTool) { $repeat++ } else { $repeat = 1 }

    $warnedScope = [bool]$state.warnedScope
    $warnedLoop = [bool]$state.warnedLoop
    $warnFile = Join-Path $cwd ".claude\pending-context-warnings.md"

    function Write-CtxWarn($msg) {
        if (-not (Test-Path $warnFile)) {
            Set-Content -Path $warnFile -Value "# Context monitor warnings (auto, non-blocking)`n" -Encoding utf8
        }
        Add-Content -Path $warnFile -Value "- $timestamp $msg" -Encoding utf8
    }

    $SCOPE_THRESHOLD = 20
    $LOOP_THRESHOLD = 3
    if ($files.Count -gt $SCOPE_THRESHOLD -and -not $warnedScope) {
        Write-CtxWarn "SCOPE CREEP: $($files.Count) files modified in the session (threshold $SCOPE_THRESHOLD). Check that you are not overflowing the scope."
        $warnedScope = $true
    }
    if ($repeat -ge $LOOP_THRESHOLD -and ($repeat % $LOOP_THRESHOLD) -eq 0) {
        Write-CtxWarn "TOOL LOOP: $toolName repeated $repeat times in a row. Possible unproductive loop - reconsider the approach."
    }

    $newState = [ordered]@{
        files = $files
        lastTool = $toolName
        repeatCount = $repeat
        warnedScope = $warnedScope
        warnedLoop = $warnedLoop
    }
    $newState | ConvertTo-Json -Compress -Depth 4 | Set-Content -Path $stateFile -Encoding utf8
} catch {
    "$timestamp [PostToolUse] context-monitor failed: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append -Encoding utf8
}

# === Error detection ===
if ($exitCode -ne $null -and $exitCode -ne 0) {
    # Categorize the error (regex on stderr)
    $category = "unknown"
    if ($stderr -match "ENOENT|No such file|cannot find") {
        $category = "missing-file"
    } elseif ($stderr -match "permission denied|access denied") {
        $category = "permission"
    } elseif ($stderr -match "syntax error|unexpected token") {
        $category = "syntax"
    } elseif ($stderr -match "ModuleNotFoundError|Cannot find module") {
        $category = "missing-dependency"
    } elseif ($stderr -match "TypeError|undefined is not") {
        $category = "type-error"
    } elseif ($stderr -match "network|ENETUNREACH|connection refused") {
        $category = "network"
    } elseif ($stderr -match "timeout|ETIMEDOUT") {
        $category = "timeout"
    }

    # Append to pending-blockers.md
    $pendingFile = Join-Path $cwd ".claude\pending-blockers.md"

    if (-not (Test-Path $pendingFile)) {
        $headerLines = @(
            "# Pending Blockers (auto-detected by hook)",
            "",
            "> Errors detected automatically during the session.",
            "> To review at session close, then:",
            "> - Either promote to B<NN> in registers/blockers.md (real blockers)",
            "> - Or ignore (transient error / false alarm)",
            "> - Or merge with an existing blocker",
            "> The hook does NOT create a direct entry in registers/blockers.md.",
            ""
        )
        Set-Content -Path $pendingFile -Value ($headerLines -join "`n") -Encoding utf8
    }

    # Truncate stderr if too long
    $stderrSnippet = if ($stderr.Length -gt 500) { $stderr.Substring(0, 500) + "...[truncated]" } else { $stderr }

    # Indent stderr by 4 spaces (markdown code block equivalent without backticks)
    $indentedStderr = ($stderrSnippet -split "`r?`n" | ForEach-Object { "    $_" }) -join "`n"

    # Build the entry without backtick here-string (to avoid parse errors)
    $entryLines = @(
        "",
        "## $timestamp -- $category",
        "- Tool: $toolName",
        "- Exit code: $exitCode",
        "- Category: $category",
        "- Stderr (snippet):",
        "",
        $indentedStderr,
        "",
        ""
    )
    Add-Content -Path $pendingFile -Value ($entryLines -join "`n") -Encoding utf8

    "$timestamp [PostToolUse] BLOCKER candidate recorded (category=$category)" | Out-File -FilePath $logFile -Append -Encoding utf8
}

# === Hallucination pattern detection ===
# If tool=Read and the file does not exist, that is often a sign of a Claude hallucination
if ($toolName -eq "Read" -and $toolResponse.error -match "does not exist|not found") {
    $evalPendingFile = Join-Path $cwd ".claude\pending-eval.md"
    if (-not (Test-Path $evalPendingFile)) {
        $evalHeader = @(
            "# Pending Eval (auto-detected)",
            "",
            "> Potential hallucination patterns.",
            ""
        ) -join "`n"
        Set-Content -Path $evalPendingFile -Value $evalHeader -Encoding utf8
    }
    $invented = $payload.tool_input.file_path
    $evalEntry = @(
        "",
        "## $timestamp -- invented file",
        "- Path: $invented",
        ""
    ) -join "`n"
    Add-Content -Path $evalPendingFile -Value $evalEntry -Encoding utf8
    "$timestamp [PostToolUse] EVAL pattern (invented file): $invented" | Out-File -FilePath $logFile -Append -Encoding utf8
}

# Always exit 0 (non-blocking)
exit 0
