#Requires -Version 5.1

<#
.SYNOPSIS
    Runs repeatable Pester timing samples and compares them to a committed
    baseline so local workflow runs can catch likely regressions early.

.DESCRIPTION
    Measures one or more Pester suites multiple times, computes median suite
    duration, compares the median against a baseline JSON file, and writes TXT
    plus JSON artifacts under artifacts/validation/.

    Use -UpdateBaseline intentionally when the current timings should become the
    new baseline for future workflow runs.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$TestPath = @(
        'tests\Printer\Restart.Spool.DeletePrinterQSimple.Tests.ps1',
        'tests\Printer\Restart.spool.delete.printerQ.Tests.ps1',
        'tests\Printer\restart.SpoolDeleteQV4.Tests.ps1'
    ),

    [Parameter()]
    [ValidateRange(1, 15)]
    [int]$SampleCount = 3,

    [Parameter()]
    [ValidateRange(0, 500)]
    [double]$AllowedRegressionPercent = 50,

    [Parameter()]
    [string]$BaselinePath = '',

    [Parameter()]
    [string]$OutTxtPath = '',

    [Parameter()]
    [string]$OutJsonPath = '',

    [Parameter()]
    [switch]$UpdateBaseline,

    [Parameter()]
    [switch]$EnableExit
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return (Get-Location).ProviderPath
    }

    return (Split-Path -Path $PSScriptRoot -Parent)
}

function Resolve-OptionalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }

    return (Join-Path -Path $RepoRoot -ChildPath $PathValue)
}

function Convert-ToRelativeRepoPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    $RepoRootWithSeparator = $RepoRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $Candidate = $PathValue

    if ($Candidate.StartsWith($RepoRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Candidate.Substring($RepoRootWithSeparator.Length)
    }

    return $Candidate
}

function Get-MedianValue {
    param(
        [Parameter(Mandatory = $true)]
        [double[]]$Values
    )

    $Sorted = @($Values | Sort-Object)
    if ($Sorted.Count -eq 0) {
        return [double]0
    }

    $MiddleIndex = [int]($Sorted.Count / 2)
    if (($Sorted.Count % 2) -eq 1) {
        return [double]$Sorted[$MiddleIndex]
    }

    return [double](($Sorted[$MiddleIndex - 1] + $Sorted[$MiddleIndex]) / 2)
}

function Import-PesterModule {
    $Module = Get-Module -ListAvailable -Name Pester |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($null -eq $Module) {
        throw 'Pester is required to run performance regression checks.'
    }

    Import-Module -Name $Module.Path -Force -ErrorAction Stop | Out-Null
}

function Invoke-PesterTimingSample {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SuitePath
    )

    $Result = Invoke-Pester -Path $SuitePath -PassThru

    return [pscustomobject]@{
        SuitePath        = $SuitePath
        PassedCount      = $Result.PassedCount
        FailedCount      = $Result.FailedCount
        SkippedCount     = $Result.SkippedCount
        TotalCount       = $Result.TotalCount
        DurationSeconds  = [math]::Round($Result.Duration.TotalSeconds, 3)
    }
}

function Get-BaselineLookup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaselineFilePath
    )

    if (-not (Test-Path -LiteralPath $BaselineFilePath -PathType Leaf)) {
        return @{}
    }

    $RawText = Get-Content -LiteralPath $BaselineFilePath -Raw
    if ([string]::IsNullOrWhiteSpace($RawText)) {
        return @{}
    }

    $BaselineObject = $RawText | ConvertFrom-Json
    $Lookup = @{}

    foreach ($Suite in @($BaselineObject.Suites)) {
        if ($null -eq $Suite -or [string]::IsNullOrWhiteSpace([string]$Suite.TestPath)) {
            continue
        }

        $Lookup[[string]$Suite.TestPath] = $Suite
    }

    return $Lookup
}

