. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'V5 complete cleanup hardening' {

    BeforeAll {
        try {
            Add-Type -AssemblyName 'System.ServiceProcess' -ErrorAction Stop
        }
        catch {
            Add-Type -AssemblyName 'System.ServiceProcess.ServiceController' -ErrorAction Stop
        }
        $script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'PowerShell Script\windows-maintenance\Nettoyage.Complet.Caches.Windows.ps1'
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'uses trusted cleanup specs and reparse-point guards' {
        $scriptPath = Join-Path (Get-SysadminMainRepoRoot) 'PowerShell Script\windows-maintenance\Nettoyage.Complet.Caches.Windows.ps1'
        $content = Get-Content -LiteralPath $scriptPath -Raw

        $content | Should -Match 'CleanupSpecs'
        $content | Should -Match 'Resolve-TrustedDirectoryPath'
        $content | Should -Match 'Test-IsReparsePoint'
        $content | Should -Not -Match '\$env:TEMP'
    }

    It 'counts only successful removals across update and cache cleanup passes' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($updateCachePath, $cleanupPathOne, $cleanupPathTwo, $systemRoot)

            $service = [pscustomobject]@{
                Status = [System.ServiceProcess.ServiceControllerStatus]::Running
            }
            Add-Member -InputObject $service -MemberType ScriptMethod -Name WaitForStatus -Value {
                param($Status, $Timeout)
            } -Force

            $updateItemFailure = [pscustomobject]@{ FullName = (Join-Path $updateCachePath 'locked.cab') }
            $cleanupItemSuccess = [pscustomobject]@{ FullName = (Join-Path $cleanupPathOne 'ok.tmp') }
            $cleanupItemFailure = [pscustomobject]@{ FullName = (Join-Path $cleanupPathTwo 'locked.tmp') }
            $script:RemovedPaths = @()

            Mock Resolve-TrustedDirectoryPath { $Path }
            Mock Get-Service { $service }
            Mock Stop-Service {}
            Mock Start-Service {}
            Mock Get-SafeChildItems {
                param($Path)

                if ($Path -eq $updateCachePath) { return @($updateItemFailure) }
                if ($Path -eq $cleanupPathOne) { return @($cleanupItemSuccess) }
                if ($Path -eq $cleanupPathTwo) { return @($cleanupItemFailure) }
                @()
            }
            Mock Remove-Item {
                $script:RemovedPaths += $LiteralPath
                if ($LiteralPath -like '*locked*') {
                    throw 'simulated remove failure'
                }
            }
            Mock Clear-RecycleBin {}

            $result = Invoke-WindowsCacheCleanup `
                -RequireAdmin $false `
                -IsAdministrator $true `
                -CleanupSpecs @(
                    @{ Path = $cleanupPathOne; AllowedRoots = @($systemRoot) },
                    @{ Path = $cleanupPathTwo; AllowedRoots = @($systemRoot) }
                ) `
                -UpdateServiceName 'wuauserv' `
                -UpdateCachePath $updateCachePath `
                -ServiceTimeoutSeconds 30 `
                -FlushDns $false `
                -ClearRecycleBin $false `
                -IpConfigPath 'C:\Windows\System32\ipconfig.exe'

            $result.CleanupPathCount | Should -Be 2
            $result.RemovedCount | Should -Be 1
            $result.FlushDns | Should -BeFalse
            $result.ClearRecycleBin | Should -BeFalse
            $result.Status | Should -Be 'Completed'

            $script:RemovedPaths.Count | Should -Be 3
            Assert-MockCalled Stop-Service -Times 1 -Exactly -Scope It
            Assert-MockCalled Start-Service -Times 1 -Exactly -Scope It
        } -Parameters @{
            updateCachePath = 'C:\Windows\SoftwareDistribution\Download'
            cleanupPathOne  = 'C:\Windows\Temp'
            cleanupPathTwo  = 'C:\Users\Bob\AppData\Local\Temp'
            systemRoot      = 'C:\Windows'
        }
    }
}
