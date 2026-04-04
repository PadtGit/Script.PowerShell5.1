## Summary
- add a dedicated advisory printer export performance checker with a committed baseline
- add focused Pester coverage for median calculation, baseline loading, and advisory artifact reporting
- trim the printer export security tests so the dedicated checker now measures within the seeded baseline

## Validation
- Invoke-Pester -Path '.\\tests\\tools\\Invoke-PrinterExportPerformanceCheck.Tests.ps1'
- Invoke-Pester -Path '.\\tests\\tools'
- Invoke-Pester -Path '.\\tests\\Printer\\Export.printer.list.Security.Tests.ps1'
- & "$env:SystemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File '.\\tools\\Invoke-PrinterExportPerformanceCheck.ps1' -RunCount 3
