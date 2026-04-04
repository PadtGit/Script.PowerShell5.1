# sysadmin-main ExecPlan Guide

This file defines how to write and maintain an execution plan ("ExecPlan") in this checkout. An ExecPlan is a self-contained design-and-execution document that a novice can follow from the current working tree alone. Any ExecPlan created for this repository must follow this file exactly.

This repository is a Windows PowerShell 5.1 sysadmin script tree. The plan writer must assume the next reader has no memory of previous tasks, no access to upstream repositories, and no context beyond this checkout plus the single ExecPlan file being read.

## Purpose

Use an ExecPlan when a task needs more than a tiny one-file edit. The plan must explain why the work matters to a Windows administrator, what will visibly work after the change, which files must be edited, which commands must be run, and what success looks like in this repository. The goal is not "code that seems plausible." The goal is a novice being able to reproduce a working, observable result safely.

The default active ExecPlan filename in this checkout is `plan.md` at the repository root unless the user asks for another location. This file, `PLANS.md`, is the standing authoring guide. An active `plan.md` must say near the top that it follows `PLANS.md`.

## Repository Assumptions You Must Repeat Inside Every ExecPlan

Every ExecPlan must restate the repository facts it depends on. Do not assume the reader has already opened `AGENTS.md` or `SKILL.md`. `AGENTS.md` remains the canonical source for workflow commands in this checkout; if a plan repeats a command, keep it aligned with that file.

- This branch supports Windows PowerShell 5.1 only.
- Treat `PowerShell Script/` as the canonical runtime script tree.
- Runtime scripts under `PowerShell Script/` are meant to stay copyable as single files for PC-side use.
- If an original runtime script still has fixed launch-time defaults, add a sibling `.Standalone.ps1` copy rather than changing that original launch contract.
- Generated validation output belongs under `artifacts/validation/`.
- Repo-root tools, tests, and sandbox helpers assume the local checkout layout even though runtime scripts are copy-to-PC surfaces.
- Historical notes may describe fuller upstream layouts; this checkout does not guarantee those paths exist.

If the plan touches workflow guidance, the plan must also say that `AGENTS.md`, `PLANS.md`, `SKILL.md`, `README.md`, and affected files under `docs/` need to stay aligned in the same change set.

## Safety Rules You Must Preserve

Every ExecPlan must call out the safety invariants that apply to the target files. At minimum, repeat the ones that matter for the task.

- Preserve truthful `#Requires -Version ...` declarations.
- Preserve `Set-StrictMode -Version 3.0` unless the task explicitly changes that contract.
- Preserve `$ErrorActionPreference = 'Stop'` unless the task explicitly changes that contract.
- Preserve `[CmdletBinding(SupportsShouldProcess = $true)]` on scripts that change system state.
- Preserve usable `-WhatIf` behavior wherever the script already supports safe preview without elevation.
- Keep admin-only execution gates truthful, but do not block safe preview paths that can remain usable without elevation.
- Keep exit codes and structured result objects stable unless the task explicitly changes the contract.
- Prefer summary-style output over noisy transcript-style output unless the task explicitly calls for detailed logging.

The plan must explain how the chosen implementation respects those rules. Do not leave that reasoning implicit.

## What an ExecPlan Must Contain

Each ExecPlan must be a living document. It must stay accurate as work progresses, even if the implementation changes direction. Every ExecPlan in this repository must contain these sections with exactly these names:

- `Purpose / Big Picture`
- `Progress`
- `Surprises & Discoveries`
- `Decision Log`
- `Outcomes & Retrospective`
- `Context and Orientation`
- `Plan of Work`
- `Concrete Steps`
- `Validation and Acceptance`
- `Idempotence and Recovery`
- `Artifacts and Notes`
- `Interfaces and Dependencies`

The `Progress` section must use checkboxes and timestamps. Every time work pauses, update `Progress` to show what is done and what remains. If a task is partially complete, split it into a completed statement and a remaining statement instead of leaving an ambiguous checkbox.

The `Surprises & Discoveries` section must capture unexpected behavior that shaped the work. In this repo that often means `-WhatIf` behavior, Pester behavior, Windows Sandbox constraints, analyzer diagnostics, path-trust concerns, service restart behavior, or validation-artifact handling. Include short evidence snippets when possible.

The `Decision Log` must record each material decision, why it was made, and who made it. If the plan changes course, record that explicitly.

The `Outcomes & Retrospective` section must summarize what was achieved, what remains, and what the next contributor should learn from the work.

## Formatting Rules for ExecPlans

If the ExecPlan is being sent in chat, it must be one fenced code block labeled `md` with no nested triple-backtick fences. Use indented blocks when showing commands, output, or code excerpts.

