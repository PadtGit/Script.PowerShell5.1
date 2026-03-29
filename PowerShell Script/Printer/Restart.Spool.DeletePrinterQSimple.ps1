#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$RequireAdmin = $true
$IsAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$ServiceName = 'Spooler'
$SpoolDirectory = Join-Path -Path $env:SystemRoot -ChildPath 'System32\spool\PRINTERS'
$SpoolAllowedRoots = @(Join-Path -Path $env:SystemRoot -ChildPath 'System32\spool')
$AllowedExtensions = @('.spl', '.shd')

function Test-PathWithinAllowedRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedRoots
    )

    $NormalizedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    foreach ($AllowedRoot in $AllowedRoots) {
        if ([string]::IsNullOrWhiteSpace($AllowedRoot)) {
            continue
        }

        $NormalizedRoot = [System.IO.Path]::GetFullPath($AllowedRoot).TrimEnd('\')
        if ($NormalizedPath.Equals($NormalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }

        if ($NormalizedPath.StartsWith(($NormalizedRoot + '\'), [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Test-IsReparsePoint {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileSystemInfo]$Item
    )

    return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Resolve-TrustedDirectoryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedRoots
    )

    $NormalizedPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-PathWithinAllowedRoot -Path $NormalizedPath -AllowedRoots $AllowedRoots)) {
        throw ('Directory path is outside the trusted root: {0}' -f $NormalizedPath)
    }

    foreach ($AllowedRoot in $AllowedRoots) {
        if ([string]::IsNullOrWhiteSpace($AllowedRoot) -or -not (Test-Path -LiteralPath $AllowedRoot -PathType Container)) {
            continue
        }

        $AllowedRootItem = Get-Item -LiteralPath $AllowedRoot -Force -ErrorAction Stop
        if (Test-IsReparsePoint -Item $AllowedRootItem) {
            throw ('Trusted root must not be a reparse point: {0}' -f $AllowedRootItem.FullName)
        }
    }

    if (-not (Test-Path -LiteralPath $NormalizedPath -PathType Container)) {
        throw ('Directory path not found: {0}' -f $NormalizedPath)
    }

    $DirectoryItem = Get-Item -LiteralPath $NormalizedPath -Force -ErrorAction Stop
    if (Test-IsReparsePoint -Item $DirectoryItem) {
        throw ('Directory path must not be a reparse point: {0}' -f $DirectoryItem.FullName)
    }

    return $DirectoryItem.FullName
}

function Invoke-SimplePrintQueueCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$RequireAdmin,

        [Parameter(Mandatory = $true)]
        [bool]$IsAdministrator,

        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [string]$SpoolDirectory,

        [Parameter(Mandatory = $true)]
        [string[]]$SpoolAllowedRoots,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedExtensions
    )

    if ($RequireAdmin -and -not $WhatIfPreference -and -not $IsAdministrator) {
        throw 'Run this script in an elevated PowerShell 5.1 session.'
    }

    $TrustedSpoolDirectory = Resolve-TrustedDirectoryPath -Path $SpoolDirectory -AllowedRoots $SpoolAllowedRoots
    $Service = Get-Service -Name $ServiceName -ErrorAction Stop
    $ServiceWasRunning = $Service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running
    $ServiceWasStopped = $false
    $DeletedCount = 0
    $Status = 'Completed'

    if ($ServiceWasRunning -and $PSCmdlet.ShouldProcess($ServiceName, 'Stop service')) {
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
        $ServiceWasStopped = $true
    }

    try {
        $Files = @(
            Get-ChildItem -LiteralPath $TrustedSpoolDirectory -File -ErrorAction SilentlyContinue |
                Where-Object {
                    $AllowedExtensions -contains $_.Extension.ToLowerInvariant() -and
                    -not (Test-IsReparsePoint -Item $_)
                }
        )

        foreach ($File in $Files) {
            if ($PSCmdlet.ShouldProcess($File.FullName, 'Remove spool file')) {
                Remove-Item -LiteralPath $File.FullName -Force -ErrorAction Stop
                $DeletedCount++
            }
        }
    }
    finally {
        if ($ServiceWasStopped -and $PSCmdlet.ShouldProcess($ServiceName, 'Start service')) {
            Start-Service -Name $ServiceName -ErrorAction Stop
        }
    }

    if ($WhatIfPreference) {
        $Status = 'WhatIf'
    }

    [pscustomobject]@{
        ServiceName  = $ServiceName
        QueuePath    = $TrustedSpoolDirectory
        FileCount    = $Files.Count
        DeletedCount = $DeletedCount
        Status       = $Status
    }
}

try {
    Invoke-SimplePrintQueueCleanup `
        -RequireAdmin $RequireAdmin `
        -IsAdministrator $IsAdministrator `
        -ServiceName $ServiceName `
        -SpoolDirectory $SpoolDirectory `
        -SpoolAllowedRoots $SpoolAllowedRoots `
        -AllowedExtensions $AllowedExtensions
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
