# sysadmin-main Skill Entry

Use the canonical script tree under `PowerShell Script/`.

## Core Rules

- This branch supports Windows PowerShell 5.1 only.
- `PowerShell Script/*` is the primary implementation surface.
- Keep `Set-StrictMode -Version 3.0`, `$ErrorActionPreference = 'Stop'`, and `SupportsShouldProcess` behavior intact unless the task explicitly changes them.
- Preserve usable `-WhatIf` behavior wherever the script already supports safe preview without elevation.
- Write generated validation output to `artifacts/validation/`, not to tracked repo files.
- Do not assume `.agents/`, `.codex/agents/`, or `.github/workflows/` exist in this checkout just because older notes or changelog entries mention them.

## Validation Entry Points

- Root validator: `Invoke-WhatIfValidation.ps1`
- Pester tests: `tests/`
- Analyzer runner: `& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PWD 'tools\Invoke-PSScriptAnalyzer.ps1') -Path . -Recurse -SettingsPath (Join-Path $PWD 'tools\PSScriptAnalyzerSettings.psd1') -EnableExit -ExitCodeMode AllDiagnostics`
- Performance regression check: `& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PWD 'tools\Invoke-PerformanceRegressionCheck.ps1') -EnableExit`
- Analyzer regression tests: `Invoke-Pester -Path '.\tests\tools\Invoke-PSScriptAnalyzer.Tests.ps1'`
- GitHub Actions workflow: `.github/workflows/powershell-ci.yml`

## Detailed Workflow

Use `AGENTS.md` for the full playbook and `docs/sysadmin-main-multi-agent-sop.md` for the longer role and workflow notes that match this checkout.