function Write-PerformanceArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Report,

        [Parameter(Mandatory = $true)]
        [string]$TxtPath,

        [Parameter(Mandatory = $true)]
        [string]$JsonPath
    )

    foreach ($ArtifactPath in @($TxtPath, $JsonPath)) {
        $Parent = Split-Path -Path $ArtifactPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($Parent) -and
            -not (Test-Path -LiteralPath $Parent -PathType Container)) {
            New-Item -ItemType Directory -Path $Parent -Force | Out-Null
        }
    }

    $Lines = [System.Collections.Generic.List[string]]::new()
    $Lines.Add('Performance Regression Report')
    $Lines.Add(('Generated : {0}' -f $Report.GeneratedAt))
    $Lines.Add(('Baseline  : {0}' -f $Report.BaselinePath))
    $Lines.Add(('Samples   : {0}' -f $Report.SampleCount))
    $Lines.Add(('Regressed : {0}' -f $Report.RegressionSuiteCount))
    $Lines.Add(('Failed    : {0}' -f $Report.FailedSuiteCount))
    $Lines.Add('')
    $Lines.Add('--- Suites ---')

    foreach ($Suite in @($Report.Suites)) {
        $Lines.Add(
            ('{0} :: {1} :: median={2}s :: baseline={3}s :: threshold={4}s :: total={5}' -f
                $Suite.Status,
                $Suite.TestPath,
                $Suite.CurrentMedianSeconds,
                $Suite.BaselineMedianSeconds,
                $Suite.RegressionThresholdSeconds,
                $Suite.TotalCount)
        )
    }

    Set-Content -LiteralPath $TxtPath -Value $Lines -Encoding UTF8
    ($Report | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $JsonPath -Encoding UTF8
}

function Update-BaselineFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaselineFilePath,

        [Parameter(Mandatory = $true)]
        [object[]]$Suites,

        [Parameter(Mandatory = $true)]
        [int]$SampleCountValue,

        [Parameter(Mandatory = $true)]
        [double]$DefaultAllowedRegressionPercent
    )

    $Parent = Split-Path -Path $BaselineFilePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($Parent) -and
        -not (Test-Path -LiteralPath $Parent -PathType Container)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $BaselineSuites = foreach ($Suite in @($Suites)) {
        [pscustomobject]@{
            TestPath                 = $Suite.TestPath
            BaselineMedianSeconds    = $Suite.CurrentMedianSeconds
            TotalCount               = $Suite.TotalCount
            AllowedRegressionPercent = $DefaultAllowedRegressionPercent
        }
    }

    $BaselineObject = [pscustomobject]@{
        Version     = 1
        GeneratedAt = (Get-Date).ToString('s')
        SampleCount = $SampleCountValue
        Suites      = @($BaselineSuites)
    }

    ($BaselineObject | ConvertTo-Json -Depth 6) |
        Set-Content -LiteralPath $BaselineFilePath -Encoding UTF8
}

$RepoRoot = Get-RepoRoot

if ([string]::IsNullOrWhiteSpace($BaselinePath)) {
    $BaselinePath = Join-Path -Path $PSScriptRoot -ChildPath 'performance-baselines\printer-pester-baseline.json'
}
else {
    $BaselinePath = Resolve-OptionalPath -RepoRoot $RepoRoot -PathValue $BaselinePath
}

if ([string]::IsNullOrWhiteSpace($OutTxtPath)) {
    $OutTxtPath = Join-Path -Path $RepoRoot -ChildPath 'artifacts\validation\performance-regression.txt'
}
else {
    $OutTxtPath = Resolve-OptionalPath -RepoRoot $RepoRoot -PathValue $OutTxtPath
}

if ([string]::IsNullOrWhiteSpace($OutJsonPath)) {
    $OutJsonPath = Join-Path -Path $RepoRoot -ChildPath 'artifacts\validation\performance-regression.json'
}
else {
    $OutJsonPath = Resolve-OptionalPath -RepoRoot $RepoRoot -PathValue $OutJsonPath
}

Import-PesterModule

$ResolvedSuites = foreach ($Item in @($TestPath)) {
    $CandidatePath = Resolve-OptionalPath -RepoRoot $RepoRoot -PathValue $Item
    if (-not (Test-Path -LiteralPath $CandidatePath -PathType Leaf)) {
        throw ('Test path not found: {0}' -f $CandidatePath)
    }

    (Resolve-Path -LiteralPath $CandidatePath).Path
}

$BaselineLookup = Get-BaselineLookup -BaselineFilePath $BaselinePath

