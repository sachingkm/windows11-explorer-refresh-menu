[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [ValidateSet('x64')]
    [string]$Platform = 'x64',

    [switch]$ProvisionForAllUsers = $true
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Import-PowerShellDataFile (Join-Path $repoRoot 'config\PackageConfig.psd1')
$installRoot = Join-Path ${env:ProgramFiles} $config.InstallDirectoryName
$packagePath = Join-Path $repoRoot "artifacts\$Configuration\$Platform\package\Windows11ExplorerRefreshMenu.msix"
$externalSource = Join-Path $repoRoot "artifacts\$Configuration\$Platform\external"
$logDirectory = Join-Path $repoRoot 'artifacts\logs'
$logPath = Join-Path $logDirectory ("install-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))

if (-not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}

Start-Transcript -Path $logPath -Force | Out-Null

function Assert-Administrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run Install-RefreshMenu.ps1 from an elevated PowerShell session.'
    }
}

try {
    Write-Host "Install log: $logPath"
    Assert-Administrator

    $certificate = & (Join-Path $PSScriptRoot 'New-CodeSigningCertificate.ps1')
    $securePassword = ConvertTo-SecureString -String $certificate.Password -AsPlainText -Force

    Import-Certificate -FilePath $certificate.CerPath -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
    Import-Certificate -FilePath $certificate.CerPath -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null

    & (Join-Path $PSScriptRoot 'Build.ps1') -Configuration $Configuration -Platform $Platform -SignArtifacts -PfxPath $certificate.PfxPath -PfxPassword $securePassword

    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    Copy-Item -Path (Join-Path $externalSource '*') -Destination $installRoot -Recurse -Force

    $currentUserPackage = Get-AppxPackage -Name $config.PackageName -ErrorAction SilentlyContinue
    if ($currentUserPackage) {
        Remove-AppxPackage -Package $currentUserPackage.PackageFullName
    }

    $provisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $config.PackageName }
    if ($provisionedPackage) {
        Remove-AppxProvisionedPackage -Online -PackageName $provisionedPackage.PackageName | Out-Null
    }

    if ($ProvisionForAllUsers) {
        Add-AppxProvisionedPackage -Online -PackagePath $packagePath -ExternalLocationPath $installRoot -SkipLicense | Out-Null
    }

    Add-AppxPackage -Path $packagePath -ExternalLocation $installRoot -ForceUpdateFromAnyVersion
}
finally {
    Stop-Transcript | Out-Null
}
