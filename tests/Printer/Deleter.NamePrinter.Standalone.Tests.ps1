. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'V5 standalone named printer removal behavior' {

    BeforeAll {
        . (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path
$script:ModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'PowerShell Script\Printer\Deleter.NamePrinter.Standalone.ps1'
    }

    AfterAll {
        if ($null -ne $script:ModuleInfo) {
            Remove-Module -Name $script:ModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns the provided printer name pattern without prompting' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            Mock Read-Host { throw 'Read-Host should not be called when a name pattern is supplied.' }

            $result = Resolve-StandalonePrinterNamePattern `
                -NamePattern '*Office*' `
                -PlaceholderPattern '*NAMEPRINTER*'

            $result | Should -Be '*Office*'
            Assert-MockCalled Read-Host -Times 0 -Exactly -Scope It
        }
    }

    It 'prompts for a name pattern outside WhatIf when no pattern is supplied' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            Mock Read-Host { '*Office*' }

            $result = Resolve-StandalonePrinterNamePattern `
                -NamePattern '' `
                -PlaceholderPattern '*NAMEPRINTER*'

            $result | Should -Be '*Office*'
            Assert-MockCalled Read-Host -Times 1 -Exactly -Scope It
        }
    }

    It 'keeps the safe placeholder during WhatIf when no pattern is supplied' {
        $moduleName = $script:ModuleInfo.ModuleName

        InModuleScope $moduleName {
            Mock Read-Host { throw 'Read-Host should not be called during WhatIf resolution.' }

            $previousWhatIfPreference = $WhatIfPreference
            $WhatIfPreference = $true

            try {
                $result = Resolve-StandalonePrinterNamePattern `
                    -NamePattern '' `
                    -PlaceholderPattern '*NAMEPRINTER*'
            }
            finally {
                $WhatIfPreference = $previousWhatIfPreference
            }

            $result | Should -Be '*NAMEPRINTER*'
            Assert-MockCalled Read-Host -Times 0 -Exactly -Scope It
        }
    }
}
