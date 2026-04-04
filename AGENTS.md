# sysadmin-main Playbook

## Project Snapshot

- This branch contains Windows sysadmin PowerShell scripts for Windows PowerShell 5.1 only.
- Treat `PowerShell Script/*` as the canonical working tree.
- Keep runtime scripts under `PowerShell Script/*` copyable as single files for PC-side use. When an original script still has baked-in launch-time defaults, add a sibling `.Standalone.ps1` copy rather than changing that original contract.
- This checkout currently contains local script, test, tool, docs, sandbox, and validation-artifact surfaces only.
- Historical notes in `CHANGELOG.md` may describe fuller upstream layouts; verify paths against this checkout before reusing copied workflow notes or commands.
- `AGENTS.md` is the canonical playbook for workflow commands and safety guidance. Keep `PLANS.md`, `SKILL.md`, `README.md`, and `docs/*` aligned with it when durable workflow guidance changes.
- Generated validation output belongs under `artifacts/validation/`, not tracked root-level result files.
- Prefer small, reversible changes over bulk rewrites.

## ExecPlans

When writing complex features or significant refactors, use an ExecPlan from design to implementation.

In this checkout, follow `PLANS.md` from the repository root for ExecPlan structure, maintenance rules, validation expectations, and the default `plan.md` task-plan location.

## Canonical Layout

- `PowerShell Script/*`: runtime-specific script tree for this branch.
- `PowerShell Script/*/*.Standalone.ps1`: repo-free launch copies for runtime scripts that otherwise carry baked-in launch-time defaults.
- `Invoke-WhatIfValidation.ps1`: fixed-list `-WhatIf` validator for the current branch.
- `PLANS.md`: repo-specific rules for writing and maintaining ExecPlans.
- `SKILL.md`: repo-root entrypoint for the current local workflow surfaces.
- `README.md`: short repo overview that points readers to the local playbook and docs.
- `CHANGELOG.md`: landed-history reference for durable repo changes.
- `tests/*`: Pester suites for scripts and tooling.
- `tests/TestHelpers.ps1`: shared helpers for object-based `-WhatIf` and module-import testing.
- `tests/tools/Invoke-PSScriptAnalyzer.Tests.ps1`: regression coverage for analyzer crash-handling and stale-artifact reset behavior.
- `tools/Invoke-PSScriptAnalyzer.ps1`: analyzer runner that emits TXT, JSON, and SARIF artifacts.
- `tools/PSScriptAnalyzerSettings.psd1`: canonical analyzer settings for repo-wide validation.
- `artifacts/validation/*`: generated analyzer, Pester, and `-WhatIf` validation artifacts.
- `sandbox/sysadmin-main-validation.wsb`: disposable Windows Sandbox profile that maps `C:\Users\Bob\Documents\Script.PowerShell5.1` read-only into `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`, disables networking and vGPU, and opens PowerShell at that path.
- `sandbox/Start-SysadminMainSandboxShell.ps1`: Sandbox startup helper that resolves the repo root from its own location and sets that as the working directory. In Sandbox this resolves to `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`.
- `docs/windows-sandbox-validation.md`: manual validation flow for risky scripts in Windows Sandbox.
- `docs/sysadmin-main-multi-agent-sop.md`: longer workflow notes and role/responsibility guidance for this checkout.

## Safety Invariants

- Preserve truthful `#Requires -Version ...` declarations.
- Preserve `[CmdletBinding(SupportsShouldProcess = $true)]` on scripts that change system state.
- Preserve `Set-StrictMode -Version 3.0` and `$ErrorActionPreference = 'Stop'` unless the task explicitly changes them.
- Keep admin-only work gated so `-WhatIf` remains usable wherever the script already supports safe preview without elevation.
- Keep exit-code behavior and structured result objects stable unless the task explicitly changes contract.
- Prefer summary-style output and optional logging over noisy item-by-item transcript behavior by default.

## Validation Commands

These command blocks are the canonical workflow copy for this checkout. Shorter entrypoint docs should point back here instead of restating them unless a task needs a tighter, task-specific excerpt.

- Targeted `-WhatIf` validation:

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File 'PowerShell Script\<category>\<script>.ps1' -WhatIf
```

- Canonical validator:

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File 'Invoke-WhatIfValidation.ps1'
```

- Analyzer helper:

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PWD 'tools\Invoke-PSScriptAnalyzer.ps1') `
  -Path . `
  -Recurse `
  -SettingsPath (Join-Path $PWD 'tools\PSScriptAnalyzerSettings.psd1') `
  -EnableExit `
  -ExitCodeMode AllDiagnostics
```