$SuiteReports = foreach ($SuitePath in @($ResolvedSuites)) {
    $RelativeSuitePath = Convert-ToRelativeRepoPath -RepoRoot $RepoRoot -PathValue $SuitePath
    $SampleResults = @()

    for ($Index = 1; $Index -le $SampleCount; $Index++) {
        $Sample = Invoke-PesterTimingSample -SuitePath $SuitePath
        $SampleResults += [pscustomobject]@{
            Run             = $Index
            DurationSeconds = $Sample.DurationSeconds
            PassedCount     = $Sample.PassedCount
            FailedCount     = $Sample.FailedCount
            SkippedCount    = $Sample.SkippedCount
            TotalCount      = $Sample.TotalCount
        }
    }

    $MedianSeconds = [math]::Round((Get-MedianValue -Values @($SampleResults | ForEach-Object { [double]$_.DurationSeconds })), 3)
    $FailedSampleCount = @($SampleResults | Where-Object { $_.FailedCount -gt 0 }).Count
    $BaselineSuite = $null
    if ($BaselineLookup.ContainsKey($RelativeSuitePath)) {
        $BaselineSuite = $BaselineLookup[$RelativeSuitePath]
    }

    $BaselineMedianSeconds = $null
    $ThresholdPercent = $AllowedRegressionPercent
    if ($null -ne $BaselineSuite) {
        $BaselineMedianSeconds = [double]$BaselineSuite.BaselineMedianSeconds
        if ($null -ne $BaselineSuite.PSObject.Properties['AllowedRegressionPercent']) {
            $ThresholdPercent = [double]$BaselineSuite.AllowedRegressionPercent
        }
    }

    $ThresholdSeconds = $null
    $RegressionPercent = $null
    $Status = 'Passed'

    if ($FailedSampleCount -gt 0) {
        $Status = 'TestFailure'
    }
    elseif ($null -eq $BaselineMedianSeconds) {
        $Status = 'NoBaseline'
    }
    else {
        $ThresholdSeconds = [math]::Round(($BaselineMedianSeconds * (1 + ($ThresholdPercent / 100))), 3)
        if ($BaselineMedianSeconds -gt 0) {
            $RegressionPercent = [math]::Round((($MedianSeconds - $BaselineMedianSeconds) / $BaselineMedianSeconds) * 100, 2)
        }
        else {
            $RegressionPercent = 0
        }

        if ($MedianSeconds -gt $ThresholdSeconds) {
            $Status = 'Regression'
        }
    }

    [pscustomobject]@{
        TestPath                   = $RelativeSuitePath
        CurrentMedianSeconds       = $MedianSeconds
        BaselineMedianSeconds      = $BaselineMedianSeconds
        RegressionThresholdSeconds = $ThresholdSeconds
        AllowedRegressionPercent   = $ThresholdPercent
        RegressionPercent          = $RegressionPercent
        TotalCount                 = $SampleResults[0].TotalCount
        FailedSampleCount          = $FailedSampleCount
        Status                     = $Status
        Samples                    = @($SampleResults)
    }
}

if ($UpdateBaseline) {
    Update-BaselineFile `
        -BaselineFilePath $BaselinePath `
        -Suites @($SuiteReports) `
        -SampleCountValue $SampleCount `
        -DefaultAllowedRegressionPercent $AllowedRegressionPercent

    $BaselineLookup = Get-BaselineLookup -BaselineFilePath $BaselinePath
    foreach ($Suite in @($SuiteReports)) {
        if ($BaselineLookup.ContainsKey($Suite.TestPath)) {
            $Suite.BaselineMedianSeconds = [double]$BaselineLookup[$Suite.TestPath].BaselineMedianSeconds
            $Suite.RegressionThresholdSeconds = [math]::Round(
                ($Suite.BaselineMedianSeconds * (1 + ($Suite.AllowedRegressionPercent / 100))),
                3
            )
            if ($Suite.Status -eq 'NoBaseline') {
                $Suite.Status = 'Passed'
            }
        }
    }
}

$Report = [pscustomobject]@{
    GeneratedAt          = (Get-Date).ToString('s')
    BaselinePath         = $BaselinePath
    SampleCount          = $SampleCount
    RegressionSuiteCount = @($SuiteReports | Where-Object { $_.Status -eq 'Regression' }).Count
    FailedSuiteCount     = @($SuiteReports | Where-Object { $_.Status -eq 'TestFailure' }).Count
    NoBaselineSuiteCount = @($SuiteReports | Where-Object { $_.Status -eq 'NoBaseline' }).Count
    Suites               = @($SuiteReports)
}

Write-PerformanceArtifacts -Report $Report -TxtPath $OutTxtPath -JsonPath $OutJsonPath

if ($EnableExit) {
    if ($Report.FailedSuiteCount -gt 0 -or $Report.RegressionSuiteCount -gt 0 -or $Report.NoBaselineSuiteCount -gt 0) {
        exit 1
    }

    exit 0
}

$Report
