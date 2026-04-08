[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [ValidateSet('x64')]
    [string]$Platform = 'x64',

    [switch]$ProvisionForAllUsers,

    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Import-PowerShellDataFile (Join-Path $repoRoot 'config\PackageConfig.psd1')
$installRoot = Join-Path ${env:LOCALAPPDATA} $config.InstallDirectoryName
$packagePath = Join-Path $repoRoot "artifacts\$Configuration\$Platform\package\Windows11ExplorerRefreshMenu.msix"
$externalSource = Join-Path $repoRoot "artifacts\$Configuration\$Platform\external"
$logDirectory = Join-Path $repoRoot 'artifacts\logs'
$logPath = Join-Path $logDirectory ("install-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))

if (-not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}

Start-Transcript -Path $logPath -Force | Out-Null

function Test-BuildArtifacts {
    return (Test-Path $packagePath) -and
        (Test-Path (Join-Path $externalSource 'RefreshExplorerCommand.dll')) -and
        (Test-Path (Join-Path $externalSource 'RefreshExplorerHost.exe'))
}

try {
    Write-Host "Install log: $logPath"

    if ($ProvisionForAllUsers) {
        throw 'All-user provisioning is not supported on this Windows edition. Use the default current-user install path.'
    }

    $certificate = & (Join-Path $PSScriptRoot 'New-CodeSigningCertificate.ps1')

    Import-Certificate -FilePath $certificate.CerPath -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' | Out-Null
    Import-Certificate -FilePath $certificate.CerPath -CertStoreLocation 'Cert:\CurrentUser\Root' | Out-Null

    if (-not $SkipBuild) {
        $buildProcess = Start-Process `
            -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
            -ArgumentList @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-File', (Join-Path $PSScriptRoot 'Build.ps1'),
                '-Configuration', $Configuration,
                '-Platform', $Platform,
                '-SignArtifacts',
                '-PfxPath', $certificate.PfxPath,
                '-PfxPasswordFilePath', (Join-Path $repoRoot 'artifacts\cert\Windows11ExplorerRefreshMenu.pfx.password.txt')
            ) `
            -Wait `
            -PassThru

        if ($buildProcess.ExitCode -ne 0) {
            if (Test-BuildArtifacts) {
                Write-Warning "Build.ps1 failed with exit code $($buildProcess.ExitCode). Reusing the existing built artifacts."
            }
            else {
                throw "Build.ps1 failed with exit code $($buildProcess.ExitCode)."
            }
        }
    }

    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    Copy-Item -Path (Join-Path $externalSource '*') -Destination $installRoot -Recurse -Force

    $currentUserPackage = Get-AppxPackage -Name $config.PackageName -ErrorAction SilentlyContinue
    if ($currentUserPackage) {
        Remove-AppxPackage -Package $currentUserPackage.PackageFullName
    }

    Add-AppxPackage -Path $packagePath -ExternalLocation $installRoot -ForceUpdateFromAnyVersion
}
finally {
    Stop-Transcript | Out-Null
}
