---
name: upgrade-socle
description: Upgrades the METHOD layer of an existing standalone lab (_method/ socle, method agents/skills, hooks, CATALOG) WITHOUT touching its custom layer (domain agents/skills, register content). Via scripts/upgrade-socle.ps1.
when_to_use: |
  When the method (vibeforge-os) has evolved and an existing standalone lab should benefit
  (new doctrine frame, new governance skills, agent fixes). Detection: compare the lab's
  `_method/VERSION` with the current vibeforge-os commit.
  Examples: /upgrade-socle lab=<path-to-lab>,
            /upgrade-socle lab=<path> --dry-run
allowed-tools: Bash Read
argument-hint: "lab=<lab-path> [socle=<vibeforge-os-path>] [--dry-run]"
---

## Purpose

Refresh the **method layer** of a standalone lab (frame 16) from a newer socle, while fully
preserving its **custom layer**. This is the "maintained labs" counterpart of
`/new-lab-standalone`: generated labs are upgradeable, not throwaway.

## Separation rule (NON-NEGOTIABLE)

- **Refreshed**: `_method/` (whole), agents/skills present in the socle inventory, hooks
  in `.claude/hooks/`, `tools/rebuild-catalog.ps1`, `_method/VERSION`, regenerated CATALOG.
- **NEVER touched**: agents/skills **absent from the socle inventory** (= custom, detected
  dynamically), all `registres/` content (local rules.md/eval.md additions), existing
  `agent-contexts/` (living MEMORY), SOUL/CLAUDE/contexte-domaine, projects.
- `settings.json`: created only if missing (never overwritten).

## Methodology

1. **Check eligibility**: the lab must be standalone (`method.txt` = `standalone`) — the
   script refuses otherwise. Read the lab's `_method/VERSION` for the current version.
2. **DryRun first**:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/upgrade-socle.ps1" -LabPath "<lab>" -DryRun
   ```
   → shows the detected custom layer (verify with the operator: the list must match the
   expected domain agents/skills).
3. **Real run** (without -DryRun). The script verifies on exit: zero external refs + custom intact.
4. **Restart Claude Code sessions** in the lab (no hot-reload of agents/skills).
5. If the lab is shared: commit + push the lab, notify the collaborator.

## Anti-patterns

- ❌ Upgrading without a DryRun inventory check first.
- ❌ Hand-editing `_method/` instead of upgrading.
- ❌ Upgrading without a prior commit of the lab (no rollback point).
- ❌ Overwriting the lab's local `registres/rules.md`/`eval.md` — the script never does; neither should you.

## Verification

- Script output: "zero external reference" + "custom layer intact (N agents, M skills)".
- `_method/VERSION` = new socle commit.
- Lab git diff: no custom file modified (besides idempotent ref rewrites).

---

**Created**: 2026-07-04 ("standalone labs" project, maintenance brick)
**Version**: 1.0
