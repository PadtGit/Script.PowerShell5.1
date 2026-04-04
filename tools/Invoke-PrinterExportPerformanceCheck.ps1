#Requires -Version 5.1

<#
.SYNOPSIS
    Measures the printer export security Pester suite and compares the median
    duration against a committed baseline.

.DESCRIPTION
    Runs the target Pester suite multiple times, records per-run durations,
    computes the median duration, compares that median against a committed
    baseline, and writes TXT and JSON advisory artifacts under
    artifacts/validation by default.

    The default mode reports drift without failing the run. Use
    -EnableExit -FailOnRegression to promote the advisory signal into a
    non-zero exit code once the baseline is stable enough for enforcement.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SuitePath = '',

    [Parameter()]
    [string]$BaselinePath = '',

    [Parameter()]
    [ValidateRange(1, 99)]
    [int]$RunCount = 5,

    [Parameter()]
    [double]$AllowedRegressionPercent = -1,

    [Parameter()]
    [string]$OutTxtPath = '',

    [Parameter()]
    [string]$OutJsonPath = '',

    [Parameter()]
    [switch]$EnableExit,

    [Parameter()]
    [switch]$FailOnRegression
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $ScriptRoot = $PWD.Path
}
else {
    $ScriptRoot = $PSScriptRoot
}

$RepoRoot = Split-Path -Path $ScriptRoot -Parent

function Ensure-ParentDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $parentPath = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parentPath) -and
        -not (Test-Path -LiteralPath $parentPath -PathType Container)) {
        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }
}

function Resolve-PerformanceCheckPathDefaults {
    param(
        [string]$RequestedSuitePath,
        [string]$RequestedBaselinePath,
        [string]$RequestedTxtPath,
        [string]$RequestedJsonPath
    )

    $effectiveSuitePath = $RequestedSuitePath
    if ([string]::IsNullOrWhiteSpace($effectiveSuitePath)) {
        $effectiveSuitePath = Join-Path -Path $RepoRoot -ChildPath 'tests\Printer\Export.printer.list.Security.Tests.ps1'
    }

    $effectiveBaselinePath = $RequestedBaselinePath
    if ([string]::IsNullOrWhiteSpace($effectiveBaselinePath)) {
        $effectiveBaselinePath = Join-Path -Path $ScriptRoot -ChildPath 'performance-baselines\printer-export-security.json'
    }

    $effectiveTxtPath = $RequestedTxtPath
    if ([string]::IsNullOrWhiteSpace($effectiveTxtPath)) {
        $effectiveTxtPath = Join-Path -Path $RepoRoot -ChildPath 'artifacts\validation\printer-export-performance.txt'
    }

    $effectiveJsonPath = $RequestedJsonPath
    if ([string]::IsNullOrWhiteSpace($effectiveJsonPath)) {
        $effectiveJsonPath = Join-Path -Path $RepoRoot -ChildPath 'artifacts\validation\printer-export-performance.json'
    }

    return [pscustomobject]@{
        SuitePath    = $effectiveSuitePath
        BaselinePath = $effectiveBaselinePath
        OutTxtPath   = $effectiveTxtPath
        OutJsonPath  = $effectiveJsonPath
    }
}

function Get-MedianSeconds {
    param(
        [Parameter(Mandatory = $true)]
        [double[]]$Values
    )

    if ($null -eq $Values -or $Values.Count -eq 0) {
        return $null
    }

    $sortedValues = @($Values | Sort-Object)
    $midpoint = [int][math]::Floor($sortedValues.Count / 2)

    if (($sortedValues.Count % 2) -eq 1) {
        return [double]$sortedValues[$midpoint]
    }

    return [double](($sortedValues[$midpoint - 1] + $sortedValues[$midpoint]) / 2.0)
}

function Read-PerformanceBaseline {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Baseline file not found: $Path"
    }

    $baseline = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($null -eq $baseline) {
        throw "Baseline file is empty: $Path"
    }

    if ($null -eq $baseline.SuitePath -or [string]::IsNullOrWhiteSpace([string]$baseline.SuitePath)) {
        throw "Baseline file missing SuitePath: $Path"
    }

    if ($null -eq $baseline.MedianSeconds) {
        throw "Baseline file missing MedianSeconds: $Path"
    }

    if ($null -eq $baseline.AllowedRegressionPercent) {
        throw "Baseline file missing AllowedRegressionPercent: $Path"
    }

    return [pscustomobject]@{
        SuitePath                = [string]$baseline.SuitePath
        MedianSeconds            = [double]$baseline.MedianSeconds
        AllowedRegressionPercent = [double]$baseline.AllowedRegressionPercent
        SourceCommit             = [string]$baseline.SourceCommit
        Notes                    = [string]$baseline.Notes
    }
}

