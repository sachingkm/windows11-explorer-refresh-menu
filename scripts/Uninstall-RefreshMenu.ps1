[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Import-PowerShellDataFile (Join-Path $repoRoot 'config\PackageConfig.psd1')
$installRoot = Join-Path ${env:ProgramFiles} $config.InstallDirectoryName

function Assert-Administrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run Uninstall-RefreshMenu.ps1 from an elevated PowerShell session.'
    }
}

Assert-Administrator

Get-AppxPackage -Name $config.PackageName -AllUsers -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}

$provisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $config.PackageName }
if ($provisionedPackage) {
    Remove-AppxProvisionedPackage -Online -PackageName $provisionedPackage.PackageName | Out-Null
}

if (Test-Path $installRoot) {
    Remove-Item -LiteralPath $installRoot -Recurse -Force
}

$subject = $config.Publisher
$friendlyName = $config.DisplayName

@(
    'Cert:\CurrentUser\My',
    'Cert:\LocalMachine\TrustedPeople',
    'Cert:\LocalMachine\Root'
) | ForEach-Object {
    Get-ChildItem $_ -ErrorAction SilentlyContinue |
        Where-Object { $_.Subject -eq $subject -and $_.FriendlyName -eq $friendlyName } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