- Analyzer helper with explicit artifact outputs for a focused target:

```powershell
$artifactRoot = Join-Path $PWD 'artifacts\validation'
New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PWD 'tools\Invoke-PSScriptAnalyzer.ps1') `
  -Path '.\PowerShell Script\Printer\Restart.Spool.DeletePrinterQSimple.ps1' `
  -SettingsPath (Join-Path $PWD 'tools\PSScriptAnalyzerSettings.psd1') `
  -OutTxtPath (Join-Path $artifactRoot 'psscriptanalyzer.txt') `
  -OutJsonPath (Join-Path $artifactRoot 'psscriptanalyzer.json') `
  -OutSarifPath (Join-Path $artifactRoot 'psscriptanalyzer.sarif') `
  -EnableExit `
  -ExitCodeMode AllDiagnostics
```

- Basic Pester helper:

```powershell
Invoke-Pester -Path .\tests
```

- CI-style Pester with NUnit XML output:

```powershell
$resultPath = Join-Path $PWD 'artifacts\validation\pester-results.xml'
New-Item -ItemType Directory -Force -Path (Split-Path -Path $resultPath -Parent) | Out-Null
$config = New-PesterConfiguration
$config.Run.Path = '.\tests'
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $true
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = $resultPath
$config.TestResult.OutputFormat = 'NUnitXml'
Invoke-Pester -Configuration $config
```

- Focused analyzer-helper regression tests:

```powershell
Invoke-Pester -Path '.\tests\tools\Invoke-PSScriptAnalyzer.Tests.ps1'
```

- Trusted local smoke checks:

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\PowerShell Script\Printer\Restart.Spool.DeletePrinterQSimple.ps1' -WhatIf
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\PowerShell Script\windows-maintenance\Nettoyage.Avance.Windows.Sauf.logserreur.ps1' -WhatIf
```

- Validation artifact review:

```powershell
Get-Content '.\artifacts\validation\psscriptanalyzer.txt'
Get-Content '.\artifacts\validation\whatif-validation.txt'
Get-Content '.\artifacts\validation\psscriptanalyzer.json' -Raw | ConvertFrom-Json
```

- Windows Sandbox launch:

```powershell
Start-Process '.\sandbox\sysadmin-main-validation.wsb'
```

The Sandbox profile maps the repo read-only. Use it for disposable preview and manual validation, and review persistent `artifacts/validation/` outputs from the host checkout unless you intentionally capture them to a disposable in-Sandbox path.

## Workflow Rounds

1. Explore
   - Read this playbook first.
   - Map the exact script, test, tool, doc, or sandbox surface before editing.
   - Confirm referenced paths exist in this checkout before copying older commands or workflow notes.
2. Implement
   - Make the smallest defensible patch.
   - Keep `AGENTS.md`, `PLANS.md`, `SKILL.md`, `README.md`, and `docs/*` aligned in the same change set when workflow wording changes.
3. Optional security review
   - Use a security-focused pass when work touches trust boundaries, path trust, reparse-point handling, publisher checks, output roots, or ACLs.
4. Optional behavioral Pester coverage
   - Add or update Pester coverage when behavior, result objects, `-WhatIf` safety, or tool artifacts change.
   - Prefer behavioral and object-based assertions over brittle transcript or string-output checks.
5. Validate locally
   - Run the standard analyzer command, appropriate Pester scope, trusted smoke checks, and Windows Sandbox validation for risky scripts.
6. Review generated artifacts
   - Inspect `artifacts/validation/` outputs after analyzer, Pester, or `-WhatIf` runs.
   - Treat Windows Sandbox as disposable preview/manual validation only; review persistent artifacts from the host checkout because the repo mapping is read-only.
   - Clean analyzer reruns should reset JSON findings to `[]`, and analyzer invocation failures should appear as structured diagnostics instead of disappearing silently.
7. Playbook sync
   - Sync `AGENTS.md`, `PLANS.md`, `SKILL.md`, `README.md`, and `docs/*` whenever durable repo knowledge or validation commands change.
8. Change analysis
   - Use Git metadata for recent-commit or last-N-days analysis.
   - Do not substitute file timestamps for commit windows.

## Working Roles

