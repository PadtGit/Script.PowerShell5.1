#Requires -Version 5.1

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Path $PSScriptRoot -Parent

if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
    throw ('Repo root not found for sandbox shell helper: {0}' -f $RepoRoot)
}

Set-Location -LiteralPath $RepoRoot
