# resolve-modules.ps1 - resolves a module selection into the full vendored set:
# transitive closure of `requires` (BFS, cycle-safe), mandatory modules always included.
# Single source of truth: plugin/modules.json.
#
# Usage:
#   resolve-modules.ps1 -Modules "cadrage,contenu"   -> closure as JSON {modules, skills, agents, workers, paths}
#   resolve-modules.ps1 -Modules "all"               -> everything
#   resolve-modules.ps1 -Validate                    -> coverage check: every skill dir / agent file
#                                                       on disk is claimed by EXACTLY one module.
# Exit codes: 0 OK, 1 validation failure, 3 bad input.
[CmdletBinding()]
param(
    [string]$Modules = "all",
    [switch]$Validate,
    [string]$PluginRoot = ""
)
$ErrorActionPreference = "Stop"
if (-not $PluginRoot) { $PluginRoot = Split-Path $PSScriptRoot -Parent }
$registryPath = Join-Path $PluginRoot "modules.json"
if (-not (Test-Path $registryPath)) { Write-Error "modules.json not found: $registryPath"; exit 3 }
$registry = (Get-Content $registryPath -Raw -Encoding utf8 | ConvertFrom-Json).modules
$byId = @{}
foreach ($m in $registry) { $byId[$m.id] = $m }

# === Validate mode: full-coverage + single-ownership check ===
if ($Validate) {
    $errors = @()
    $skillOwners = @{}; $agentOwners = @{}; $workerOwners = @{}
    foreach ($m in $registry) {
        foreach ($s in @($m.skills))  { if ($skillOwners[$s])  { $errors += "skill '$s' claimed by both '$($skillOwners[$s])' and '$($m.id)'" }  else { $skillOwners[$s] = $m.id } }
        foreach ($a in @($m.agents))  { if ($agentOwners[$a])  { $errors += "agent '$a' claimed by both '$($agentOwners[$a])' and '$($m.id)'" }  else { $agentOwners[$a] = $m.id } }
        foreach ($w in @($m.workers)) { if ($workerOwners[$w]) { $errors += "worker '$w' claimed by both '$($workerOwners[$w])' and '$($m.id)'" } else { $workerOwners[$w] = $m.id } }
        foreach ($r in @($m.requires)) { if (-not $byId[$r]) { $errors += "module '$($m.id)' requires unknown module '$r'" } }
    }
    $EXCLUDED_SKILLS = @("new-lab")  # deprecated, never vendored (see new-lab-standalone.ps1)
    Get-ChildItem (Join-Path $PluginRoot "skills") -Directory | Where-Object { $EXCLUDED_SKILLS -notcontains $_.Name } | ForEach-Object {
        if (-not $skillOwners[$_.Name]) { $errors += "skill dir '$($_.Name)' on disk is claimed by NO module" }
    }
    Get-ChildItem (Join-Path $PluginRoot "agents") -Filter *.md -File | ForEach-Object {
        if (-not $agentOwners[$_.BaseName]) { $errors += "agent '$($_.BaseName)' on disk is claimed by NO module" }
    }
    Get-ChildItem (Join-Path $PluginRoot "agents\_workers") -Filter *.md -File -ErrorAction SilentlyContinue | Where-Object Name -ne "README.md" | ForEach-Object {
        if (-not $workerOwners[$_.BaseName]) { $errors += "worker '$($_.BaseName)' on disk is claimed by NO module" }
    }
    if ($errors.Count -gt 0) {
        $errors | ForEach-Object { Write-Output "COVERAGE-ERROR $_" }
        Write-Output "STATUS: INVALID ($($errors.Count) error(s))"
        exit 1
    }
    Write-Output "STATUS: VALID ($($registry.Count) modules, $($skillOwners.Count) skills, $($agentOwners.Count) agents, $($workerOwners.Count) workers - full coverage, single ownership)"
    exit 0
}

# === Resolution: selection + mandatory -> BFS closure over requires ===
$selected = New-Object System.Collections.Generic.HashSet[string]
if ($Modules.Trim().ToLower() -eq "all") {
    foreach ($m in $registry) { [void]$selected.Add($m.id) }
} else {
    foreach ($id in ($Modules -split ",")) {
        $id = $id.Trim()
        if (-not $id) { continue }
        if (-not $byId[$id]) {
            $known = ($registry | ForEach-Object { $_.id }) -join ', '
            Write-Error "Unknown module: '$id'. Known: $known"
            exit 3
        }
        [void]$selected.Add($id)
    }
    foreach ($m in $registry) { if ($m.mandatory) { [void]$selected.Add($m.id) } }
    # BFS transitive closure (visited set = cycle-safe)
    $queue = New-Object System.Collections.Queue
    $selected | ForEach-Object { $queue.Enqueue($_) }
    while ($queue.Count -gt 0) {
        $cur = $queue.Dequeue()
        foreach ($r in @($byId[$cur].requires)) {
            if (-not $selected.Contains($r)) { [void]$selected.Add($r); $queue.Enqueue($r) }
        }
    }
}

$ordered = @($registry | Where-Object { $selected.Contains($_.id) })   # registry order = stable
$result = [ordered]@{
    modules = @($ordered | ForEach-Object { [ordered]@{ id = $_.id; version = $_.version } })
    skills  = @($ordered | ForEach-Object { @($_.skills) }  | Where-Object { $_ })
    agents  = @($ordered | ForEach-Object { @($_.agents) }  | Where-Object { $_ })
    workers = @($ordered | ForEach-Object { @($_.workers) } | Where-Object { $_ })
    paths   = @($ordered | ForEach-Object { @($_.paths) }   | Where-Object { $_ })
}
Write-Output ($result | ConvertTo-Json -Depth 4)
exit 0
