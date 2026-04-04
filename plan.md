# Add Dedicated Printer Export Performance Check

This ExecPlan is a living document. Keep `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` current as the work advances.

This plan follows `PLANS.md` from the repository root.

## Purpose / Big Picture

Windows administrators need an early signal when the printer export hardening tests start getting materially slower, but the current repo has no dedicated performance check, no committed performance baseline, and no safe way to distinguish real drift from normal run-to-run timing noise. After this change, the repo will have a PowerShell 5.1-friendly performance checker that repeatedly measures the export security Pester suite, compares the median run time against a committed baseline, writes results under `artifacts/validation/`, and reports drift without failing validation by default. That gives us a measurable signal now and a clean upgrade path to stricter CI enforcement later if the median stabilizes.

This repository supports Windows PowerShell 5.1 only. Treat `PowerShell Script/` as the canonical runtime script tree. Runtime scripts under `PowerShell Script/` stay copyable as single files for PC-side use. If an original runtime script still has fixed launch-time defaults, add a sibling `.Standalone.ps1` copy rather than changing that original launch contract. Generated validation output belongs under `artifacts/validation/`. Repo-root tools, tests, and sandbox helpers assume the local checkout layout even though runtime scripts are copy-to-PC surfaces. Historical notes may mention `.agents/`, `.codex/agents/`, or `.github/workflows/`; this checkout does not guarantee those paths exist.

The safety rules that matter here are tooling and validation invariants rather than runtime script semantics: preserve truthful `#Requires -Version ...` declarations, preserve `Set-StrictMode -Version 3.0`, preserve `$ErrorActionPreference = 'Stop'`, keep `-WhatIf` behavior unchanged for existing scripts, keep exit codes and structured result objects stable unless intentionally extending a tool contract, and prefer summary-style output over noisy logs. Because this change introduces durable validation workflow guidance, `AGENTS.md`, `SKILL.md`, `README.md`, and affected docs under `docs/` must stay aligned in the same change set.

## Progress

- [x] (2026-04-04 01:50Z) Initial repo mapping completed for current tests, artifacts, and validation tooling.
- [x] (2026-04-04 02:30Z) Dedicated performance regression tool and baseline implemented under `tools\Invoke-PrinterExportPerformanceCheck.ps1` and `tools\performance-baselines\printer-export-security.json`.
- [x] (2026-04-04 02:30Z) Focused tests and validation coverage added with `tests\tools\Invoke-PrinterExportPerformanceCheck.Tests.ps1`.
- [x] (2026-04-04 02:30Z) Workflow docs synced for the new durable validation command across `AGENTS.md`, `README.md`, `SKILL.md`, `docs\sysadmin-main-multi-agent-sop.md`, and `CHANGELOG.md`.

## Surprises & Discoveries

- Observation: This checkout has no existing perf checker, baseline file, or trace artifact surface; current timing evidence comes only from committed `artifacts/validation/pester-results.xml`.
  Evidence: repo search found no `Invoke-PerformanceRegressionCheck` script or perf baseline file.
- Observation: The export security suite still shows measurable slowdown locally, but batch-vs-single-suite reruns vary enough that a hard CI gate would be noisy today.
  Evidence: local reruns produced `8.92s` in a 4-suite batch and `5.44s` when rerun alone, versus `3.48s` in commit `c0ec305`.
- Observation: a 3-run execution of the new dedicated checker still reports a strong advisory regression against the committed baseline.
  Evidence: `artifacts\validation\printer-export-performance.txt` recorded `15.4478s`, `9.7044s`, and `9.7390s`, with a median of `9.7390s` versus the `3.4814s` baseline.

## Decision Log

- Decision: Build a dedicated soft-reporting performance checker before any hard CI enforcement.
  Rationale: only one suite currently reproduces slowdown and its variance is too high for a reliable required gate.
  Date/Author: 2026-04-04, Codex
- Decision: Scope the first baseline to `tests\Printer\Export.printer.list.Security.Tests.ps1` rather than inventing a repo-wide performance system.
  Rationale: this is the only suite with sustained drift, and a narrow tool keeps the change small and easier to validate.
  Date/Author: 2026-04-04, Codex

## Outcomes & Retrospective

