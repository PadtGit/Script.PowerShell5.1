. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'V5 network reset and reboot behavior' {

    BeforeAll {
        . (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path
$script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'PowerShell Script\windows-maintenance\Reset.Network.RebootPC.ps1'
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns a preview-safe WhatIf summary' {
$Result = Invoke-WhatIfScriptObject -RelativeScriptPath 'PowerShell Script\windows-maintenance\Reset.Network.RebootPC.ps1'

        $Result.Object | Should -Not -BeNullOrEmpty
        $Result.Object.CommandCount | Should -Be 5
        $Result.Object.ExecutedCount | Should -Be 0
        $Result.Object.Status | Should -Be 'WhatIf'
        $Result.Object.Reason | Should -Be ''
    }

    It 'returns a skipped result in Windows Sandbox without running commands' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            $result = Invoke-NetworkReset `
                -RequireAdmin $false `
                -IsAdministrator $false `
                -IsWindowsSandbox $true `
                -Commands @(
                    @{
                        FilePath  = 'C:\DoesNotExist\netsh.exe'
                        Arguments = @('int', 'ip', 'reset')
                    }
                ) `
                -ShutdownPath 'C:\Windows\System32\shutdown.exe' `
                -RebootDelaySeconds 5

            $result.CommandCount | Should -Be 1
            $result.ExecutedCount | Should -Be 0
            $result.Status | Should -Be 'Skipped'
            $result.Reason | Should -Be 'NetworkResetUnsupportedInWindowsSandbox'
        }
    }

    It 'fails when reboot scheduling returns a non-zero exit code' {
        $moduleName = $script:ModuleInfo.ModuleName
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force
        $shutdownPath = Join-Path $tempRoot 'fail-shutdown.cmd'
        $commandPath = Join-Path $tempRoot 'noop.cmd'

        try {
            Set-Content -LiteralPath $shutdownPath -Encoding ASCII -Value "@echo off`r`nexit /b 5`r`n"
            Set-Content -LiteralPath $commandPath -Encoding ASCII -Value "@echo off`r`nexit /b 0`r`n"

            InModuleScope $moduleName {
                param($shutdownPath, $commandPath)

                {
                    Invoke-NetworkReset `
                        -RequireAdmin $false `
                        -IsAdministrator $true `
                        -IsWindowsSandbox $false `
                        -Commands @(
                            @{
                                FilePath  = $commandPath
                                Arguments = @()
                            }
                        ) `
                        -ShutdownPath $shutdownPath `
                        -RebootDelaySeconds 5
                } | Should -Throw '*Restart scheduling failed*'
            } -Parameters @{
                shutdownPath = $shutdownPath
                commandPath  = $commandPath
            }
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