function Invoke-PesterSuiteMeasurement {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $configuration = New-PesterConfiguration
    $configuration.Run.Path = $Path
    $configuration.Output.Verbosity = 'None'
    $configuration.Run.PassThru = $true

    $result = Invoke-Pester -Configuration $configuration
    $container = @($result.Containers) | Select-Object -First 1
    if ($null -eq $container) {
        return [pscustomobject]@{
            DurationSeconds = $null
            PassedCount     = 0
            FailedCount     = 0
            SkippedCount    = 0
        }
    }

    return [pscustomobject]@{
        DurationSeconds = [double]$container.Duration.TotalSeconds
        PassedCount     = [int]$container.PassedCount
        FailedCount     = [int]$container.FailedCount
        SkippedCount    = [int]$container.SkippedCount
    }
}

function Write-PerformanceArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Result,

        [Parameter(Mandatory = $true)]
        [string]$TxtPath,

        [Parameter(Mandatory = $true)]
        [string]$JsonPath
    )

    Ensure-ParentDirectory -Path $TxtPath
    Ensure-ParentDirectory -Path $JsonPath

    $reportLines = [System.Collections.Generic.List[string]]::new()
    $reportLines.Add('Printer Export Performance Check')
    $reportLines.Add(('Generated : {0}' -f $Result.GeneratedAt))
    $reportLines.Add(('Suite     : {0}' -f $Result.SuitePath))
    $reportLines.Add(('Status    : {0}' -f $Result.Status))
    $reportLines.Add(('Runs      : {0}' -f $Result.RunCount))
    if ($null -ne $Result.BaselineMedianSeconds) {
        $reportLines.Add(('Baseline  : {0:N4}s' -f $Result.BaselineMedianSeconds))
    }
    else {
        $reportLines.Add('Baseline  : No measurements found')
    }
    if ($null -ne $Result.MedianSeconds) {
        $reportLines.Add(('Median    : {0:N4}s' -f $Result.MedianSeconds))
        $reportLines.Add(('Delta     : {0:+0.0000;-0.0000;0.0000}s ({1:+0.00;-0.00;0.00}%)' -f $Result.DeltaSeconds, $Result.DeltaPercent))
    }
    else {
        $reportLines.Add('Median    : No measurements found')
    }
    $reportLines.Add(('Threshold : {0:N2}%' -f $Result.AllowedRegressionPercent))
    $reportLines.Add(('Regression: {0}' -f $Result.RegressionDetected))
    $reportLines.Add('')
    $reportLines.Add('Run durations (seconds):')
    if (@($Result.RunDurationsSeconds).Count -gt 0) {
        foreach ($duration in @($Result.RunDurationsSeconds)) {
            $reportLines.Add(('  - {0:N4}' -f [double]$duration))
        }
    }
    else {
        $reportLines.Add('  - No measurements found')
    }

    Set-Content -LiteralPath $TxtPath -Value $reportLines -Encoding UTF8
    ($Result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $JsonPath -Encoding UTF8
}