The repo now has a narrow, advisory-first performance checker for `tests\Printer\Export.printer.list.Security.Tests.ps1`. The checker runs repeated Pester measurements, compares the median to a committed baseline, writes TXT and JSON artifacts under `artifacts\validation\`, and keeps failure optional behind `-EnableExit -FailOnRegression`. Focused Pester coverage locks in baseline parsing, median calculation, artifact generation, and advisory reporting, and the core workflow docs now mention the new command.

What remains is a product decision rather than missing implementation: whether to keep refining the baseline and measurement stability, or to promote the check into stricter enforcement later. The current measured median is still well above the seeded baseline, so the checker is already surfacing a real advisory signal.

## Context and Orientation

The key current surfaces are:

- `tests\Printer\Export.printer.list.Security.Tests.ps1`: the suite we want to measure repeatedly.
- `tests\TestHelpers.ps1`: shared helpers used by Pester tests if the new checker needs test-time support.
- `artifacts\validation\pester-results.xml`: current committed source of timing evidence.
- `tools\Invoke-PSScriptAnalyzer.ps1`: the existing repo-level validation helper whose shape is a good reference for result reporting and artifact output.
- `AGENTS.md`, `README.md`, `SKILL.md`, and `docs\sysadmin-main-multi-agent-sop.md`: workflow entrypoints that need the new command if it becomes part of durable validation guidance.

The new tool should live under `tools\` because it is repo-local validation infrastructure rather than a runtime script to copy to a PC. The committed baseline should live under `tools\` or a sibling tooling data directory so it is versioned with the checker. Generated measurement output belongs under `artifacts\validation\`.

## Plan of Work

First, add a small PowerShell 5.1 tool under `tools\` that runs the export security Pester suite multiple times, captures container durations, computes a median, compares that median against a committed baseline, and emits a compact object plus TXT/JSON artifacts under `artifacts\validation\`. The default behavior should report drift but not fail unless explicitly asked to do so later.

Next, add a focused Pester suite for the new tool. The tests should lock in baseline parsing, median calculation, repeated-run aggregation, artifact writing, and soft-reporting behavior when the median exceeds the threshold. Those tests should avoid slow live timing by mocking the measurement layer.

Finally, validate the tool locally against the real export suite, review the generated artifacts, and update workflow docs so contributors know the new command exists and that it is currently advisory rather than a hard gate.

## Concrete Steps

Working directory: `C:\Users\Bob\Documents\Script.PowerShell5.1`

1. Implement the new checker and baseline:
   Command:
     edit `tools\Invoke-PrinterExportPerformanceCheck.ps1`
     add a committed baseline file for the export suite

2. Add focused regression coverage:
   Command:
     edit `tests\tools\Invoke-PrinterExportPerformanceCheck.Tests.ps1`

3. Run the new focused tests:
   Command:
     Invoke-Pester -Path '.\tests\tools\Invoke-PrinterExportPerformanceCheck.Tests.ps1'
   Expected:
     the new tool tests pass and prove median/baseline/reporting behavior without depending on noisy wall-clock runs.

4. Run the dedicated checker against the real suite:
   Command:
     & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\tools\Invoke-PrinterExportPerformanceCheck.ps1'
   Expected:
     the command completes, writes validation artifacts under `artifacts\validation\`, and reports the measured median plus any advisory drift signal.

5. Run existing validation needed for touched tooling:
   Command:
     Invoke-Pester -Path '.\tests\tools'
   Expected:
     tool-focused regression coverage still passes.

## Validation and Acceptance

Acceptance requires all of the following:

- The new checker runs under Windows PowerShell 5.1 and measures `tests\Printer\Export.printer.list.Security.Tests.ps1` repeatedly.
- A committed baseline exists and the checker compares the median run time to that baseline.
- The checker writes generated output under `artifacts\validation\`.
- Default behavior reports drift without failing the run solely because of performance variance.
- Focused Pester tests pass for baseline loading, median calculation, artifact writing, and advisory reporting.

Concrete validation commands:

    Working directory: C:\Users\Bob\Documents\Script.PowerShell5.1
    Command:
      Invoke-Pester -Path '.\tests\tools\Invoke-PrinterExportPerformanceCheck.Tests.ps1'

    Working directory: C:\Users\Bob\Documents\Script.PowerShell5.1
    Command:
      & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\tools\Invoke-PrinterExportPerformanceCheck.ps1'

    Working directory: C:\Users\Bob\Documents\Script.PowerShell5.1
    Command:
      Get-Content '.\artifacts\validation\printer-export-performance.txt'
      Get-Content '.\artifacts\validation\printer-export-performance.json' -Raw | ConvertFrom-Json

Success looks like a passing focused tool test suite, a real measurement artifact pair in `artifacts\validation\`, and a summary that clearly shows median, baseline, delta, and advisory status.

## Idempotence and Recovery

The checker must be safe to rerun because it only executes Pester tests and overwrites its own validation artifacts. If an artifact write is interrupted, rerunning the checker should replace the partial TXT/JSON files. The Pester tests should use isolated temp paths or mocks so repeated runs do not depend on prior artifact state. This plan does not change live admin scripts, so there is no live-system recovery path beyond rerunning the tool after fixing code.

## Artifacts and Notes

Expected generated artifacts after implementation:

- `artifacts\validation\printer-export-performance.txt`
- `artifacts\validation\printer-export-performance.json`

Important existing evidence captured before implementation:

- Local rerun of `tests\Printer\Export.printer.list.Security.Tests.ps1`: `5.44s`
- Earlier committed timing in `c0ec305`: `3.4814s`

## Interfaces and Dependencies

The final tool will depend on:

- Pester 5 via `New-PesterConfiguration` and `Invoke-Pester`
- A committed baseline file that names the measured suite and expected median
- `artifacts\validation\` as the output root
- A structured result object that includes suite path, run count, raw run durations, median, baseline, delta, and advisory status

Revision note (2026-04-04): Created the initial ExecPlan after confirming the repo has no dedicated performance checker and that only the printer export security suite still reproduces measurable slowdown.
Revision note (2026-04-04): Updated progress and outcomes after implementing the new checker, adding focused tests, validating local advisory output, and syncing the durable workflow docs.
