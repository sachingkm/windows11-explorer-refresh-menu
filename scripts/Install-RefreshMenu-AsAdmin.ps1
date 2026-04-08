[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [ValidateSet('x64')]
    [string]$Platform = 'x64'
)

$ErrorActionPreference = 'Stop'

Write-Warning 'Administrative install is no longer the primary path. Running the current-user installer instead.'
& (Join-Path $PSScriptRoot 'Install-RefreshMenu.ps1') -Configuration $Configuration -Platform $Platform
