# Security Best Practices Report

## Executive Summary

This Windows PowerShell 5.1 admin-script repo already shows a strong hardening trend: most destructive scripts preserve `SupportsShouldProcess`, enforce strict mode, validate trusted roots, reject reparse points, and harden ProgramData output directories. The main remaining code-level security gap is the printer spool cleanup family, which still deletes files from the spool directory without the same trusted-path and reparse-point checks used elsewhere. The second meaningful risk is operational rather than code-level: all security-sensitive paths are effectively single-owner in git history, which raises the chance that subtle admin-script regressions land without a second reviewer.

## Scope And Constraints

- Repo assessed: `C:\Users\Bob\Documents\Script.PowerShell5.1`
- Primary runtime surface: `PowerShell Script/*`
- Assessment basis: repo-grounded review plus ownership analysis in `artifacts/security/ownership-map-out/`
- Constraint: the `$security-best-practices` skill does not ship PowerShell-specific reference files, so this report uses Windows admin-script secure-by-default practices inferred from the repo and standard PowerShell safety expectations.

## Medium Severity

### BP-001: Printer spool cleanup variants delete from the spool directory without trusted-path or reparse-point validation

Impact: if one of the retained spool-cleanup variants is ever pointed at a redirected or attacker-influenced path, it can delete files under elevated context without first proving the target is still the intended spool directory.

Evidence:

- `PowerShell Script/Printer/Restart.Spool.DeletePrinterQSimple.ps1:49-55` enumerates and deletes spool files directly from `$SpoolDirectory` with no `Test-IsReparsePoint` or trusted-root validation.
- `PowerShell Script/Printer/Restart.spool.delete.printerQ.ps1:54-60` repeats the same deletion pattern.
- `PowerShell Script/Printer/restart.SpoolDeleteQV4.ps1:222-234` hardens the log directory but still deletes spool files from `$SpoolDirectory` without validating the spool directory itself.
- By contrast, `PowerShell Script/windows-maintenance/Move-OrphanedInstallerFiles.ps1:169-228` rejects reparse points and constrains output to a hardened root before moving files.

Why this matters:

- These scripts stop a privileged Windows service and then perform file deletion.
- The rest of the repo already treats path trust and reparse handling as mandatory for destructive operations, so this family is the main outlier.

Recommended fix:

- Introduce a shared trusted-directory resolver for the spool directory, using the same pattern already present in the installer-move and cleanup scripts.
- Reject spool directories and candidate files that are reparse points before enumeration or deletion.
- Add behavior-focused Pester coverage that proves the spool cleanup aborts on reparse-point targets.

### BP-002: Sensitive admin-script ownership has a bus factor of 1 across every tagged security surface

Evidence:

- `artifacts/security/ownership-map-out/summary.json` reports one person and one email controlling 100% of the tagged `service_control`, `installer_store`, `package_install`, `destructive_cleanup`, `network_stack`, and `validation_entrypoint` categories.
- `artifacts/security/ownership-map-out/people.csv` shows a single effective owner, `it.gat.templeton@gmail.com`, with `sensitive_touches` of `9.00`.
- `artifacts/security/ownership-map-out/summary.json` lists every high-risk script as a `bus_factor_hotspot` with `bus_factor: 1`.

Why this matters:

- The codebase is full of admin-only flows that stop services, reboot machines, move installer-store content, or clear OS caches.
- When all of those surfaces depend on one maintainer, security review and recovery both become fragile.

Recommended fix:

- Assign at least one second reviewer or maintainer for the destructive/admin surfaces.
- Add CODEOWNERS or an equivalent review gate for `PowerShell Script/Printer/Restart*.ps1`, `PowerShell Script/windows-maintenance/*.ps1`, `PowerShell Script/Adobe/*.ps1`, and `PowerShell Script/WindowsServer/*.ps1`.
- Keep the ownership-map artifact in the security review loop so bus-factor drift is visible over time.

## Low Severity

### BP-003: Existing printer spool cleanup tests do not cover the missing path-trust defense

Evidence:

- `tests/Printer/Restart.Spool.DeletePrinterQSimple.Tests.ps1:1-12` only asserts structured `-WhatIf` output.
- `tests/Printer/restart.SpoolDeleteQV4.Tests.ps1:22-239` focuses on transcript/service behavior and the `FP*.tmp` rule, but not on spool-directory reparse-point rejection.
- In contrast, `tests/windows-maintenance/Move-OrphanedInstallerFiles.Tests.ps1:16-82` explicitly exercises reparse-point skipping on a destructive file-move flow.

Why this matters:

- The repo already relies on behavioral Pester tests to lock in security hardening.
- Without equivalent regression coverage for the spool-cleanup family, the current gap is easier to miss and future fixes are easier to regress.

Recommended fix:

- Add Pester cases that mock a spool directory or spool file as a reparse point and assert that deletion is skipped or rejected.
- Add a regression test that proves the trusted spool root stays under `%SystemRoot%\\System32\\spool\\PRINTERS`.

## Positive Controls Worth Preserving

- `PowerShell Script/windows-maintenance/Move-OrphanedInstallerFiles.ps1:19-140` and `PowerShell Script/WindowsServer/FichierOphelin.ps1:19-140` already enforce trusted roots, reject reparse points, and harden newly created quarantine directories.
- `PowerShell Script/Adobe/Install.AdobeAcrobat.Clean.ps1:165-278` validates the package signature and publisher before invoking install or uninstall flows.
- `docs/windows-sandbox-validation.md:5-29` and `sandbox/sysadmin-main-validation.wsb` document a disposable Windows Sandbox path for risky validation, with networking disabled and the repo mounted read-only.

## Suggested Next Steps

1. Port the repo’s existing trusted-root and reparse-point pattern into all three spool-cleanup variants.
2. Add matching Pester coverage so the new defense stays locked in.
3. Put a second reviewer on the destructive/admin script paths and keep the ownership map current as the repo evolves.
