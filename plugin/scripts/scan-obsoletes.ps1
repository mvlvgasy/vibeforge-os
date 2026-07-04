# scan-obsoletes.ps1
# Support script for the /scan-obsoletes skill.
# Detects obsolete entries in the Vibeforge registers (Frame 3 step 4 - Consolidation).
#
# For each register entry (status: active):
#   - computes age via last_updated YAML > **Date**: YYYY-MM-DD > git log -L > mtime
#   - if age > threshold (default 180 days) -> ARCHIVE candidate
#   - cross-checks metrics/events.jsonl: no citation of the ID in the last 30 days
#   - cross-checks git grep: no reference in the repo's active files
#   - recommendation: ARCHIVE / REVIEW / KEEP
#
# Output: <BaseDir>/vibeforge/audits/scan-obsoletes-<YYYY-MM-DD-HHmm>.md
#
# Paths point at the USER workspace, not the plugin. By default the scan runs
# from the current directory; override with -BaseDir to point at your stack root
# (the folder that contains your method repo and your lab-* folders).
#
# Modes:
#   - default: detection only (phase 1)
#   - -Apply: marks status: archived in the frontmatter of ARCHIVE entries
#   - -ThresholdDays N: custom threshold (default 180)
#
# Guard rails:
#   - NEVER deletes (status: archived only)
#   - Idempotent (already-archived entries are skipped)
#   - No blocking failure if events.jsonl is absent
#   - No external API dependency

param(
    [int]$ThresholdDays = 180,
    [int]$RecentCitationDays = 30,
    [switch]$Apply,
    # Root of your workspace: the folder containing the method repo and lab-* dirs.
    # Defaults to the current working directory.
    [string]$BaseDir = (Get-Location).Path
)

$ErrorActionPreference = "Continue"

$now = Get-Date
$reportDate = $now.ToString("yyyy-MM-dd HH:mm")
$reportSlug = $now.ToString("yyyy-MM-dd-HHmm")
$vibeforgeRoot = Join-Path $BaseDir "vibeforge"

Write-Host "Vibeforge - Scan obsoletes" -ForegroundColor Cyan
Write-Host ("  Threshold       : " + $ThresholdDays + " days") -ForegroundColor Gray
Write-Host ("  Citation window : " + $RecentCitationDays + " days") -ForegroundColor Gray
Write-Host ("  Mode            : " + $(if ($Apply) { "APPLY (marks status: archived)" } else { "DETECTION (read-only)" })) -ForegroundColor Gray
Write-Host ""

# ===========================================
# Step 1 - Inventory of registers to scan
# ===========================================

$registerFiles = @()

# Global Vibeforge registers
$globalRegistersDir = Join-Path $vibeforgeRoot "registres"
foreach ($name in @("rules", "learnings", "bdr", "eval")) {
    $path = Join-Path $globalRegistersDir ($name + ".md")
    if (Test-Path $path) {
        $registerFiles += [PSCustomObject]@{
            Path = $path
            Scope = "global"
            Name = $name
            Lab = $null
        }
    }
}

# Local lab-* registers
Get-ChildItem -Path $BaseDir -Filter "lab-*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $labName = $_.Name
    $labRegistersDir = Join-Path $_.FullName "registres"
    if (Test-Path $labRegistersDir) {
        foreach ($name in @("learnings", "rules", "bdr", "eval")) {
            $path = Join-Path $labRegistersDir ($name + ".md")
            if (Test-Path $path) {
                $registerFiles += [PSCustomObject]@{
                    Path = $path
                    Scope = "lab"
                    Name = $name
                    Lab = $labName
                }
            }
        }
    }
}

Write-Host ("Registers scanned : " + $registerFiles.Count) -ForegroundColor Green

# ===========================================
# Step 2 - Parse the entries of each register
# ===========================================

