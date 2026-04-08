. (Resolve-Path (Join-Path $PSScriptRoot 'TestHelpers.ps1')).Path

Describe 'WhatIf validation harness' {

    BeforeAll {
        $script:RepoRoot = Get-SysadminMainRepoRoot
        $script:ScriptPath = Join-Path $script:RepoRoot 'Invoke-WhatIfValidation.ps1'
        $script:PowerShellPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    }

    It 'records invocation failures when the child PowerShell process cannot be started' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $resultPath = Join-Path $tempRoot 'whatif-validation.txt'
            $escapedScriptPath = $script:ScriptPath.Replace("'", "''")
            $escapedResultPath = $resultPath.Replace("'", "''")
            $missingPowerShellPath = 'C:\DoesNotExist\System32\WindowsPowerShell\v1.0\powershell.exe'
            $escapedPowerShellPath = $missingPowerShellPath.Replace("'", "''")
            $invocation = @"
& '$escapedScriptPath' -ResultPath '$escapedResultPath' -PowerShellPath '$escapedPowerShellPath'
"@

            $null = @(
                $invocation |
                    & $script:PowerShellPath -NoProfile -ExecutionPolicy Bypass -Command - 2>&1 |
                    ForEach-Object { $_.ToString() }
            )
            $exitCode = $LASTEXITCODE
            $resultText = Get-Content -LiteralPath $resultPath -Raw

            $exitCode | Should -Be 1
            $resultText | Should -Match 'Success\s*:\s*False'
            $resultText | Should -Match 'Invocation failed'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
