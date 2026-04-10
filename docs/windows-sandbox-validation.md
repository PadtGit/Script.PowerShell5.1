# Windows Sandbox Validation

## Purpose

Use Windows Sandbox for manual validation of risky scripts such as:

- network reset/reboot
- installer orphan move
- broad cleanup scripts

## Repo Template

- Sandbox file: `sandbox/sysadmin-main-validation.wsb`
- Sandbox shell helper: `sandbox/Start-SysadminMainSandboxShell.ps1`
- Host repo path: `C:\Users\Bob\Documents\Script.PowerShell5.1`
- Sandbox repo path: `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`
- The host repo is mapped read-only into the Sandbox.
- This branch keeps the in-Sandbox working folder at `sysadmin-main` so the documented validation commands stay stable after the Windows PowerShell 5.1 branch split.
- Keep the host-side validation tooling baseline pinned to `PSScriptAnalyzer 1.25.0` and `Pester 5.7.1` so Sandbox observations line up with local analyzer and test runs.
- Networking is disabled.
- vGPU is disabled.
- The logon command starts PowerShell through `sandbox/Start-SysadminMainSandboxShell.ps1`, which resolves the repo root relative to the helper script and sets that as the working location. In Sandbox this resolves to `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`.
- `AGENTS.md` remains the canonical source for validation commands; this doc only explains how to use the Sandbox safely.

## Validation Flow

1. Launch the `.wsb` file.
2. Confirm PowerShell opens in `C:\Users\WDAGUtilityAccount\Desktop\sysadmin-main`.
3. Run the target script with `-WhatIf` first and review the on-screen result object or summary output.
4. If you need disposable output inside Sandbox, write it to a Sandbox-local path rather than the read-only mapped repo.
5. Review persistent `artifacts/validation/` outputs from the host checkout after local analyzer, Pester, or `-WhatIf` validation; do not expect Sandbox writes to persist back through the mapped repo.
6. Only perform non-`WhatIf` validation when you are intentionally testing inside the disposable Sandbox environment.
