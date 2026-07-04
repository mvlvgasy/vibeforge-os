# PreToolUse hook -- Vibeforge (anti full-read registers)
#
# Implements forced indexation: large TOC-indexed registers should be read via
# their table of contents + targeted Grep/Read, not full-read.
#
# Detects Read calls on the large registers (rules.md, learnings.md, etc.) made
# WITHOUT offset/limit.
#
# Expected gain: ~40-70% savings on bootstrap tokens for registers > 500 lines.
#
# Behavior: INTELLIGENT BLOCKING.
# - Full-read (no offset/limit) on a watched register > 500 lines => exit 2
#   (block) + procedure message (read TOC, Grep, targeted Read).
# - Escape hatch: if the WHOLE file is genuinely needed (audit, refactor),
#   re-run Read with explicit offset/limit (e.g. offset=0 limit=N+1) => not blocked.
# - Small files (<= 500 lines): full-read allowed (no gain in blocking).
#
# Note: all internal comments/messages are ASCII to avoid PowerShell encoding
# issues on Windows.

$ErrorActionPreference = "SilentlyContinue"

# === Logs setup ===
$cwd = (Get-Location).Path
$logDir = Join-Path $cwd ".claude\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "pre-tool-use-hook.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# === Read stdin JSON (sent by Claude Code) ===
$rawInput = [Console]::In.ReadToEnd()

try {
    $payload = $rawInput | ConvertFrom-Json
} catch {
    "$timestamp [PreToolUse] No parsable JSON, skip" | Out-File -FilePath $logFile -Append -Encoding utf8
    exit 0
}

$toolName = $payload.tool_name
$toolInput = $payload.tool_input

# Quick filter: we only care about the Read tool
if ($toolName -ne "Read") {
    exit 0
}

$filePath = $toolInput.file_path
$offset = $toolInput.offset
$limit = $toolInput.limit

# === List of watched registers (large TOC-indexed files) ===
# Criterion: files > 500 lines that have a TOC at the top (to read first).
# Match both the French ("registres") and English ("registers") folder names.
$watchedFiles = @(
    "registres\rules.md",
    "registres\learnings.md",
    "registres\bdr.md",
    "registres\traffic-journal.md",
    "registers\rules.md",
    "registers\learnings.md",
    "registers\bdr.md",
    "registers\traffic-journal.md",
    "MEMORY-cadrage.md"
)

# Check if the file_path matches a watched file
$isWatched = $false
foreach ($wf in $watchedFiles) {
    if ($filePath -match [regex]::Escape($wf)) {
        $isWatched = $true
        break
    }
}

if (-not $isWatched) {
    exit 0
}

# === Full-read detection (no offset, no limit) ===
# These files have a TOC at the top. Reading the whole file without offset is a
# signal of token waste.
$isFullRead = ($null -eq $offset) -and ($null -eq $limit)

if ($isFullRead) {
    # === INTELLIGENT BLOCKING by line-count threshold ===
    # Count the lines of the watched file. Threshold 500: beyond it, a full-read
    # is waste (the TOC + targeted Read are enough). Below it, we let it pass.
    $lineCount = 0
    try {
        if (Test-Path $filePath) {
            $lineCount = (Get-Content -Path $filePath -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
        }
    } catch {
        # If we cannot count, we do not block (fail-open, cautious)
        $lineCount = 0
    }

    $BLOCK_THRESHOLD = 500

    if ($lineCount -gt $BLOCK_THRESHOLD) {
        # --- BLOCKED: large register read in full ---
        "$timestamp [PreToolUse] BLOCKED full-read $filePath ($lineCount lines > $BLOCK_THRESHOLD)" | Out-File -FilePath $logFile -Append -Encoding utf8
        try {
            $metricsDir = Join-Path $cwd ".claude\metrics"
            if (-not (Test-Path $metricsDir)) {
                New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
            }
            $eventsFile = Join-Path $metricsDir "events.jsonl"
            $event = @{
                ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                kind = "full_read_blocked"
                file = $filePath
                lines = $lineCount
                tool = "Read"
                cwd = $cwd
                phase = "block"
            } | ConvertTo-Json -Compress
            Add-Content -Path $eventsFile -Value $event -Encoding utf8
        } catch { }

        # Message on stderr (exit 2 => stderr returned to Claude, which re-decides)
        $allowLimit = $lineCount + 1
        $blockMsg = "[Vibeforge anti-full-read] BLOCKED: '$filePath' is $lineCount lines. Do NOT read it all (~70% token waste). PROCEDURE: (1) read the TOC at the top (the '## Index' section), (2) Grep by 'domain:' or by ID to find the right section, (3) Read with targeted offset/limit. If you GENUINELY need the WHOLE file (audit/refactor): re-run Read with offset=0 and limit=$allowLimit (explicit intent, not blocked)."
        [Console]::Error.WriteLine($blockMsg)
        exit 2
    } else {
        # --- Small file (<= threshold): full-read OK, soft log only ---
        "$timestamp [PreToolUse] full-read $filePath ($lineCount lines <= $BLOCK_THRESHOLD, allowed)" | Out-File -FilePath $logFile -Append -Encoding utf8
        exit 0
    }
}

# Read with offset/limit OK -- no action (escape hatch or targeted read)
exit 0
