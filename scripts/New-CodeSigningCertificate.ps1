[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\artifacts\cert'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$config = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\config\PackageConfig.psd1')

if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$pfxPath = Join-Path $OutputDirectory 'Windows11ExplorerRefreshMenu.pfx'
$cerPath = Join-Path $OutputDirectory 'Windows11ExplorerRefreshMenu.cer'
$passwordFile = Join-Path $OutputDirectory 'Windows11ExplorerRefreshMenu.pfx.password.txt'
$friendlyName = $config.DisplayName

if (-not $Force -and (Test-Path $pfxPath) -and (Test-Path $cerPath) -and (Test-Path $passwordFile)) {
    $plainPassword = Get-Content $passwordFile -Raw
    $existingCertificate = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $config.Publisher -and $_.FriendlyName -eq $friendlyName } | Select-Object -First 1
    if ($existingCertificate) {
        return [pscustomobject]@{
            Thumbprint = $existingCertificate.Thumbprint
            PfxPath    = $pfxPath
            CerPath    = $cerPath
            Password   = $plainPassword.Trim()
        }
    }
}

$plainPassword = ([Guid]::NewGuid().ToString('N') + '!LocalDev')
$securePassword = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force

$certificate = New-SelfSignedCertificate `
    -Type Custom `
    -Subject $config.Publisher `
    -FriendlyName $friendlyName `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -HashAlgorithm SHA256 `
    -KeyUsage DigitalSignature `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3') `
    -NotAfter (Get-Date).AddYears(5)

Export-PfxCertificate -Cert $certificate -FilePath $pfxPath -Password $securePassword | Out-Null
Export-Certificate -Cert $certificate -FilePath $cerPath | Out-Null
Set-Content -LiteralPath $passwordFile -Value $plainPassword -NoNewline

[pscustomobject]@{
    Thumbprint = $certificate.Thumbprint
    PfxPath    = $pfxPath
    CerPath    = $cerPath
    Password   = $plainPassword
}