If the ExecPlan is written to a Markdown file whose content is only the ExecPlan, omit the outer triple backticks. A repo-root `plan.md` in this repository should therefore be ordinary Markdown, not wrapped in a fence.

Narrative sections must be prose-first. Use lists only when they genuinely improve clarity. Checklists are mandatory only in `Progress`. Avoid tables unless a table is the clearest possible explanation.

Define every non-obvious term the first time it appears. In this repo, examples of terms that usually need plain-language definitions are:

- `-WhatIf`: PowerShell preview mode that reports what a command would do without applying the change.
- Pester: the PowerShell test framework used by `tests/`.
- PSScriptAnalyzer: the PowerShell static-analysis tool run by `tools/Invoke-PSScriptAnalyzer.ps1`.
- Windows Sandbox: the disposable Windows environment launched by `sandbox/sysadmin-main-validation.wsb` for risky manual validation.
- `.Standalone.ps1`: a sibling runtime script copy used when the original script has baked-in launch defaults that must remain unchanged.

## How to Write a Good ExecPlan for This Repository

Begin with user-visible value. Explain what a Windows administrator can do after the change that was unreliable, unsafe, or impossible before. Then explain how to observe that behavior safely in this repository. If the change is internal, describe the external proof, such as a failing Pester test that passes after the edit or a `-WhatIf` transcript that now reports the right action.

Orient the novice before asking them to edit anything. Name the exact files and why each one matters. Example: if the task changes a runtime printer script, say whether the primary edit is under `PowerShell Script/Printer/`, whether a `.Standalone.ps1` sibling is needed, whether tests belong under `tests/`, whether analyzer behavior is relevant, and whether `AGENTS.md`, `PLANS.md`, `SKILL.md`, `README.md`, or `docs/` must be updated because workflow guidance changed.

Resolve ambiguity inside the plan. Do not write "choose the best place" or "update tests as needed." Say which file to edit, which function or script block to change, what behavior to preserve, and how to verify the result. The next contributor should not have to invent missing requirements.

Keep the plan safe to retry. If a command can be re-run, say so. If a step can fail halfway, explain the cleanup or retry path. Prefer additive edits and behavior-first validation over destructive rewrites.

## Repo-Specific Validation You Must Include

Every ExecPlan must include the exact validation commands appropriate to the change. Do not hand-wave with "run tests." Use concrete commands from the repo and explain what the reader should observe.

`AGENTS.md` owns the canonical command blocks for this checkout. When an ExecPlan quotes a command, copy it from `AGENTS.md` and then describe the expected observation or success condition.

For script behavior that already supports preview safely, include a targeted `-WhatIf` command such as:

    Working directory: C:\Users\Bob\Documents\Script.PowerShell5.1
    Command:
      & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\PowerShell Script\<category>\<script>.ps1' -WhatIf

For the fixed-list branch validator, use:

    Working directory: C:\Users\Bob\Documents\Script.PowerShell5.1
    Command:
      & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\Invoke-WhatIfValidation.ps1'

