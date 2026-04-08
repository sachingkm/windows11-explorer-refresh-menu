[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [ValidateSet('x64')]
    [string]$Platform = 'x64'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$command = @(
    "Set-ExecutionPolicy -Scope Process Bypass -Force"
    "Set-Location -LiteralPath '$repoRoot'"
    ".\scripts\Install-RefreshMenu.ps1 -Configuration $Configuration -Platform $Platform"
) -join '; '

Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList '-NoProfile', '-Command', $command -Wait
