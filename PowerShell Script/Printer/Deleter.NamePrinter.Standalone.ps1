#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [AllowEmptyString()]
    [string]$NamePattern = ''
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$RequireAdmin = $true
$IsAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$StandalonePlaceholderPattern = '*NAMEPRINTER*'

function Resolve-StandalonePrinterNamePattern {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string]$NamePattern,

        [Parameter(Mandatory = $true)]
        [string]$PlaceholderPattern
    )

    if (-not [string]::IsNullOrWhiteSpace($NamePattern)) {
        return $NamePattern
    }

    if ($WhatIfPreference) {
        return $PlaceholderPattern
    }

    $PromptedPattern = [string](Read-Host 'Enter printer name pattern (wildcards allowed)')
    if ([string]::IsNullOrWhiteSpace($PromptedPattern)) {
        return $PlaceholderPattern
    }

    return $PromptedPattern
}

function Invoke-NamedPrinterRemoval {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$RequireAdmin,

        [Parameter(Mandatory = $true)]
        [bool]$IsAdministrator,

        [Parameter(Mandatory = $true)]
        [string]$NamePattern
    )

    if ($RequireAdmin -and -not $WhatIfPreference -and -not $IsAdministrator) {
        throw 'Run this script in an elevated PowerShell 5.1 session.'
    }

    if ([string]::IsNullOrWhiteSpace($NamePattern) -or $NamePattern -eq $StandalonePlaceholderPattern) {
        return [pscustomobject]@{
            NamePattern  = $NamePattern
            PrinterCount = 0
            RemovedCount = 0
            Status       = 'Skipped'
            Reason       = 'NamePatternNotConfigured'
        }
    }

    try {
        $Printers = @(Get-Printer -ErrorAction Stop | Where-Object { $_.Name -like $NamePattern })
    }
    catch {
        if ($WhatIfPreference) {
            return [pscustomobject]@{
                NamePattern  = $NamePattern
                PrinterCount = 0
                RemovedCount = 0
                Status       = 'Skipped'
                Reason       = 'GetPrinterUnavailable'
            }
        }

        throw
    }

    $RemovedCount = 0
    $Status = 'Completed'

    foreach ($Printer in $Printers) {
        if ($PSCmdlet.ShouldProcess($Printer.Name, 'Remove printer')) {
            Remove-Printer -Name $Printer.Name -Confirm:$false -ErrorAction Stop
            $RemovedCount++
        }
    }

    if ($WhatIfPreference) {
        $Status = 'WhatIf'
    }

    [pscustomobject]@{
        NamePattern  = $NamePattern
        PrinterCount = $Printers.Count
        RemovedCount = $RemovedCount
        Status       = $Status
        Reason       = ''
    }
}

try {
    $ResolvedNamePattern = Resolve-StandalonePrinterNamePattern `
        -NamePattern $NamePattern `
        -PlaceholderPattern $StandalonePlaceholderPattern

    Invoke-NamedPrinterRemoval `
        -RequireAdmin $RequireAdmin `
        -IsAdministrator $IsAdministrator `
        -NamePattern $ResolvedNamePattern
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