function Parse-RegisterEntries {
    param(
        [string]$Path
    )

    $content = Get-Content -Path $Path -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    if (-not $content) { return @() }

    # Split on entry sections: `## <ID>` or `## <ID> ...`
    # ID format: Lxx, L-xxx-yy, Rxx, BDRxx, Exx, etc.
    # Important: exclude template headers "## BDR<NN>", "## L<NN>" by requiring a real digit.
    $entries = @()

    # Strict regex: ID must be digits OR L-word-word (lab-prefixed)
    # NB: L<NN> (template) does not match because <NN> is not a digit
    # Tolerates uppercase (L-orus-META) and digits (L-arch-003)
    $regex = '(?ms)^##\s+(?<id>(?:BDR|L|R|E)\d+|L-[A-Za-z][A-Za-z0-9-]*)\b[^\r\n]*\r?\n(?<body>.*?)(?=^##\s+|\z)'

    $matches = [regex]::Matches($content, $regex)
    foreach ($m in $matches) {
        $id = $m.Groups['id'].Value
        $body = $m.Groups['body'].Value
        $headerLine = ($content.Substring($m.Index)).Split("`n")[0].TrimEnd("`r")

        # Skip header section that just contains "Index"
        if ($id -ieq "Index") { continue }

        # Skip template / placeholder headers: "## BDR<NN>", "## L<NN>", "## E<NN>", "## R<NN>"
        # (the ID regex captures just the letters, but the full header still contains <NN>)
        if ($headerLine -match '<\s*N+\s*>' -or $headerLine -match '<[A-Z]+>' -or $headerLine -match '\b<titre\b') { continue }

        # Skip "## To add ..." / "## Format ..." / "## Archives" / "## Promotions ..." headers
        # that appear in some registers as documentation templates
        $titlePart = $headerLine -replace '^##\s+', ''
        if ($titlePart -match '^(Pour ajouter|To add|Format|Archives|Promotions candidates|Pre-amorces|Synth)' ) { continue }
        # Note: we keep it if the ID strictly matches Lxx/Rxx/BDRxx/Exx/L-xxx-yy with trailing digits
        if ($id -notmatch '^(L|R|E|BDR)\d+$' -and $id -notmatch '^L-[a-z0-9-]+$') {
            # Non-standard ID, accepted but logged silently
            # (e.g. future schemas)
        }

        # Extract YAML frontmatter inside the body
        # Pattern 1: block ```yaml + --- + content + --- + ```
        # Pattern 2: block ```yaml + key:value direct + ```
        $yamlBlock = $null
        $yamlMatch = [regex]::Match($body, '(?ms)```\s*yaml\s*\r?\n(.*?)\r?\n\s*```')
        if ($yamlMatch.Success) {
            $yamlBlock = $yamlMatch.Groups[1].Value
            # Strip optional --- delimiters
            $yamlBlock = $yamlBlock -replace '(?m)^---\s*$', ''
        }

        $entryStatus = $null
        $entryLastUpdated = $null
        $entryCreated = $null

        if ($yamlBlock) {
            $statusMatch = [regex]::Match($yamlBlock, '(?m)^\s*status:\s*(\S+)')
            if ($statusMatch.Success) { $entryStatus = $statusMatch.Groups[1].Value.Trim() }

            $luMatch = [regex]::Match($yamlBlock, '(?m)^\s*last_updated:\s*(\S+)')
            if ($luMatch.Success) {
                try { $entryLastUpdated = Get-Date $luMatch.Groups[1].Value.Trim() -ErrorAction Stop } catch {}
            }

            $crMatch = [regex]::Match($yamlBlock, '(?m)^\s*created:\s*(\S+)')
            if ($crMatch.Success) {
                try { $entryCreated = Get-Date $crMatch.Groups[1].Value.Trim() -ErrorAction Stop } catch {}
            }
        }

        # Fallback: look for "**Date**: YYYY-MM-DD" in the body (legacy register format)
        if (-not $entryLastUpdated -and -not $entryCreated) {
            $dateMatch = [regex]::Match($body, '(?m)^\*\*Date\*\*\s*:\s*(\d{4}-\d{2}-\d{2})')
            if ($dateMatch.Success) {
                try { $entryCreated = Get-Date $dateMatch.Groups[1].Value -ErrorAction Stop } catch {}
            }
        }

        # Default status = active if undeclared but the entry has YAML => probably active
        # If there is no YAML at all, keep null (treated as legacy)
        if (-not $entryStatus -and $yamlBlock) { $entryStatus = "active" }

        $entries += [PSCustomObject]@{
            Id = $id
            HeaderLine = $headerLine
            HasYaml = ($yamlBlock -ne $null)
            Status = $entryStatus
            LastUpdated = $entryLastUpdated
            Created = $entryCreated
            BodyExcerpt = ($body.Substring(0, [Math]::Min(200, $body.Length))).Trim()
            CharOffset = $m.Index
            CharLength = $m.Length
        }
    }

    return $entries
}

