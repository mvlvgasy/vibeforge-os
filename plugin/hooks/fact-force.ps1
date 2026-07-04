# PreToolUse hook -- Vibeforge fact-force / investigation-before-edit
#
# Blocks the FIRST Edit/Write per file in a session and demands a prior
# investigation (importers, data schemas, explicit user instruction).
# The idea: instead of asking "are you sure?" (which LLMs always answer "yes"),
# this hook demands concrete facts. The act of investigating creates an
# awareness that self-evaluation never does.
#
# === DISABLED BY DEFAULT (opt-in) ===
# This hook is INTRUSIVE (it blocks the 1st edit of EVERY file). It is therefore
# gated by an environment variable: it does NOTHING unless
# VIBEFORGE_FACT_FORCE == "1". To pilot it on a project: set
# $env:VIBEFORGE_FACT_FORCE = "1" in the session environment. In your harness,
# do NOT set the var => total no-op, zero risk.
#
# Note: internal comments/messages are ASCII (PowerShell Windows encoding).

$ErrorActionPreference = "SilentlyContinue"

# === Opt-in gate: no-op if not enabled ===
if ($env:VIBEFORGE_FACT_FORCE -ne "1") {
    exit 0
}

$rawInput = [Console]::In.ReadToEnd()
try {
    $payload = $rawInput | ConvertFrom-Json
} catch {
    exit 0  # fail-open
}

$toolName = $payload.tool_name
if ($toolName -ne "Edit" -and $toolName -ne "Write" -and $toolName -ne "MultiEdit") {
    exit 0
}

$filePath = $payload.tool_input.file_path
if ([string]::IsNullOrWhiteSpace($filePath)) {
    exit 0
}

$cwd = (Get-Location).Path
$logDir = Join-Path $cwd ".claude\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Per-session state file: list of files already "investigated" (= blocked once)
$sessId = $env:CLAUDE_CODE_SESSION_ID
if ([string]::IsNullOrWhiteSpace($sessId)) { $sessId = "nosession" }
$safeSess = ($sessId -replace "[^A-Za-z0-9_-]", "_")
$stateFile = Join-Path $logDir "fact-force-$safeSess.txt"

$investigated = @()
if (Test-Path $stateFile) {
    $investigated = @(Get-Content -Path $stateFile -ErrorAction SilentlyContinue)
}

# Already investigated (blocked once) => let the real modification through
if ($investigated -contains $filePath) {
    exit 0
}

# First time on this file: mark it + block to force the investigation
Add-Content -Path $stateFile -Value $filePath -Encoding utf8
$leaf = Split-Path $filePath -Leaf
$blockMsg = "[Vibeforge fact-force] BLOCKED (1st edit of '$leaf'). Before modifying, INVESTIGATE and state concrete facts: (1) who imports/depends on this file (Grep the importers)? (2) which data schemas / public contracts are affected? (3) which explicit user instruction justifies this edit? Once those facts are established, re-run the same Edit: it will pass (the hook only blocks once per file)."
[Console]::Error.WriteLine($blockMsg)
exit 2
