. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'Invoke-PrinterExportPerformanceCheck helper' {

    BeforeAll {
        $script:RepoRoot = Get-SysadminMainRepoRoot
        $script:ToolModuleInfo = Import-ScriptModuleForTest -RelativeScriptPath 'tools\Invoke-PrinterExportPerformanceCheck.ps1'
    }

    AfterAll {
        if ($null -ne $script:ToolModuleInfo) {
            Remove-Module -Name $script:ToolModuleInfo.ModuleName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'reads the committed export performance baseline' {
        InModuleScope $script:ToolModuleInfo.ModuleName {
            $baselinePath = Join-Path $env:SYSADMIN_MAIN_REPO_ROOT 'tools\performance-baselines\printer-export-security.json'
            $baseline = Read-PerformanceBaseline -Path $baselinePath

            $baseline.SuitePath | Should -Be 'tests\Printer\Export.printer.list.Security.Tests.ps1'
            $baseline.MedianSeconds | Should -Be 3.4814
            $baseline.AllowedRegressionPercent | Should -Be 25.0
            $baseline.SourceCommit | Should -Be 'c0ec30541ac2bd4648e49bf40380d5894d76734a'
        }
    }

    It 'computes medians for odd and even duration lists' {
        InModuleScope $script:ToolModuleInfo.ModuleName {
            (Get-MedianSeconds -Values @(4.0, 1.0, 9.0)) | Should -Be 4.0
            (Get-MedianSeconds -Values @(8.0, 2.0, 6.0, 4.0)) | Should -Be 5.0
        }
    }

    It 'writes an advisory regression report when the median exceeds the baseline threshold' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $suitePath = Join-Path $tempRoot 'Export.printer.list.Security.Tests.ps1'
            $baselinePath = Join-Path $tempRoot 'baseline.json'
            $txtPath = Join-Path $tempRoot 'printer-export-performance.txt'
            $jsonPath = Join-Path $tempRoot 'printer-export-performance.json'

            Set-Content -LiteralPath $suitePath -Encoding UTF8 -Value "Describe 'synthetic export perf suite' { It 'passes' { \$true | Should -Be \$true } }"
            Set-Content -LiteralPath $baselinePath -Encoding UTF8 -Value @'
{
  "SuitePath": "tests\\Printer\\Export.printer.list.Security.Tests.ps1",
  "MedianSeconds": 4.0,
  "AllowedRegressionPercent": 10.0,
  "SourceCommit": "deadbeef",
  "Notes": "synthetic baseline"
}
'@

            InModuleScope $script:ToolModuleInfo.ModuleName {
                param($suitePath, $baselinePath, $txtPath, $jsonPath)

                $script:measurementIndex = 0
                Mock Invoke-PesterSuiteMeasurement {
                    $script:measurementIndex++
                    switch ($script:measurementIndex) {
                        1 { return [pscustomobject]@{ DurationSeconds = 5.0; PassedCount = 5; FailedCount = 0; SkippedCount = 0 } }
                        2 { return [pscustomobject]@{ DurationSeconds = 6.0; PassedCount = 5; FailedCount = 0; SkippedCount = 0 } }
                        default { return [pscustomobject]@{ DurationSeconds = 7.0; PassedCount = 5; FailedCount = 0; SkippedCount = 0 } }
                    }
                }

                $result = Invoke-PrinterExportPerformanceCheck `
                    -TargetSuitePath $suitePath `
                    -TargetBaselinePath $baselinePath `
                    -MeasurementRunCount 3 `
                    -RegressionPercentOverride -1 `
                    -TxtPath $txtPath `
                    -JsonPath $jsonPath

                $result.Status | Should -Be 'AdvisoryRegressionDetected'
                $result.RegressionDetected | Should -BeTrue
                $result.MedianSeconds | Should -Be 6.0
                $result.DeltaPercent | Should -Be 50.0
                Test-Path -LiteralPath $txtPath | Should -BeTrue
                Test-Path -LiteralPath $jsonPath | Should -BeTrue

                $jsonResult = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
                $jsonResult.Status | Should -Be 'AdvisoryRegressionDetected'
                @($jsonResult.RunDurationsSeconds).Count | Should -Be 3

                $txtContent = Get-Content -LiteralPath $txtPath -Raw
                $txtContent | Should -Match 'AdvisoryRegressionDetected'
                $txtContent | Should -Match '6\.0000s'
            } -Parameters @{
                suitePath = $suitePath
                baselinePath = $baselinePath
                txtPath = $txtPath
                jsonPath = $jsonPath
            }
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'marks the result as within baseline when the median stays under the threshold' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $suitePath = Join-Path $tempRoot 'Export.printer.list.Security.Tests.ps1'
            $baselinePath = Join-Path $tempRoot 'baseline.json'
            $txtPath = Join-Path $tempRoot 'printer-export-performance.txt'
            $jsonPath = Join-Path $tempRoot 'printer-export-performance.json'

            Set-Content -LiteralPath $suitePath -Encoding UTF8 -Value "Describe 'synthetic export perf suite' { It 'passes' { \$true | Should -Be \$true } }"
            Set-Content -LiteralPath $baselinePath -Encoding UTF8 -Value @'
{
  "SuitePath": "tests\\Printer\\Export.printer.list.Security.Tests.ps1",
  "MedianSeconds": 4.0,
  "AllowedRegressionPercent": 25.0,
  "SourceCommit": "deadbeef",
  "Notes": "synthetic baseline"
}
'@

            InModuleScope $script:ToolModuleInfo.ModuleName {
                param($suitePath, $baselinePath, $txtPath, $jsonPath)

                $script:measurementIndex = 0
                Mock Invoke-PesterSuiteMeasurement {
                    $script:measurementIndex++
                    switch ($script:measurementIndex) {
                        1 { return [pscustomobject]@{ DurationSeconds = 3.8; PassedCount = 5; FailedCount = 0; SkippedCount = 0 } }
                        2 { return [pscustomobject]@{ DurationSeconds = 4.1; PassedCount = 5; FailedCount = 0; SkippedCount = 0 } }
                        default { return [pscustomobject]@{ DurationSeconds = 4.0; PassedCount = 5; FailedCount = 0; SkippedCount = 0 } }
                    }
                }

                $result = Invoke-PrinterExportPerformanceCheck `
                    -TargetSuitePath $suitePath `
                    -TargetBaselinePath $baselinePath `
                    -MeasurementRunCount 3 `
                    -RegressionPercentOverride -1 `
                    -TxtPath $txtPath `
                    -JsonPath $jsonPath

                $result.Status | Should -Be 'WithinBaseline'
                $result.RegressionDetected | Should -BeFalse
                $result.MedianSeconds | Should -Be 4.0
                $result.DeltaPercent | Should -Be 0.0
            } -Parameters @{
                suitePath = $suitePath
                baselinePath = $baselinePath
                txtPath = $txtPath
                jsonPath = $jsonPath
            }
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