$allEntries = @()
foreach ($reg in $registerFiles) {
    Write-Host ("  parsing : " + $reg.Path) -ForegroundColor DarkGray
    $entries = Parse-RegisterEntries -Path $reg.Path
    foreach ($e in $entries) {
        $e | Add-Member -NotePropertyName "RegistrePath" -NotePropertyValue $reg.Path
        $e | Add-Member -NotePropertyName "RegistreScope" -NotePropertyValue $reg.Scope
        $e | Add-Member -NotePropertyName "RegistreName" -NotePropertyValue $reg.Name
        $e | Add-Member -NotePropertyName "RegistreLab" -NotePropertyValue $reg.Lab
        $allEntries += $e
    }
}

Write-Host ("Entries parsed    : " + $allEntries.Count) -ForegroundColor Green

# ===========================================
# Step 3 - Date fallback via git log -L
# ===========================================

function Get-GitDateForEntry {
    param(
        [string]$RegistrePath,
        [string]$EntryId
    )

    $prevPref = $global:LASTEXITCODE
    try {
        # Repo root containing the file
        $dir = Split-Path -Parent $RegistrePath
        $repoRoot = & git -C $dir rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
            $global:LASTEXITCODE = 0
            return $null
        }

        $relPath = $RegistrePath.Substring($repoRoot.Length).TrimStart('\', '/').Replace('\', '/')

        # Find the line number where "## $EntryId" appears
        $matched = & git -C $repoRoot grep -n "^## $EntryId" -- $relPath 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $matched) {
            $global:LASTEXITCODE = 0
            return $null
        }

        $lineNum = [int](($matched -split ':')[1])

        # git log -L for that single line, last commit date
        $logOut = & git -C $repoRoot log -L "$lineNum,${lineNum}:$relPath" --format="%aI" --no-patch -1 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $logOut) {
            $global:LASTEXITCODE = 0
            return $null
        }

        # Parse first ISO date from output
        $dateMatch = [regex]::Match($logOut, '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}')
        if ($dateMatch.Success) {
            return Get-Date $dateMatch.Value -ErrorAction SilentlyContinue
        }
    } catch {
        # silent fallback
    } finally {
        # Reset exit code because the silent git calls may pollute it
        $global:LASTEXITCODE = 0
    }
    return $null
}

# For active entries with no known date, try the git fallback
$gitFallbackCount = 0
foreach ($e in $allEntries) {
    $effectiveDate = $null
    if ($e.LastUpdated) { $effectiveDate = $e.LastUpdated }
    elseif ($e.Created) { $effectiveDate = $e.Created }

    if (-not $effectiveDate) {
        $gd = Get-GitDateForEntry -RegistrePath $e.RegistrePath -EntryId $e.Id
        if ($gd) {
            $effectiveDate = $gd
            $gitFallbackCount++
        }
    }

    # Final fallback: file mtime (unreliable but defensive)
    if (-not $effectiveDate) {
        try {
            $effectiveDate = (Get-Item $e.RegistrePath).LastWriteTime
        } catch {}
    }

    $e | Add-Member -NotePropertyName "EffectiveDate" -NotePropertyValue $effectiveDate -Force
    if ($effectiveDate) {
        $daysSince = [int]($now - $effectiveDate).TotalDays
    } else {
        $daysSince = -1
    }
    $e | Add-Member -NotePropertyName "DaysSince" -NotePropertyValue $daysSince -Force
}

