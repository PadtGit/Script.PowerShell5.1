. (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.ps1')).Path

Describe 'Invoke-PerformanceRegressionCheck' {

    BeforeAll {
        $script:RepoRoot = Get-SysadminMainRepoRoot
        $script:ToolPath = Join-Path $script:RepoRoot 'tools\Invoke-PerformanceRegressionCheck.ps1'
        $script:PowerShellPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    }

    It 'writes a baseline file when invoked with UpdateBaseline' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $testPath = Join-Path $tempRoot 'Fast.Tests.ps1'
            $baselinePath = Join-Path $tempRoot 'baseline.json'
            $jsonPath = Join-Path $tempRoot 'report.json'
            $txtPath = Join-Path $tempRoot 'report.txt'

            Set-Content -LiteralPath $testPath -Encoding UTF8 -Value @'
Describe "Fast suite" {
    It "passes quickly" {
        $true | Should -BeTrue
    }
}
'@

            & $script:PowerShellPath `
                -NoProfile `
                -ExecutionPolicy Bypass `
                -File $script:ToolPath `
                -TestPath $testPath `
                -SampleCount 1 `
                -BaselinePath $baselinePath `
                -OutJsonPath $jsonPath `
                -OutTxtPath $txtPath `
                -UpdateBaseline | Out-Null

            $LASTEXITCODE | Should -Be 0
            Test-Path -LiteralPath $baselinePath | Should -BeTrue

            $baseline = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json
            @($baseline.Suites).Count | Should -Be 1
            $baseline.Suites[0].TestPath | Should -Be $testPath
            [double]$baseline.Suites[0].BaselineMedianSeconds | Should -BeGreaterThan 0
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'fails with exit code 1 when the current timing exceeds the configured regression threshold' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $testPath = Join-Path $tempRoot 'Slow.Tests.ps1'
            $baselinePath = Join-Path $tempRoot 'baseline.json'
            $jsonPath = Join-Path $tempRoot 'report.json'
            $txtPath = Join-Path $tempRoot 'report.txt'

            Set-Content -LiteralPath $testPath -Encoding UTF8 -Value @'
Describe "Slow suite" {
    It "waits long enough to trigger a regression" {
        Start-Sleep -Milliseconds 200
        $true | Should -BeTrue
    }
}
'@

            Set-Content -LiteralPath $baselinePath -Encoding UTF8 -Value @'
{
  "Version": 1,
  "GeneratedAt": "2026-03-28T23:20:00",
  "SampleCount": 1,
  "Suites": [
    {
      "TestPath": "__TEST_PATH__",
      "BaselineMedianSeconds": 0.01,
      "TotalCount": 1,
      "AllowedRegressionPercent": 0
    }
  ]
}
'@.Replace('__TEST_PATH__', $testPath.Replace('\', '\\'))

            & $script:PowerShellPath `
                -NoProfile `
                -ExecutionPolicy Bypass `
                -File $script:ToolPath `
                -TestPath $testPath `
                -SampleCount 1 `
                -BaselinePath $baselinePath `
                -OutJsonPath $jsonPath `
                -OutTxtPath $txtPath `
                -EnableExit | Out-Null

            $LASTEXITCODE | Should -Be 1

            $report = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
            $report.RegressionSuiteCount | Should -Be 1
            $report.Suites[0].Status | Should -Be 'Regression'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'reports missing baseline coverage as a failure when EnableExit is requested' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $testPath = Join-Path $tempRoot 'NoBaseline.Tests.ps1'
            $jsonPath = Join-Path $tempRoot 'report.json'
            $txtPath = Join-Path $tempRoot 'report.txt'

            Set-Content -LiteralPath $testPath -Encoding UTF8 -Value @'
Describe "No baseline suite" {
    It "passes" {
        $true | Should -BeTrue
    }
}
'@

            & $script:PowerShellPath `
                -NoProfile `
                -ExecutionPolicy Bypass `
                -File $script:ToolPath `
                -TestPath $testPath `
                -SampleCount 1 `
                -BaselinePath (Join-Path $tempRoot 'missing.json') `
                -OutJsonPath $jsonPath `
                -OutTxtPath $txtPath `
                -EnableExit | Out-Null

            $LASTEXITCODE | Should -Be 1

            $report = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
            $report.NoBaselineSuiteCount | Should -Be 1
            $report.Suites[0].Status | Should -Be 'NoBaseline'
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'uses the middle sorted duration for odd sample counts instead of the first run' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $tempRoot -Force

        try {
            $testPath = Join-Path $tempRoot 'MedianOdd.Tests.ps1'
            $statePath = Join-Path $tempRoot 'run-count.txt'
            $baselinePath = Join-Path $tempRoot 'baseline.json'
            $jsonPath = Join-Path $tempRoot 'report.json'
            $txtPath = Join-Path $tempRoot 'report.txt'

            Set-Content -LiteralPath $testPath -Encoding UTF8 -Value @"
Describe "Median odd suite" {
    It "slows only the first run" {
        `$statePath = '$($statePath.Replace('\', '\\'))'
        `$runCount = 0
        if (Test-Path -LiteralPath `$statePath) {
            `$runCount = [int](Get-Content -LiteralPath `$statePath -Raw)
        }

        `$runCount++
        Set-Content -LiteralPath `$statePath -Value `$runCount -Encoding UTF8

        if (`$runCount -eq 1) {
            Start-Sleep -Milliseconds 700
        }
        else {
            Start-Sleep -Milliseconds 50
        }

        `$true | Should -BeTrue
    }
}
"@

            Set-Content -LiteralPath $baselinePath -Encoding UTF8 -Value @'
{
  "Version": 1,
  "GeneratedAt": "2026-03-30T00:00:00",
  "SampleCount": 3,
  "Suites": [
    {
      "TestPath": "__TEST_PATH__",
      "BaselineMedianSeconds": 0.3,
      "TotalCount": 1,
      "AllowedRegressionPercent": 100
    }
  ]
}
'@.Replace('__TEST_PATH__', $testPath.Replace('\', '\\'))

            & $script:PowerShellPath `
                -NoProfile `
                -ExecutionPolicy Bypass `
                -File $script:ToolPath `
                -TestPath $testPath `
                -SampleCount 3 `
                -BaselinePath $baselinePath `
                -OutJsonPath $jsonPath `
                -OutTxtPath $txtPath `
                -EnableExit | Out-Null

            $LASTEXITCODE | Should -Be 0

            $report = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
            $report.RegressionSuiteCount | Should -Be 0
            $report.Suites[0].Status | Should -Be 'Passed'
            [double]$report.Suites[0].CurrentMedianSeconds | Should -BeLessThan 0.61
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
