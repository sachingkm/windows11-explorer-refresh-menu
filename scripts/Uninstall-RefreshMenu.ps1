[CmdletBinding()]
param(
    [switch]$AllUsers
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Import-PowerShellDataFile (Join-Path $repoRoot 'config\PackageConfig.psd1')
$installRoot = Join-Path ${env:LOCALAPPDATA} $config.InstallDirectoryName

if ($AllUsers) {
    throw 'All-user uninstall is not supported in the current implementation. Use the default current-user uninstall path.'
}

Get-AppxPackage -Name $config.PackageName -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue
}

if (Test-Path $installRoot) {
    Remove-Item -LiteralPath $installRoot -Recurse -Force
}

$subject = $config.Publisher
$friendlyName = $config.DisplayName

@(
    'Cert:\CurrentUser\My',
    'Cert:\CurrentUser\TrustedPeople',
    'Cert:\CurrentUser\Root'
) | ForEach-Object {
    Get-ChildItem $_ -ErrorAction SilentlyContinue |
        Where-Object { $_.Subject -eq $subject -and $_.FriendlyName -eq $friendlyName } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
