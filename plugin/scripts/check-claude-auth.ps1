# Vibeforge - check expiration of the Claude Code OAuth token
#
# Detects tokens that are expired OR about to expire before the Anthropic
# Agent SDK returns a 401 on the next session.
#
# `claude auth status` reports `loggedIn: true` even when the token has been
# expired for days -- it only checks that the file exists without testing
# `expiresAt`. This script does the real check.
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File scripts/check-claude-auth.ps1
#   powershell.exe -ExecutionPolicy Bypass -File scripts/check-claude-auth.ps1 -Json -Quiet
#
# Exit codes:
#   0 - Token valid (>WarningThresholdMin minutes remaining)
#   1 - Token expiring soon (<WarningThresholdMin min) -- WARNING
#   2 - Token expired -- ERROR: re-login required (`claude logout` then `claude login`)
#   3 - .credentials.json missing or unreadable
#
# Optional session-start hook (in your local ~/.claude/settings.json):
#   "hooks": {
#     "SessionStart": [
#       { "command": "powershell.exe -ExecutionPolicy Bypass -File ${CLAUDE_PLUGIN_ROOT}/scripts/check-claude-auth.ps1" }
#     ]
#   }

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Quiet,
    [int]$WarningThresholdMin = 30
)

$credFile = Join-Path $env:USERPROFILE ".claude\.credentials.json"

# === Output helper ===
function Emit-Result {
    param($Status, $ExpStr, $RemainingMin, $Tier, $Email, $Message, $Color, $ExitCode)
    if (-not $Quiet) {
        Write-Host "[claude-auth] " -NoNewline
        Write-Host $Message -ForegroundColor $Color
    }
    if ($Json) {
        $obj = [PSCustomObject]@{
            status = $Status
            expiresAt = $ExpStr
            remainingMin = $RemainingMin
            tier = $Tier
            email = $Email
        }
        $obj | ConvertTo-Json -Compress
    }
    exit $ExitCode
}

# === File missing ===
if (-not (Test-Path -LiteralPath $credFile)) {
    Emit-Result "no-credentials" $null $null $null $null `
        "No .credentials.json on this machine. To use Claude Code: 'claude login'." `
        "Yellow" 3
}

# === Parse ===
$jsonObj = $null
try {
    $jsonObj = Get-Content -LiteralPath $credFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
} catch {
    Emit-Result "parse-error" $null $null $null $null `
        ("Failed to read/parse .credentials.json: " + $_.Exception.Message) `
        "Red" 3
}

$oauth = $jsonObj.claudeAiOauth
if ($null -eq $oauth) {
    Emit-Result "no-oauth" $null $null $null $null `
        "No claudeAiOauth section in the file -- are you using an API key instead?" `
        "Yellow" 3
}
if ($null -eq $oauth.expiresAt) {
    Emit-Result "no-expires-at" $null $null $null $null `
        "No claudeAiOauth.expiresAt -- file corrupted, run claude login again" `
        "Red" 3
}

# === Compute ===
$exp = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$oauth.expiresAt).LocalDateTime
$remaining = [int](($exp - (Get-Date)).TotalMinutes)
$tier = if ($oauth.subscriptionType) { [string]$oauth.subscriptionType } else { "unknown" }
$email = if ($oauth.email) { [string]$oauth.email } else { "unknown" }
$expStr = $exp.ToString("yyyy-MM-ddTHH:mm:sszzz")
$expShort = $exp.ToString("yyyy-MM-dd HH:mm")

# === Decision ===
if ($remaining -lt 0) {
    $expiredMin = -$remaining
    $msg = "TOKEN EXPIRED $expiredMin min ago (exp $expShort, tier $tier, $email). Fix: claude logout then claude login."
    Emit-Result "expired" $expStr $remaining $tier $email $msg "Red" 2
}

if ($remaining -lt $WarningThresholdMin) {
    $msg = "WARNING: token expires in $remaining min (exp $expShort, tier $tier). The SDK auto-refreshes, otherwise: claude logout && claude login."
    Emit-Result "expiring-soon" $expStr $remaining $tier $email $msg "Yellow" 1
}

$hours = [Math]::Round($remaining / 60.0, 1)
$msg = "OK: token valid for $hours h (exp $expShort, tier $tier, $email)."
Emit-Result "valid" $expStr $remaining $tier $email $msg "Green" 0
