# Security Ownership Map Summary

## Overview

This summary is based on the generated ownership artifacts in `artifacts/security/ownership-map-out/`, using the repo-specific sensitivity rules in `artifacts/security/ownership-sensitive.csv`.

## Key Results

- Effective people in git history: `1`
- Included commits: `4`
- Files seen: `49`
- Sensitive touches attributed: `9.00`
- Time zone observed for the effective owner: `-04:00`

## Highest-Risk Ownership Signals

- All tagged sensitive categories are effectively controlled by the same email, `it.gat.templeton@gmail.com`.
- Every tagged security-sensitive script is currently a bus-factor hotspot with `bus_factor = 1`.
- There is no orphaned sensitive code in the current shallow history window, but there is also no ownership redundancy.

## Sensitive Categories Controlled By One Owner

| Category | Current owner | Share |
| --- | --- | --- |
| `validation_entrypoint` | `System Admin <it.gat.templeton@gmail.com>` | `100%` |
| `package_install` | `System Admin <it.gat.templeton@gmail.com>` | `100%` |
| `service_control` | `System Admin <it.gat.templeton@gmail.com>` | `100%` |
| `installer_store` | `System Admin <it.gat.templeton@gmail.com>` | `100%` |
| `destructive_cleanup` | `System Admin <it.gat.templeton@gmail.com>` | `100%` |
| `network_stack` | `System Admin <it.gat.templeton@gmail.com>` | `100%` |

## Bus-Factor Hotspots

| Path | Tags | Bus factor |
| --- | --- | --- |
| `Invoke-WhatIfValidation.ps1` | `validation_entrypoint` | `1` |
| `PowerShell Script/Adobe/Install.AdobeAcrobat.Clean.ps1` | `package_install` | `1` |
| `PowerShell Script/Printer/Restart.Spool.DeletePrinterQSimple.ps1` | `service_control` | `1` |
| `PowerShell Script/Printer/Restart.spool.delete.printerQ.ps1` | `service_control` | `1` |
| `PowerShell Script/Printer/restart.SpoolDeleteQV4.ps1` | `service_control` | `1` |
| `PowerShell Script/WindowsServer/FichierOphelin.ps1` | `installer_store` | `1` |
| `PowerShell Script/windows-maintenance/Move-OrphanedInstallerFiles.ps1` | `installer_store` | `1` |
| `PowerShell Script/windows-maintenance/Nettoyage.Avance.Windows.Sauf.logserreur.ps1` | `destructive_cleanup` | `1` |
| `PowerShell Script/windows-maintenance/Nettoyage.Complet.Caches.Windows.ps1` | `destructive_cleanup` | `1` |
| `PowerShell Script/windows-maintenance/Reset.Network.RebootPC.ps1` | `network_stack` | `1` |

## Interpretation

- This repo’s security-sensitive paths are not ownerless; they are concentrated.
- That concentration reduces resilience for security review, maintenance continuity, and emergency response.
- The immediate process fix is not broad reorganization; it is assigning at least one additional reviewer or maintainer to the destructive/admin script paths.

## Generated Artifacts

- `artifacts/security/ownership-map-out/summary.json`
- `artifacts/security/ownership-map-out/people.csv`
- `artifacts/security/ownership-map-out/files.csv`
- `artifacts/security/ownership-map-out/edges.csv`
- `artifacts/security/ownership-map-out/cochange_edges.csv`
- `artifacts/security/ownership-map-out/communities.json`
- `artifacts/security/ownership-map-out/cochange.graph.json`
- `artifacts/security/ownership-map-out/commits.jsonl`
