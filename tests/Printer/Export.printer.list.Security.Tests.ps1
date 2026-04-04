Describe 'V5 printer export hardening' {
    . (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

    BeforeAll {
        $script:BasicModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'PowerShell Script\Printer\Export.printer.list.BASIC.ps1'
        $script:FullModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'PowerShell Script\Printer\Export.printer.list.FULL.ps1'
    }

    AfterAll {
        if ($null -ne $script:BasicModuleInfo) {
            Remove-Module -Name $script:BasicModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }

        if ($null -ne $script:FullModuleInfo) {
            Remove-Module -Name $script:FullModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'uses a secured per-user path and unique file name for the basic export preview' {
        $moduleName = $script:BasicModuleInfo.ModuleName

        InModuleScope $moduleName {
            Mock Test-Path { $false }
            Mock Get-Printer { throw 'Synthetic Get-Printer failure for WhatIf preview' }

            $result = Invoke-BasicPrinterExport `
                -OutputDirectory (Join-Path $StorageRoot 'Exports\Printers') `
                -OutputFileNamePrefix 'printers-basic' `
                -Properties @('Name') `
                -WhatIf

            $result | Should -Not -BeNullOrEmpty
            $result.OutputPath | Should -Match 'sysadmin-main\\Exports\\Printers\\printers-basic-'
            $result.OutputPath | Should -Not -Match 'C:\\Temp'
            $result.Status | Should -Be 'Skipped'
            $result.Reason | Should -Be 'GetPrinterUnavailable'
        }
    }

    It 'uses a secured per-user path and unique file name for the full export preview' {
        $moduleName = $script:FullModuleInfo.ModuleName

        InModuleScope $moduleName {
            Mock Test-Path { $false }
            Mock Get-Printer { throw 'Synthetic Get-Printer failure for WhatIf preview' }

            $result = Invoke-FullPrinterExport `
                -OutputDirectory (Join-Path $StorageRoot 'Exports\Printers') `
                -OutputFileNamePrefix 'printers-full' `
                -Properties @('Name') `
                -WhatIf

            $result | Should -Not -BeNullOrEmpty
            $result.OutputPath | Should -Match 'sysadmin-main\\Exports\\Printers\\printers-full-'
            $result.OutputPath | Should -Not -Match 'C:\\Temp'
            $result.Status | Should -Be 'Skipped'
            $result.Reason | Should -Be 'GetPrinterUnavailable'
        }
    }

    It 'restricts the export directory in code' {
$BasicContent = Get-Content -LiteralPath (Join-Path (Get-SysadminMainRepoRoot) 'PowerShell Script\Printer\Export.printer.list.BASIC.ps1') -Raw
$FullContent = Get-Content -LiteralPath (Join-Path (Get-SysadminMainRepoRoot) 'PowerShell Script\Printer\Export.printer.list.FULL.ps1') -Raw

        $BasicContent | Should -Match 'Resolve-SecureDirectory'
        $BasicContent | Should -Match 'Set-RestrictedDirectoryAcl'
        $FullContent | Should -Match 'Resolve-SecureDirectory'
        $FullContent | Should -Match 'Set-RestrictedDirectoryAcl'
    }

    It 'does not rewrite ACLs when the export directory already exists' {
        $moduleName = $script:BasicModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($storageRoot, $outputDirectory)

            $storageRootItem = [System.IO.DirectoryInfo]::new($storageRoot)
            $outputDirectoryItem = [System.IO.DirectoryInfo]::new($outputDirectory)

            Mock Test-Path {
                if ($LiteralPath -eq $storageRoot -or $LiteralPath -eq $outputDirectory) {
                    return $true
                }

                return $false
            }
            Mock Get-Item {
                if ($LiteralPath -eq $storageRoot) {
                    return $storageRootItem
                }

                return $outputDirectoryItem
            }
            Mock Test-IsReparsePoint { $false }
            Mock New-Item {}
            Mock Set-RestrictedDirectoryAcl {}

            $resolvedPath = Resolve-SecureDirectory -Path $outputDirectory -AllowedRoots @($storageRoot)

            $resolvedPath | Should -Be $outputDirectory
            Assert-MockCalled New-Item -Times 0 -Exactly -Scope It
            Assert-MockCalled Set-RestrictedDirectoryAcl -Times 0 -Exactly -Scope It
        } -Parameters @{
            storageRoot     = 'C:\Users\Test\AppData\Local\sysadmin-main'
            outputDirectory = 'C:\Users\Test\AppData\Local\sysadmin-main\Exports\Printers'
        }
    }

    It 'hardens a newly created export directory once' {
        $moduleName = $script:BasicModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($storageRoot, $outputDirectory)

            $storageRootItem = [System.IO.DirectoryInfo]::new($storageRoot)

            Mock Test-Path {
                if ($LiteralPath -eq $storageRoot) {
                    return $true
                }

                return $false
            }
            Mock Get-Item { $storageRootItem } -ParameterFilter { $LiteralPath -eq $storageRoot }
            Mock Test-IsReparsePoint { $false }
            Mock New-Item { [pscustomobject]@{ FullName = $Path } }
            Mock Set-RestrictedDirectoryAcl {}

            $resolvedPath = Resolve-SecureDirectory -Path $outputDirectory -AllowedRoots @($storageRoot)

            $resolvedPath | Should -Be $outputDirectory
            Assert-MockCalled New-Item -Times 1 -Exactly -Scope It -ParameterFilter {
                $ItemType -eq 'Directory' -and $Path -eq $outputDirectory -and $Force
            }
            Assert-MockCalled Set-RestrictedDirectoryAcl -Times 1 -Exactly -Scope It -ParameterFilter {
                $Path -eq $outputDirectory
            }
        } -Parameters @{
            storageRoot     = 'C:\Users\Test\AppData\Local\sysadmin-main'
            outputDirectory = 'C:\Users\Test\AppData\Local\sysadmin-main\Exports\Printers'
        }
    }
}
