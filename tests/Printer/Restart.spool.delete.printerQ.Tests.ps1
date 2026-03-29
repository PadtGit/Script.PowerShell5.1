. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'V5 spool cleanup behavior' {

    BeforeAll {
        . (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path
        try {
            Add-Type -AssemblyName 'System.ServiceProcess' -ErrorAction Stop
        }
        catch {
            Add-Type -AssemblyName 'System.ServiceProcess.ServiceController' -ErrorAction Stop
        }
        $script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'PowerShell Script\Printer\Restart.spool.delete.printerQ.ps1'
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects a reparse-point spool directory before touching the service' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($spoolDirectory, $spoolRoot)

            $spoolDirectoryItem = [System.IO.DirectoryInfo]::new($spoolDirectory)
            $spoolRootItem = [System.IO.DirectoryInfo]::new($spoolRoot)

            Mock Test-Path {
                $LiteralPath -in @($spoolDirectory, $spoolRoot)
            }
            Mock Get-Item {
                if ($LiteralPath -eq $spoolRoot) {
                    return $spoolRootItem
                }

                return $spoolDirectoryItem
            }
            Mock Test-IsReparsePoint {
                param($Item)

                $Item.FullName -eq $spoolDirectory
            }
            Mock Get-Service {}

            {
                Invoke-PrintQueueCleanup `
                    -RequireAdmin $false `
                    -IsAdministrator $false `
                    -ServiceName 'Spooler' `
                    -SpoolDirectory $spoolDirectory `
                    -SpoolAllowedRoots @($spoolRoot) `
                    -TimeoutSeconds 30 `
                    -AllowedExtensions @('.spl', '.shd')
            } | Should -Throw '*reparse point*'

            Assert-MockCalled Get-Service -Times 0 -Exactly -Scope It
        } -Parameters @{
            spoolDirectory = 'C:\Windows\System32\spool\PRINTERS'
            spoolRoot      = 'C:\Windows\System32\spool'
        }
    }

    It 'filters reparse-point spool files during WhatIf preview' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($spoolDirectory, $spoolRoot)

            $service = [pscustomobject]@{
                Status = [System.ServiceProcess.ServiceControllerStatus]::Stopped
            }
            Add-Member -InputObject $service -MemberType ScriptMethod -Name WaitForStatus -Value {
                param($Status, $Timeout)
            } -Force
            $spoolDirectoryItem = [System.IO.DirectoryInfo]::new($spoolDirectory)
            $spoolRootItem = [System.IO.DirectoryInfo]::new($spoolRoot)
            $keptFile = [System.IO.FileInfo]::new((Join-Path $spoolDirectory 'job1.spl'))
            $skippedFile = [System.IO.FileInfo]::new((Join-Path $spoolDirectory 'job2.shd'))

            Mock Test-Path {
                $LiteralPath -in @($spoolDirectory, $spoolRoot)
            }
            Mock Get-Item {
                if ($LiteralPath -eq $spoolRoot) {
                    return $spoolRootItem
                }

                return $spoolDirectoryItem
            }
            Mock Test-IsReparsePoint {
                param($Item)

                $Item.FullName -eq $skippedFile.FullName
            }
            Mock Get-Service { $service }
            Mock Stop-Service {}
            Mock Start-Service {}
            Mock Get-ChildItem { @($keptFile, $skippedFile) } -ParameterFilter { $LiteralPath -eq $spoolDirectory -and $File }
            Mock Remove-Item {}

            $result = Invoke-PrintQueueCleanup `
                -RequireAdmin $false `
                -IsAdministrator $false `
                -ServiceName 'Spooler' `
                -SpoolDirectory $spoolDirectory `
                -SpoolAllowedRoots @($spoolRoot) `
                -TimeoutSeconds 30 `
                -AllowedExtensions @('.spl', '.shd') `
                -WhatIf

            $result.FileCount | Should -Be 1
            $result.DeletedCount | Should -Be 0
            $result.Status | Should -Be 'WhatIf'

            Assert-MockCalled Remove-Item -Times 0 -Exactly -Scope It
        } -Parameters @{
            spoolDirectory = 'C:\Windows\System32\spool\PRINTERS'
            spoolRoot      = 'C:\Windows\System32\spool'
        }
    }
}