if ($gitFallbackCount -gt 0) {
    Write-Host ("Git log fallback  : " + $gitFallbackCount + " entries dated via history") -ForegroundColor DarkGray
}

# ===========================================
# Step 4 - Cross-check metrics events.jsonl
# ===========================================

$metricsFile = Join-Path $vibeforgeRoot "metrics\events.jsonl"
$citationsByEntry = @{}

if (Test-Path $metricsFile) {
    $cutoff = $now.AddDays(-$RecentCitationDays)
    try {
        $rawContent = Get-Content $metricsFile -Raw -Encoding utf8 -ErrorAction SilentlyContinue
        if ($rawContent) {
            # Look for entry IDs in the raw jsonl text (citations in files,
            # promotions_to, related, etc. tracked in events).
            foreach ($e in $allEntries) {
                # Pattern: ID bounded by non-alphanum (or start/end)
                $pattern = "\b" + [regex]::Escape($e.Id) + "\b"
                $matches = [regex]::Matches($rawContent, $pattern)
                # To honor the 30d window, filter per line by timestamp
                if ($matches.Count -gt 0) {
                    $recentCount = 0
                    Get-Content $metricsFile -ErrorAction SilentlyContinue | ForEach-Object {
                        $line = $_
                        if ($line -match $pattern) {
                            try {
                                $evt = $line | ConvertFrom-Json -ErrorAction Stop
                                if ($evt.ts) {
                                    $ts = Get-Date $evt.ts -ErrorAction Stop
                                    if ($ts -gt $cutoff) { $recentCount++ }
                                }
                            } catch {}
                        }
                    }
                    if ($recentCount -gt 0) {
                        $citationsByEntry[$e.Id] = $recentCount
                    }
                }
            }
        }
    } catch {
        Write-Host "  events.jsonl not parsable, graceful fallback (0 citation)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  events.jsonl absent, skip metrics cross-check" -ForegroundColor Yellow
}

# ===========================================
# Step 5 - Cross-check git grep in active repo
# ===========================================

function Test-EntryGitRefs {
    param(
        [string]$VibeforgeRoot,
        [string]$EntryId
    )

    $refCount = 0
    try {
        # git grep in the method repo - excluded paths are filtered post-hoc
        # (pathspec :! exclusion only works if the path exists; varies by repo)
        $grepOut = & git -C $VibeforgeRoot grep -l -- $EntryId 2>$null
        if ($grepOut) {
            # Count distinct paths that contain the ID, excluding:
            #   - the source register (registres/)
            #   - archives, backlog, audits (i.e. previous scan reports)
            $files = ($grepOut -split "`n") | Where-Object {
                $_ -and
                $_ -notmatch '^registres/' -and
                $_ -notmatch '^_archived/' -and
                $_ -notmatch '^backlog/' -and
                $_ -notmatch '^audits/'
            }
            $refCount = $files.Count
        }
    } catch {} finally {
        $global:LASTEXITCODE = 0
    }
    return $refCount
}

Write-Host "Cross-check git grep in active repo..." -ForegroundColor DarkGray
foreach ($e in $allEntries) {
    if (-not $e.Status -or $e.Status -eq "active") {
        $grepRefs = Test-EntryGitRefs -VibeforgeRoot $vibeforgeRoot -EntryId $e.Id
    } else {
        $grepRefs = -1  # not relevant for archived/deprecated
    }
    $e | Add-Member -NotePropertyName "GitRefs" -NotePropertyValue $grepRefs -Force

    $citations = if ($citationsByEntry.ContainsKey($e.Id)) { $citationsByEntry[$e.Id] } else { 0 }
    $e | Add-Member -NotePropertyName "RecentCitations" -NotePropertyValue $citations -Force
}

# ===========================================
# Step 6 - Compute recommendations
# ===========================================

function Get-Recommendation {
    param([PSCustomObject]$Entry)

    if ($Entry.Status -and $Entry.Status -ne "active") {
        return @{ Rec = "SKIP"; Reason = "already $($Entry.Status)" }
    }

    if ($Entry.DaysSince -lt 0) {
        return @{ Rec = "REVIEW"; Reason = "unknown date" }
    }

    if ($Entry.DaysSince -le $ThresholdDays) {
        return @{ Rec = "KEEP"; Reason = "recent ($($Entry.DaysSince)d)" }
    }

    # Beyond the threshold
    $reasons = @()
    $reasons += "age $($Entry.DaysSince)d > ${ThresholdDays}d"

    $citations = $Entry.RecentCitations
    $gitRefs = $Entry.GitRefs

    if ($citations -eq 0 -and $gitRefs -le 0) {
        $reasons += "0 citation in $($RecentCitationDays)d"
        $reasons += "0 ref in active repo"
        return @{ Rec = "ARCHIVE"; Reason = ($reasons -join ", ") }
    } elseif ($citations -eq 0 -and $gitRefs -gt 0) {
        $reasons += "0 citation, $gitRefs active ref(s)"
        return @{ Rec = "REVIEW"; Reason = ($reasons -join ", ") }
    } else {
        $reasons += "$citations recent citations"
        return @{ Rec = "REVIEW"; Reason = ($reasons -join ", ") }
    }
}

foreach ($e in $allEntries) {
    $r = Get-Recommendation -Entry $e
    $e | Add-Member -NotePropertyName "Recommendation" -NotePropertyValue $r.Rec -Force
    $e | Add-Member -NotePropertyName "Reason" -NotePropertyValue $r.Reason -Force
}

$archiveCandidates = @($allEntries | Where-Object { $_.Recommendation -eq "ARCHIVE" })
$reviewCandidates = @($allEntries | Where-Object { $_.Recommendation -eq "REVIEW" })
$keepEntries = @($allEntries | Where-Object { $_.Recommendation -eq "KEEP" })
$skipEntries = @($allEntries | Where-Object { $_.Recommendation -eq "SKIP" })

Write-Host ""
Write-Host ("ARCHIVE : " + $archiveCandidates.Count) -ForegroundColor Red
Write-Host ("REVIEW  : " + $reviewCandidates.Count) -ForegroundColor Yellow
Write-Host ("KEEP    : " + $keepEntries.Count) -ForegroundColor Green
Write-Host ("SKIP    : " + $skipEntries.Count) -ForegroundColor DarkGray

# ===========================================
# Step 7 - Apply mode (marks status: archived)
# ===========================================

$appliedIds = @()
if ($Apply -and $archiveCandidates.Count -gt 0) {
    Write-Host ""
    Write-Host "APPLY mode: marking status: archived..." -ForegroundColor Yellow
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    # Group by file (avoid multiple overwrites)
    $byFile = $archiveCandidates | Group-Object -Property RegistrePath
    foreach ($grp in $byFile) {
        $filePath = $grp.Name
        $content = Get-Content -Path $filePath -Raw -Encoding utf8

        foreach ($e in $grp.Group) {
            if (-not $e.HasYaml) {
                Write-Host ("  skip $($e.Id): no YAML frontmatter (legacy)") -ForegroundColor DarkGray
                continue
            }
            # Replace `status: active` -> `status: archived` in this entry's YAML block
            # Target the specific block: first find the "## $id" section
            $sectionStart = $content.IndexOf("## $($e.Id)")
            if ($sectionStart -lt 0) { continue }

            # Find end of section: next "## " or end of file
            $nextSection = $content.IndexOf("`n## ", $sectionStart + 3)
            if ($nextSection -lt 0) { $nextSection = $content.Length }

            $section = $content.Substring($sectionStart, $nextSection - $sectionStart)
            $newSection = $section -replace '(?m)^(\s*)status:\s*active\s*$', '${1}status: archived'

            # Add archived_at timestamp
            if ($newSection -match '(?m)^(\s*)status:\s*archived\s*$' -and $newSection -notmatch 'archived_at:') {
                $newSection = $newSection -replace '(?m)^(\s*)status:\s*archived\s*$', "`${1}status: archived`n`${1}archived_at: $($now.ToString('yyyy-MM-dd'))"
            }

            if ($newSection -ne $section) {
                $content = $content.Substring(0, $sectionStart) + $newSection + $content.Substring($nextSection)
                $appliedIds += $e.Id
                Write-Host ("  applied : " + $e.Id) -ForegroundColor Green
            }
        }

        # Write the file as UTF-8 without BOM
        [System.IO.File]::WriteAllText($filePath, $content, $utf8NoBom)
    }
}

# ===========================================
# Step 8 - Build markdown report
# ===========================================

$lines = @(
    "# scan-obsoletes report -- $reportDate",
    "",
    "**Threshold**: $ThresholdDays days (last_updated > threshold = archive candidate)",
    "**Citation window**: $RecentCitationDays days (events.jsonl)",
    "**Mode**: $(if ($Apply) { 'APPLY (status: archived marked on ' + $appliedIds.Count + ' entries)' } else { 'DETECTION only' })",
    "",
    "## Summary",
    "",
    "| Category | Count |",
    "|----------|-------|",
    "| ARCHIVE (180d+ and 0 citation) | $($archiveCandidates.Count) |",
    "| REVIEW (180d+ with residual activity) | $($reviewCandidates.Count) |",
    "| KEEP (recent) | $($keepEntries.Count) |",
    "| SKIP (already archived/deprecated) | $($skipEntries.Count) |",
    "| **Total entries scanned** | **$($allEntries.Count)** |",
    "",
    "Registers scanned: $($registerFiles.Count) (global + lab-*)",
    ""
)

if ($Apply -and $appliedIds.Count -gt 0) {
    $lines += @(
        "## Entries archived this run",
        ""
    )
    foreach ($id in $appliedIds) { $lines += "- $id" }
    $lines += ""
}

# Section per register
$registerGroups = $allEntries | Group-Object -Property RegistrePath | Sort-Object Name
foreach ($grp in $registerGroups) {
    $sample = $grp.Group[0]
    $title = if ($sample.RegistreLab) { "$($sample.RegistreLab) / $($sample.RegistreName).md" } else { "global / $($sample.RegistreName).md" }
    $lines += "## $title"
    $lines += ""
    $lines += ("Path : ``" + $sample.RegistrePath + "``")
    $lines += ""
    $lines += "| ID | last_updated | days_since | citations 30d | git_refs | recommendation | reason |"
    $lines += "|----|--------------|------------|---------------|----------|----------------|--------|"

    foreach ($e in ($grp.Group | Sort-Object @{Expression = {
        switch ($_.Recommendation) {
            "ARCHIVE" { 0 }
            "REVIEW" { 1 }
            "KEEP" { 2 }
            "SKIP" { 3 }
            default { 4 }
        }
    }}, @{Expression = "DaysSince"; Descending = $true})) {
        $luStr = if ($e.EffectiveDate) { $e.EffectiveDate.ToString("yyyy-MM-dd") } else { "?" }
        $citStr = if ($e.RecentCitations -gt 0) { $e.RecentCitations.ToString() } else { "0" }
        $grefStr = if ($e.GitRefs -ge 0) { $e.GitRefs.ToString() } else { "-" }
        $daysStr = if ($e.DaysSince -ge 0) { $e.DaysSince.ToString() } else { "?" }
        $recBadge = switch ($e.Recommendation) {
            "ARCHIVE" { "**ARCHIVE**" }
            "REVIEW"  { "REVIEW" }
            "KEEP"    { "KEEP" }
            "SKIP"    { "_skip_" }
            default   { $e.Recommendation }
        }
        $lines += "| $($e.Id) | $luStr | $daysStr | $citStr | $grefStr | $recBadge | $($e.Reason) |"
    }
    $lines += ""
}

# Actionable recommendations section
$lines += "## Actionable recommendations"
$lines += ""

if ($archiveCandidates.Count -eq 0 -and $reviewCandidates.Count -eq 0) {
    $lines += "No candidate detected. All registers are up to date."
    $lines += ""
} else {
    if ($archiveCandidates.Count -gt 0) {
        $lines += "### To archive ($($archiveCandidates.Count) entries)"
        $lines += ""
        $lines += "These entries are > $ThresholdDays days old with no recent citation nor reference in the repo."
        $lines += "Action: `pwsh scripts/scan-obsoletes.ps1 -Apply` or skill `/scan-obsoletes --apply`."
        $lines += ""
        foreach ($e in ($archiveCandidates | Select-Object -First 20)) {
            $title = $e.HeaderLine -replace '^##\s+', ''
            $lines += "- **$($e.Id)** ($($e.DaysSince)d): $title"
        }
        if ($archiveCandidates.Count -gt 20) {
            $lines += "- ... ($($archiveCandidates.Count - 20) more)"
        }
        $lines += ""
    }

    if ($reviewCandidates.Count -gt 0) {
        $lines += "### To review ($($reviewCandidates.Count) entries)"
        $lines += ""
        $lines += "These entries are > $ThresholdDays days old BUT still cited/referenced. Manual review required (rephrase, promote or archive)."
        $lines += ""
        foreach ($e in ($reviewCandidates | Select-Object -First 10)) {
            $title = $e.HeaderLine -replace '^##\s+', ''
            $lines += "- **$($e.Id)** ($($e.DaysSince)d, $($e.RecentCitations) citations, $($e.GitRefs) refs): $title"
        }
        if ($reviewCandidates.Count -gt 10) {
            $lines += "- ... ($($reviewCandidates.Count - 10) more)"
        }
        $lines += ""
    }
}

$lines += @(
    "---",
    "",
    "*Report generated by scripts/scan-obsoletes.ps1 (skill /scan-obsoletes).*",
    "*Frame 3 doctrine - Consolidation step 4 (Archiving).*"
)

# ===========================================
# Step 9 - Write report
# ===========================================

$reportDir = Join-Path $vibeforgeRoot "audits"
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$reportPath = Join-Path $reportDir "scan-obsoletes-$reportSlug.md"

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($reportPath, ($lines -join "`n"), $utf8NoBom)

Write-Host ""
Write-Host ("Report written : " + $reportPath) -ForegroundColor Green
Write-Host ("  $($allEntries.Count) entries scanned") -ForegroundColor Gray
Write-Host ("  $($archiveCandidates.Count) ARCHIVE / $($reviewCandidates.Count) REVIEW / $($keepEntries.Count) KEEP / $($skipEntries.Count) SKIP") -ForegroundColor Gray
if ($Apply) {
    Write-Host ("  $($appliedIds.Count) entries marked status: archived") -ForegroundColor Yellow
}

# Output structure for skill consumption
$result = [PSCustomObject]@{
    ReportPath = $reportPath
    TotalScanned = $allEntries.Count
    ArchiveCount = $archiveCandidates.Count
    ReviewCount = $reviewCandidates.Count
    KeepCount = $keepEntries.Count
    SkipCount = $skipEntries.Count
    AppliedCount = $appliedIds.Count
    AppliedIds = $appliedIds
}

$result
exit 0
