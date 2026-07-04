# PreToolUse hook -- Vibeforge config-protection
#
# Blocks MODIFICATION (Edit/Write) of an ALREADY EXISTING linter/formatter
# config file. Prevents the frequent agent behavior of, when facing an
# ESLint/Biome/Ruff error, loosening the config instead of fixing the code.
#
# Behavior:
# - Edit/Write on an EXISTING linter config file => exit 2 (block) + message.
# - Creation of a NEW config file => allowed (legitimate setup).
# - Any other file => allowed.
# - Fail-open: on doubt (unparsable JSON, error), we do NOT block.
#
# Harness-safe: the scope is limited to linter config files only. In a session
# on a client project, this hook PREVENTS the agent from weakening the client's
# linting (desired behavior) and touches nothing else. Escape hatch: rename or
# delete then recreate, or disable the hook.
#
# Note: internal comments/messages are ASCII (PowerShell Windows encoding).

$ErrorActionPreference = "SilentlyContinue"

$cwd = (Get-Location).Path
$logDir = Join-Path $cwd ".claude\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "config-protection-hook.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

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

# === Protected linter/formatter config files (by base name) ===
# Match on the filename, case-insensitive.
$leaf = Split-Path $filePath -Leaf
$protectedPatterns = @(
    "^\.eslintrc($|\..*)",      # .eslintrc, .eslintrc.json, .eslintrc.js, .eslintrc.cjs...
    "^eslint\.config\..*",       # eslint.config.js / .mjs / .ts
    "^\.prettierrc($|\..*)",     # .prettierrc, .prettierrc.json...
    "^prettier\.config\..*",
    "^biome\.jsonc?$",           # biome.json / biome.jsonc
    "^\.ruff\.toml$",
    "^ruff\.toml$",
    "^\.flake8$",
    "^\.stylelintrc($|\..*)",
    "^tslint\.json$"
)

$isProtected = $false
foreach ($pat in $protectedPatterns) {
    if ($leaf -imatch $pat) { $isProtected = $true; break }
}

if (-not $isProtected) {
    exit 0
}

# Protected config file targeted. We block ONLY if it already exists
# (modification). Creating a new config file = legitimate.
if (-not (Test-Path $filePath)) {
    "$timestamp [config-protection] creation allowed: $filePath" | Out-File -FilePath $logFile -Append -Encoding utf8
    exit 0
}

# === BLOCKED ===
"$timestamp [config-protection] BLOCKED $toolName on existing config: $filePath" | Out-File -FilePath $logFile -Append -Encoding utf8
try {
    $metricsDir = Join-Path $cwd ".claude\metrics"
    if (-not (Test-Path $metricsDir)) {
        New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
    }
    $event = @{
        ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        kind = "config_protection_blocked"
        file = $filePath
        tool = $toolName
        cwd = $cwd
    } | ConvertTo-Json -Compress
    Add-Content -Path (Join-Path $metricsDir "events.jsonl") -Value $event -Encoding utf8
} catch { }

$blockMsg = "[Vibeforge config-protection] BLOCKED: '$leaf' is an existing linter/formatter config. Do NOT modify the config to make a check pass. FIX the code that violates the rule. If the rule itself legitimately needs to change, that is an explicit human decision (ask the operator) - not a silent workaround mid-task."
[Console]::Error.WriteLine($blockMsg)
exit 2