- These are responsibilities, not repo-local config-backed agent files in this checkout.
- `Explorer`: maps the exact file, validation, and documentation surface before editing.
- `Implementer`: makes the smallest defensible script, tool, test, or documentation patch.
- `Security reviewer`: checks publisher, signature, path-trust, ACL, output-root, and reparse-point boundaries when relevant.
- `Behavioral tester`: owns behavior-focused Pester coverage and `-WhatIf` safety assertions.
- `Validator`: runs analyzer, Pester, smoke checks, artifact review, and Sandbox validation without editing tracked files unless the task is explicitly documentation upkeep.
- `Reviewer`: checks correctness, safety, regressions, validation gaps, and workflow drift before finalizing.
- `Playbook librarian`: keeps `AGENTS.md`, `PLANS.md`, `SKILL.md`, `README.md`, and `docs/*` aligned with the current checkout.

## Known Pitfalls and Discoveries

- This repo is PowerShell-only; keep unrelated automation trees out of this checkout.
- Historical docs or notes may describe fuller upstream layouts; verify the current checkout before relying on copied paths or workflow snippets.
- Imported files may carry `Zone.Identifier`; validation commands should keep `-ExecutionPolicy Bypass` even after local MOTW cleanup.
- Runtime scripts under `PowerShell Script/*` are the copy-to-PC surfaces. Repo-root validators, `tools/*`, `tests/*`, and `sandbox/*` still assume the local checkout layout.
- In service-control scripts, restart should depend on whether this invocation actually stopped the service, not only on the initial service state.
- Generated validation logs belong in `artifacts/validation/`; do not reintroduce tracked root-level result files.
- The standard analyzer baseline is the repo-wide recursive command using `tools\Invoke-PSScriptAnalyzer.ps1` with `tools\PSScriptAnalyzerSettings.psd1`, `-EnableExit`, and `-ExitCodeMode AllDiagnostics`.
- Pin PSScriptAnalyzer to version `1.25.0`; use `-AutoInstallModule` only when intentionally bootstrapping a local validation environment.
- `tools\Invoke-PSScriptAnalyzer.ps1` writes `artifacts/validation/psscriptanalyzer.txt`, `artifacts/validation/psscriptanalyzer.json`, and `artifacts/validation/psscriptanalyzer.sarif` by default.
- Clean analyzer runs must overwrite stale JSON findings with `[]`.
- Analyzer invocation failures should surface as `PSScriptAnalyzerInvocationFailure` diagnostics instead of being silently dropped.
- `tests\tools\Invoke-PSScriptAnalyzer.Tests.ps1` locks in analyzer crash-handling and stale-artifact reset behavior.
- CI-style Pester exports results to `artifacts/validation/pester-results.xml`.
- Pester 5 does not support combining `-CI` with `-Configuration`; use `New-PesterConfiguration` for CI-style NUnit XML output.
- `sandbox\sysadmin-main-validation.wsb` maps `C:\Users\Bob\Documents\Script.PowerShell5.1` into `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main` as read-only with networking and vGPU disabled.
- `sandbox\Start-SysadminMainSandboxShell.ps1` is the canonical way the Sandbox profile sets the in-Sandbox working directory, resolving the repo root from the helper location instead of depending on a brittle hard-coded path.
- Keep the in-Sandbox working folder at `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main` so documented validation commands stay stable.
- Because the Sandbox repo mapping is read-only, persistent `artifacts/validation/` review belongs to the host checkout unless output is explicitly redirected to a disposable in-Sandbox path.
- The preferred validation finish in this checkout is local analyzer, Pester, smoke checks, host-side artifact review, and optional Sandbox checks for risky scripts.

## Improvement Notes

- 2026-03-20: Consolidated the repo around the `PowerShell Script/` tree and redirected generated validation output into `artifacts/validation/`.
- 2026-03-22: Added local validation docs and Windows Sandbox guidance for risky script validation.
- 2026-03-23: Standardized analyzer validation on the repo-wide recursive command, pinned PSScriptAnalyzer to `1.25.0`, and aligned output handling around TXT, JSON, and SARIF artifacts.
- 2026-03-25: Added focused analyzer-helper regression coverage and documented invocation-failure diagnostics plus stale-JSON reset behavior.
- 2026-03-26: Flattened the runtime-specific work for Windows PowerShell 5.1 and preserved the stable in-Sandbox working folder at `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`.
- 2026-03-28: Switched the Windows Sandbox profile to a helper script startup path so PowerShell opens consistently in `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`.
- 2026-04-02: Added `PLANS.md` as the repo-specific ExecPlan guide and aligned the workflow entrypoints to reference it.
- Keep this section focused on durable repo guidance, not task-by-task narrative.
