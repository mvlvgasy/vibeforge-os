# migrations/ — method evolutions for generated standalone labs

DB-migration style: **idempotent, ordered, journaled**. One migration = one dated folder:

```
migrations/
  2026-08-01-example-slug/
    migration.json        # required
    apply.ps1             # optional post-file-ops script (receives -LabPath)
```

`migration.json`:

```json
{
  "id": "2026-08-01-example-slug",
  "from_version": "0.3.0",
  "to_version": "0.3.1",
  "description": "One line: what this brings to existing labs.",
  "add":     [ { "source": "plugin/skills/new-skill/SKILL.md", "target": ".claude/skills/new-skill/SKILL.md" } ],
  "replace": [ { "source": "plugin/agents/lead.md",            "target": ".claude/agents/lead.md" } ],
  "remove":  [ ".claude/skills/deprecated-skill/SKILL.md" ],
  "script":  "apply.ps1"
}
```

- `source` paths are relative to this repo; `target` paths are relative to the lab root.
- Folders sort lexicographically = chronologically (date prefix mandatory).
- Applied by `plugin/scripts/upgrade-lab.ps1 -LabPath <lab>`; each lab records what it
  received in `_method/migration-journal.json`.

## Guarantees (enforced by upgrade-lab.ps1, tested in plugin/scripts/tests/)

1. **Customizations are sacred**: a target whose sha256 differs from the lab's
   `_method/manifest.json` (client customization) is reported as CONFLICT and left
   untouched. Human arbitration, never a silent overwrite.
2. **Full backup first**: `_method/` + every touched file → `<lab>/.upgrade-backups/<ts>/`,
   with an `upgrade-report.md`. Rollback: `upgrade-lab.ps1 -LabPath <lab> -Rollback`.
3. **Idempotent**: already-journaled migrations are skipped; re-running is a no-op.

## Labs generated before v0.3 (no manifest)

Run once, then upgrades work normally:

```powershell
powershell -ExecutionPolicy Bypass -File plugin\scripts\build-manifest.ps1 -LabPath <lab> -Baseline
```

⚠️ `-Baseline` records the CURRENT state as pristine: customizations made before the
baseline become invisible to drift detection (they will look like socle files).

## Out of scope (v0.4 candidates, noted in README)

No marketplace, no inter-module dependency resolution — the socle stays monolithic.