For static analysis, use the repo-wide analyzer baseline unless the plan is explicitly scoped narrower:

    Working directory: C:\Users\Bob\Documents\Script.PowerShell5.1
    Command:
      & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PWD 'tools\Invoke-PSScriptAnalyzer.ps1') `
        -Path . `
        -Recurse `
        -SettingsPath (Join-Path $PWD 'tools\PSScriptAnalyzerSettings.psd1') `
        -EnableExit `
        -ExitCodeMode AllDiagnostics

If the plan changes analyzer output or failure handling, also include the focused regression suite:

    Working directory: C:\Users\Bob\Documents\Script.PowerShell5.1
    Command:
      Invoke-Pester -Path '.\tests\tools\Invoke-PSScriptAnalyzer.Tests.ps1'

For general test coverage, use one of these Pester commands and say why that scope is appropriate:

    Working directory: C:\Users\Bob\Documents\Script.PowerShell5.1
    Command:
      Invoke-Pester -Path '.\tests'

    Working directory: C:\Users\Bob\Documents\Script.PowerShell5.1
    Command:
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

If the task changes a risky script, the plan should also describe Windows Sandbox validation using `sandbox/sysadmin-main-validation.wsb` and the expected in-Sandbox working directory `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`. Note that the mapped repo is read-only in Sandbox, so persistent `artifacts/validation/` review still belongs to the host checkout unless the plan intentionally redirects output to a disposable in-Sandbox path.

Every validation section must say what success looks like. Examples:

- The script returns without applying changes under `-WhatIf` and reports the intended actions.
- `artifacts/validation/psscriptanalyzer.json` exists and contains `[]` on a clean analyzer run.
- The named Pester test fails before the change and passes after it.
- The Sandbox session opens in the documented mapped path and the risky command can be previewed there safely.

## Milestones

Milestones are encouraged when the work is large, risky, or uncertain. Each milestone must tell a short story in prose: the goal of the milestone, the files to edit, the command or commands to run, and the behavior that proves the milestone is complete.

In this repo, useful milestone boundaries often look like:

- first making `-WhatIf` truthful without changing live behavior,
- then adding or updating Pester coverage,
- then validating analyzer and artifact output,
- then updating workflow documentation if the change affects durable repo guidance.

If feasibility is uncertain, include an explicit prototyping milestone. For example, a prototype may prove whether a service-control script can keep safe preview behavior without elevation, or whether an analyzer helper can surface a structured failure without losing JSON output. A prototype is acceptable only if the plan explains how to run it, how to observe it, and when it should be promoted or discarded.

## Required Repo Context to Mention When Relevant

Call out these paths when they matter so a novice can navigate confidently:

- `PowerShell Script/`: runtime scripts
- `Invoke-WhatIfValidation.ps1`: branch-level `-WhatIf` validator
- `tests/`: Pester suites
- `tests/TestHelpers.ps1`: shared test helpers
- `tests/tools/Invoke-PSScriptAnalyzer.Tests.ps1`: analyzer regression tests
- `tools/Invoke-PSScriptAnalyzer.ps1`: analyzer runner
- `tools/PSScriptAnalyzerSettings.psd1`: analyzer settings
- `artifacts/validation/`: generated validation output
- `sandbox/sysadmin-main-validation.wsb`: disposable Sandbox launcher
- `sandbox/Start-SysadminMainSandboxShell.ps1`: helper that sets the in-Sandbox working directory
- `AGENTS.md`: local playbook and safety rules
- `PLANS.md`: this ExecPlan guide
- `SKILL.md`: short workflow entrypoint
- `README.md`: repo overview
- `docs/sysadmin-main-multi-agent-sop.md`: longer workflow notes
- `docs/windows-sandbox-validation.md`: manual Sandbox validation notes

## ExecPlan Skeleton for This Repository

Use the following structure as the starting point for a repo-root `plan.md`. Replace the placeholder text with task-specific content and keep every section current while work progresses.

    # <Short, action-oriented task title>

    This ExecPlan is a living document. Keep `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` current as the work advances.

    This plan follows `PLANS.md` from the repository root.

    ## Purpose / Big Picture

    Explain what a Windows administrator can do after this change, how that differs from the current behavior, and how to observe the improvement safely in this repository.

    ## Progress

    - [ ] (YYYY-MM-DD HH:MMZ) Initial repo mapping completed.
    - [ ] (YYYY-MM-DD HH:MMZ) Runtime script or tool change implemented.
    - [ ] (YYYY-MM-DD HH:MMZ) Tests and validation updated.
    - [ ] (YYYY-MM-DD HH:MMZ) Workflow docs synced if durable guidance changed.

    ## Surprises & Discoveries

    - Observation: <unexpected behavior or constraint>
      Evidence: <short command output or concise note>

    ## Decision Log

    - Decision: <what was decided>
      Rationale: <why this path was chosen>
      Date/Author: <YYYY-MM-DD, name>

    ## Outcomes & Retrospective

    Summarize what now works, what still remains, and what the next contributor should remember.

    ## Context and Orientation

    Describe the current repository surfaces involved in plain language. Name the exact files under `PowerShell Script/`, `tests/`, `tools/`, `artifacts/validation/`, and `docs/` that matter to this task. Repeat the PowerShell 5.1 and `-WhatIf` assumptions if they matter.

    ## Plan of Work

    Describe, in prose, the sequence of edits. Name each file, what will change, and what must stay stable.

    ## Concrete Steps

    Show the exact commands to run from `C:\Users\Bob\Documents\Script.PowerShell5.1`, plus short expected outputs or observations.

    ## Validation and Acceptance

    Describe the exact `-WhatIf`, Pester, analyzer, artifact-review, and Sandbox checks required for this task. State the human-observable acceptance criteria.

    ## Idempotence and Recovery

    Explain which steps are safe to re-run, how to recover from partial validation output under `artifacts/validation/`, and how to avoid damaging live systems.

    ## Artifacts and Notes

    Include the most important short transcripts, result-object snippets, or diff excerpts that prove success.

    ## Interfaces and Dependencies

    Name the functions, script parameters, result-object properties, helper files, or external Windows features that must exist at the end of the task.

## Final Revision Note Requirement

Whenever an ExecPlan is revised, add a short note at the bottom of the plan stating what changed and why. This note is mandatory because the next contributor may have only the updated plan and no other history.

## Proof Standard

An ExecPlan for this repository is complete only when a novice can read it from top to bottom, find the right PowerShell 5.1 files, make the changes safely, run the documented validation commands, inspect the expected artifacts, and confirm working behavior without needing unstated repository knowledge.
