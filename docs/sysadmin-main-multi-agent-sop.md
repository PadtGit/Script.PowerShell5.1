# sysadmin-main Workflow Roles SOP

## Purpose

- This doc describes how to split discovery, implementation, validation, review, and doc-sync work in the current checkout.
- Treat the role names below as responsibilities, not as config-backed files or required external automation.
- Keep this SOP, `AGENTS.md`, `PLANS.md`, `SKILL.md`, `README.md`, and relevant `docs/*` content aligned whenever durable workflow guidance changes.

## Repo Ground Rules

- Canonical runtime scripts live under `PowerShell Script/`.
- `AGENTS.md` owns the canonical workflow commands and safety rules.
- `PLANS.md` owns ExecPlan requirements and the default `plan.md` location.
- Runtime scripts under `PowerShell Script/` should stay copyable as single files for PC-side use; when an original script still has fixed launch-time defaults, keep a sibling `.Standalone.ps1` copy beside it.
- `Invoke-WhatIfValidation.ps1` is the branch-level validator entrypoint.
- Generated validation output belongs under `artifacts/validation/` in the local checkout.
- This branch supports Windows PowerShell 5.1 only.
- Preserve `Set-StrictMode -Version 3.0`, `$ErrorActionPreference = 'Stop'`, and `SupportsShouldProcess`.
- Prefer truthful `-WhatIf` preview behavior wherever a script can support it safely.
- Historical notes may describe fuller upstream layouts; confirm the current checkout before following copied commands verbatim.

## Responsibility Matrix

| Role | Write Scope | Primary Responsibility |
| --- | --- | --- |
| `Explorer` | None by default | Repo mapping, workflow-surface discovery, and evidence gathering |
| `Implementer` | Target script, tool, test, or doc surface only | Smallest defensible patch |
| `Security reviewer` | Target security-sensitive slice only | Publisher, signature, path-trust, ACL, output-root, and reparse-point hardening review |
| `Behavioral tester` | `tests/*` only | Behavior-focused Pester coverage and `-WhatIf` safety tests |
| `Validator` | `artifacts/validation/*` in the local checkout during validation | Local analyzer, Pester, smoke checks, host-side artifact review, and disposable Sandbox validation |
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
   - Run the canonical commands from `AGENTS.md`, use Windows Sandbox only for disposable manual validation of risky scripts, and keep persistent artifact review in the local checkout.
6. Review results
   - Inspect `artifacts/validation/` outputs, confirm analyzer failures or clean runs were recorded correctly, and capture any Sandbox-only observations in docs or notes instead of expecting them to persist through the read-only repo mapping.
7. Playbook sync
   - Update `AGENTS.md`, `PLANS.md`, `SKILL.md`, `README.md`, and `docs/*` when durable repo knowledge or commands drift.
8. Change analysis
   - Use Git metadata for recency windows rather than file timestamps.

## Validation Surface

- Use the canonical command blocks from `AGENTS.md` rather than maintaining duplicate command text here.
- Keep analyzer validation anchored on `tools\Invoke-PSScriptAnalyzer.ps1` with `tools\PSScriptAnalyzerSettings.psd1`, `-EnableExit`, and `-ExitCodeMode AllDiagnostics`.
- Keep the focused analyzer-helper regression suite at `tests/tools/Invoke-PSScriptAnalyzer.Tests.ps1` in the validation loop when changing analyzer output or failure-handling behavior.
- Keep smoke checks focused on the trusted `-WhatIf` commands documented in `AGENTS.md`.
- Use `sandbox/sysadmin-main-validation.wsb` as the disposable validation shell for risky scripts. The profile maps `C:\Users\Bob\Documents\Script.PowerShell5.1` read-only into `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`, so do not expect persistent `artifacts/validation/` writes to flow back through the Sandbox mount.
- Use `sandbox/Start-SysadminMainSandboxShell.ps1` to land in `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main` consistently.
