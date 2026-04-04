# sysadmin-main Skill Entry

Use the canonical script tree under `PowerShell Script/`.

## Core Rules

- This branch supports Windows PowerShell 5.1 only.
- `PowerShell Script/*` is the primary implementation surface.
- Runtime scripts under `PowerShell Script/*` should stay single-file portable for PC-side use; when a script needs a repo-free launch path, add a sibling `.Standalone.ps1` copy instead of changing the original script contract.
- Preserve `Set-StrictMode -Version 3.0`, `$ErrorActionPreference = 'Stop'`, and `SupportsShouldProcess` behavior unless the task explicitly changes them.
- Preserve usable `-WhatIf` behavior wherever the script already supports safe preview without elevation.
- Write generated validation output to `artifacts/validation/`, not to tracked repo files.
- Treat copied workflow notes as suspect until they match the current checkout layout.

## Canonical References

- `AGENTS.md`: canonical workflow playbook, safety guidance, and validation commands.
- `PLANS.md`: ExecPlan structure and maintenance rules for `plan.md`.
- `docs/sysadmin-main-multi-agent-sop.md`: workflow responsibilities and validation ownership.
- `docs/windows-sandbox-validation.md`: Windows Sandbox usage and read-only mapping caveats.
- `CHANGELOG.md`: landed history and historical context, not current operating instructions.
