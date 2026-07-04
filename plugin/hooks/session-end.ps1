# SessionEnd hook -- Vibeforge
# Fires at the end of each Claude Code session.
# Logs a session_end metric and, if the session was not closed via
# /cloture-session, drops a pending-capitalization.md so the next session
# can catch up. Non-blocking: failures never break SessionEnd.
# ASCII-safe code for PowerShell 5.1 on Windows.

$ErrorActionPreference = "SilentlyContinue"

$cwd = (Get-Location).Path
$logDir = Join-Path $cwd ".claude\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "session-end-hook.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

"$timestamp [SessionEnd] end of session in $cwd" | Out-File -FilePath $logFile -Append -Encoding utf8

# === Metrics logging (append-only, never break) ===
try {
    $metricsDir = Join-Path $cwd ".claude\metrics"
    if (-not (Test-Path $metricsDir)) {
        New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
    }
    $event = [ordered]@{
        ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        kind = "session_end"
        cwd = "$cwd"
        session = $env:CLAUDE_CODE_SESSION_ID
        had_handover = (Test-Path (Join-Path $cwd "HANDOVER.md"))
    }
    $eventJson = ($event | ConvertTo-Json -Compress -Depth 4)
    Add-Content -Path (Join-Path $metricsDir "events.jsonl") -Value $eventJson -Encoding utf8
} catch {
    "$timestamp [SessionEnd] metrics write failed: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append -Encoding utf8
}

# Was the session closed via /cloture-session?
# Heuristic: was HANDOVER.md modified in the last hour?
$handoverPath = Join-Path $cwd "HANDOVER.md"
$clotureDone = $false
if (Test-Path $handoverPath) {
    $handoverLastMod = (Get-Item $handoverPath).LastWriteTime
    if ($handoverLastMod -gt (Get-Date).AddHours(-1)) {
        $clotureDone = $true
        "$timestamp [SessionEnd] recent HANDOVER detected, close probably done" | Out-File -FilePath $logFile -Append -Encoding utf8
    }
}

# If the close was not done, drop a pending-capitalization.md
if (-not $clotureDone) {
    $pendingFile = Join-Path $cwd "pending-capitalization.md"
    $pendingContent = @"
# Pending capitalization

The session of $timestamp ended without ``/cloture-session``.

At the start of the next session, the lead should:
1. Read this file
2. Reconstruct the previous session's context from:
   - The lead's journal (``agent-contexts/lead/journal.md``)
   - Recent git changes (``git log --since="1 day ago"``)
   - Any errors in the logs
3. Propose running ``/cloture-session full`` to catch up
4. Once caught up, delete this file

## Missed session details
- CWD: $cwd
- End timestamp: $timestamp
- HANDOVER present: $(Test-Path $handoverPath)
"@
    $pendingContent | Out-File -FilePath $pendingFile -Encoding utf8
    "$timestamp [SessionEnd] pending-capitalization.md created" | Out-File -FilePath $logFile -Append -Encoding utf8
}

exit 0