function Invoke-PrinterExportPerformanceCheck {
    param(
        [Parameter()]
        [string]$TargetSuitePath,

        [Parameter()]
        [string]$TargetBaselinePath,

        [Parameter(Mandatory = $true)]
        [int]$MeasurementRunCount,

        [Parameter(Mandatory = $true)]
        [double]$RegressionPercentOverride,

        [Parameter()]
        [string]$TxtPath,

        [Parameter()]
        [string]$JsonPath
    )

    $pathDefaults = Resolve-PerformanceCheckPathDefaults `
        -RequestedSuitePath $TargetSuitePath `
        -RequestedBaselinePath $TargetBaselinePath `
        -RequestedTxtPath $TxtPath `
        -RequestedJsonPath $JsonPath

    if (-not (Test-Path -LiteralPath $pathDefaults.SuitePath -PathType Leaf)) {
        throw "Suite file not found: $($pathDefaults.SuitePath)"
    }

    $baseline = Read-PerformanceBaseline -Path $pathDefaults.BaselinePath
    $effectiveAllowedRegressionPercent = $baseline.AllowedRegressionPercent
    if ($RegressionPercentOverride -ge 0) {
        $effectiveAllowedRegressionPercent = [double]$RegressionPercentOverride
    }

    $measurements = [System.Collections.Generic.List[object]]::new()
    $runDurationsSeconds = [System.Collections.Generic.List[double]]::new()
    $hasFailedRuns = $false

    for ($runIndex = 1; $runIndex -le $MeasurementRunCount; $runIndex++) {
        $measurement = Invoke-PesterSuiteMeasurement -Path $pathDefaults.SuitePath
        $measurements.Add([pscustomobject]@{
            RunNumber        = $runIndex
            DurationSeconds  = if ($null -ne $measurement.DurationSeconds) { [double]$measurement.DurationSeconds } else { $null }
            PassedCount      = [int]$measurement.PassedCount
            FailedCount      = [int]$measurement.FailedCount
            SkippedCount     = [int]$measurement.SkippedCount
        })

        if ($measurement.FailedCount -gt 0) {
            $hasFailedRuns = $true
        }

        if ($null -ne $measurement.DurationSeconds) {
            $runDurationsSeconds.Add([double]$measurement.DurationSeconds)
        }
    }

    $medianSeconds = Get-MedianSeconds -Values @($runDurationsSeconds.ToArray())
    $baselineMedianSeconds = [double]$baseline.MedianSeconds
    $deltaSeconds = $null
    $deltaPercent = $null
    $regressionDetected = $false
    $status = 'No measurements found'

    if ($hasFailedRuns) {
        $status = 'SuiteFailed'
    }
    elseif ($null -ne $medianSeconds) {
        $deltaSeconds = [double]($medianSeconds - $baselineMedianSeconds)
        if ($baselineMedianSeconds -ne 0) {
            $deltaPercent = [double](($deltaSeconds / $baselineMedianSeconds) * 100.0)
        }
        else {
            $deltaPercent = 0.0
        }

        $regressionDetected = ($deltaPercent -gt $effectiveAllowedRegressionPercent)
        if ($regressionDetected) {
            $status = 'AdvisoryRegressionDetected'
        }
        else {
            $status = 'WithinBaseline'
        }
    }

    $result = [pscustomobject]@{
        GeneratedAt              = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        SuitePath                = $pathDefaults.SuitePath
        BaselinePath             = $pathDefaults.BaselinePath
        RunCount                 = $MeasurementRunCount
        RunDurationsSeconds      = @($runDurationsSeconds.ToArray())
        Measurements             = @($measurements.ToArray())
        MedianSeconds            = if ($null -ne $medianSeconds) { [math]::Round($medianSeconds, 4) } else { $null }
        BaselineMedianSeconds    = [math]::Round($baselineMedianSeconds, 4)
        AllowedRegressionPercent = [math]::Round($effectiveAllowedRegressionPercent, 2)
        DeltaSeconds             = if ($null -ne $deltaSeconds) { [math]::Round($deltaSeconds, 4) } else { $null }
        DeltaPercent             = if ($null -ne $deltaPercent) { [math]::Round($deltaPercent, 2) } else { $null }
        RegressionDetected       = $regressionDetected
        Status                   = $status
        SourceCommit             = $baseline.SourceCommit
        Notes                    = $baseline.Notes
        OutTxtPath               = $pathDefaults.OutTxtPath
        OutJsonPath              = $pathDefaults.OutJsonPath
    }

    Write-PerformanceArtifacts -Result $result -TxtPath $pathDefaults.OutTxtPath -JsonPath $pathDefaults.OutJsonPath
    return $result
}

try {
    $result = Invoke-PrinterExportPerformanceCheck `
        -TargetSuitePath $SuitePath `
        -TargetBaselinePath $BaselinePath `
        -MeasurementRunCount $RunCount `
        -RegressionPercentOverride $AllowedRegressionPercent `
        -TxtPath $OutTxtPath `
        -JsonPath $OutJsonPath

    Write-Host ''
    Write-Host ('Printer export performance status: {0}' -f $result.Status) -ForegroundColor Cyan
    if ($null -ne $result.MedianSeconds) {
        Write-Host ('  Median   : {0:N4}s' -f $result.MedianSeconds) -ForegroundColor DarkGray
    }
    else {
        Write-Host '  Median   : No measurements found' -ForegroundColor Yellow
    }
    Write-Host ('  Baseline : {0:N4}s' -f $result.BaselineMedianSeconds) -ForegroundColor DarkGray
    if ($null -ne $result.DeltaSeconds) {
    Write-Host ('  Delta    : {0:+0.0000;-0.0000;0.0000}s ({1:+0.00;-0.00;0.00}%)' -f $result.DeltaSeconds, $result.DeltaPercent) -ForegroundColor DarkGray
    }
    Write-Host ('  TXT      : {0}' -f $result.OutTxtPath) -ForegroundColor DarkGray
    Write-Host ('  JSON     : {0}' -f $result.OutJsonPath) -ForegroundColor DarkGray

    if ($EnableExit) {
        if ($result.Status -eq 'SuiteFailed') {
            exit 1
        }

        if ($FailOnRegression -and $result.RegressionDetected) {
            exit 1
        }

        exit 0
    }

    $result
}
catch {
    Write-Error $_
    if ($EnableExit) {
        exit 1
    }
    throw
}
