. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'V5 standalone Adobe Acrobat refresh launch behavior' {

    BeforeAll {
        . (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path
$script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'PowerShell Script\Adobe\Install.AdobeAcrobat.Clean.Standalone.ps1'
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'keeps an explicit package path when one is supplied' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            param($scriptDirectory)

            $result = Resolve-StandaloneAdobePackagePath `
                -PackagePath 'C:\Install\Adobe\AcrobatInstaller.msi' `
                -ScriptDirectory $scriptDirectory

            $result | Should -Be 'C:\Install\Adobe\AcrobatInstaller.msi'
        } -Parameters @{
            scriptDirectory = 'C:\Temp'
        }
    }

    It 'defaults to a sibling AcrobatInstaller.msi when no package path is supplied' {
        $moduleName = $script:ModuleInfo.ModuleName
        $tempRoot = Join-Path $env:TEMP ('codex-adobe-standalone-{0}' -f [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $packagePath = Join-Path $tempRoot 'AcrobatInstaller.msi'
        Set-Content -LiteralPath $packagePath -Value 'test package'

        try {
            InModuleScope $moduleName {
                param($scriptDirectory, $expectedPath)

                $result = Resolve-StandaloneAdobePackagePath `
                    -PackagePath '' `
                    -ScriptDirectory $scriptDirectory

                $result | Should -Be $expectedPath
            } -Parameters @{
                scriptDirectory = $tempRoot
                expectedPath    = $packagePath
            }
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws when multiple Adobe installers are found beside the script' {
        $moduleName = $script:ModuleInfo.ModuleName
        $tempRoot = Join-Path $env:TEMP ('codex-adobe-standalone-{0}' -f [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $tempRoot 'Adobe-Reader-1.msi') -Value 'test package'
        Set-Content -LiteralPath (Join-Path $tempRoot 'Adobe-Reader-2.exe') -Value 'test package'

        try {
            InModuleScope $moduleName {
                param($scriptDirectory)

                {
                    Resolve-StandaloneAdobePackagePath `
                        -PackagePath '' `
                        -ScriptDirectory $scriptDirectory
                } | Should -Throw '*Multiple Adobe installer packages were found beside the script*'
            } -Parameters @{
                scriptDirectory = $tempRoot
            }
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
