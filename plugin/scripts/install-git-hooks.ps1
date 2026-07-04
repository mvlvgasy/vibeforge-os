# Vibeforge - install the repo git hooks
#
# Activates scripts/git-hooks/ as the hooks directory for this repo via
# `git config --local core.hooksPath`. This wires up the repo's post-commit
# hook (e.g. to run consistency checks after each impacting commit).
#
# Usage: pwsh scripts/install-git-hooks.ps1
# Run once after cloning the repo.

$ErrorActionPreference = "Stop"

$repoRoot = git rev-parse --show-toplevel
if (-not $repoRoot) {
    Write-Host "ERROR: not inside a git repo." -ForegroundColor Red
    exit 1
}

$hooksPath = "scripts/git-hooks"
$fullHooksPath = Join-Path $repoRoot $hooksPath

if (-not (Test-Path $fullHooksPath)) {
    Write-Host "ERROR: $fullHooksPath not found." -ForegroundColor Red
    exit 1
}

git -C $repoRoot config --local core.hooksPath $hooksPath
Write-Host "Git hooks installed (core.hooksPath = $hooksPath)." -ForegroundColor Green
Write-Host "  - post-commit: runs after impacting changes" -ForegroundColor DarkGray
