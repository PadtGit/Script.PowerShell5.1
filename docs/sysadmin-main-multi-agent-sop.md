# sysadmin-main Multi-Agent SOP

## Why This Shape

- Use a manager-pattern workflow even in this trimmed checkout: one controller should keep the task narrative coherent while discovery, implementation, validation, review, and doc-sync responsibilities stay explicit.
- This checkout does not currently ship repo-local `.codex/agents/*.toml`, `.agents/*`, or `.github/workflows/*` surfaces. Treat the role names below as workflow responsibilities, not as config-backed files that must exist.
- Keep this SOP, `AGENTS.md`, `PLANS.md`, `SKILL.md`, `README.md`, and the local validation commands aligned whenever the workflow changes.

## Repo Ground Rules

- Canonical scripts live under `PowerShell Script/`.
- `PLANS.md` is the repo-specific guide for writing and maintaining ExecPlans, and active task plans should point back to it.
- Runtime scripts under `PowerShell Script/` should stay copyable as single files for PC-side use; when an original script still has fixed launch-time defaults, keep a sibling `.Standalone.ps1` copy beside it.
- `Invoke-WhatIfValidation.ps1` is the branch-level validator entrypoint.
- Generated validation output belongs under `artifacts/validation/`.
- This branch supports Windows PowerShell 5.1 only.
- Preserve `Set-StrictMode -Version 3.0`, `$ErrorActionPreference = 'Stop'`, and `SupportsShouldProcess`.
- Prefer safe `-WhatIf` preview behavior over hard admin-only preview blocks where the script can truthfully support preview without elevation.
- Keep result objects compact and structured. Avoid noisy transcript-style output by default.
- Historical notes may mention absent upstream workflow paths; confirm the current checkout before following copied commands verbatim.

## Responsibility Matrix

| Role | Write Scope | Primary Responsibility |
| --- | --- | --- |
| `Explorer` | None by default | Repo mapping, workflow-surface discovery, and evidence gathering |
| `Implementer` | Target script, tool, test, or doc surface only | Smallest defensible patch |
| `Security reviewer` | Target security-sensitive slice only | Publisher, signature, path-trust, ACL, output-root, and reparse-point hardening review |
| `Behavioral tester` | `tests/*` only | Behavior-focused Pester coverage and `-WhatIf` safety tests |
| `Validator` | `artifacts/validation/*` only during validation | Local analyzer, Pester, smoke checks, artifact review, and Sandbox validation |
| `Reviewer` | None | Final correctness, regression, safety, and workflow-drift review |
| `Playbook librarian` | `AGENTS.md`, `PLANS.md`, `SKILL.md`, `README.md`, and `docs/*` | Workflow-doc synchronization and durable repo guidance upkeep |

## Current High-Risk Areas

- Service-control scripts that stop and restart `Spooler` or `wuauserv`
- Network reset and reboot scripts
- Broad Windows cleanup scripts
- Installer orphan move scripts
- Analyzer-helper output handling that automation may consume from TXT, JSON, or SARIF artifacts

## Round Order

1. Explore
   - Map the exact file, validation, and docs surface before editing.
2. Implement
   - Make the smallest patch while keeping current-state docs aligned.
3. Optional security review
   - Use a security-focused pass when the task touches publisher checks, signatures, output roots, ACLs, canonical path enforcement, or reparse-point handling.
4. Optional behavioral Pester coverage
   - Add or update Pester coverage when tests, `-WhatIf` behavior, result contracts, or validation artifacts change.
5. Validate locally
   - Run the analyzer command from `AGENTS.md`, the appropriate Pester scope, trusted local smoke checks, and a Sandbox validation pass for risky scripts.
6. Review artifacts
   - Inspect `artifacts/validation/` outputs and confirm analyzer failures or clean runs were recorded correctly.
7. Playbook sync
   - Update `AGENTS.md`, `PLANS.md`, `SKILL.md`, `README.md`, and `docs/*` when durable repo knowledge or commands drift.
8. Change analysis
   - Use Git metadata for recency windows rather than file timestamps.

## Validation Surface

- Use the repo-wide recursive analyzer command with `tools\Invoke-PSScriptAnalyzer.ps1`, `tools\PSScriptAnalyzerSettings.psd1`, `-EnableExit`, and `-ExitCodeMode AllDiagnostics`.
- Remember that the analyzer helper now writes TXT, JSON, and SARIF outputs to `artifacts/validation/` by default.
- Use the CI-style Pester configuration that writes results to `artifacts/validation/pester-results.xml`.
- Keep the focused analyzer-helper regression suite at `tests/tools/Invoke-PSScriptAnalyzer.Tests.ps1` in the validation loop when changing analyzer output or failure-handling behavior.
- Keep smoke checks focused on the trusted `-WhatIf` commands documented in `AGENTS.md`.
- Use `sandbox/sysadmin-main-validation.wsb` as the disposable validation shell for risky scripts. The profile maps `C:\Users\Bob\Documents\Script.PowerShell5.1` read-only into `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`, disables networking and vGPU, and starts PowerShell through `sandbox/Start-SysadminMainSandboxShell.ps1`, which resolves the repo root from the helper location so the working directory lands there consistently.
- This checkout does not currently include a GitHub workflow file, so local validation commands are the authoritative workflow surface here.
