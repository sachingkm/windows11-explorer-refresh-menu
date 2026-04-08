[CmdletBinding()]
param(
    [switch]$RestartExplorer
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Import-PowerShellDataFile (Join-Path $repoRoot 'config\PackageConfig.psd1')
$installRoot = Join-Path ${env:LOCALAPPDATA} $config.InstallDirectoryName

if ($RestartExplorer) {
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Process explorer.exe
    Start-Sleep -Seconds 2
}

$package = Get-AppxPackage -Name $config.PackageName -ErrorAction SilentlyContinue
$recentEvents = Get-WinEvent -LogName 'Microsoft-Windows-AppXDeploymentServer/Operational' -MaxEvents 100 |
    Where-Object { $_.Message -like "*$($config.PackageName)*" } |
    Select-Object -First 5 TimeCreated, Id, LevelDisplayName, Message

[pscustomobject]@{
    PackageInstalled = [bool]$package
    PackageFullName  = $package.PackageFullName
    InstallLocation  = $package.InstallLocation
    ExternalPath     = $installRoot
    DllPresent       = Test-Path (Join-Path $installRoot 'RefreshExplorerCommand.dll')
    ExePresent       = Test-Path (Join-Path $installRoot 'RefreshExplorerHost.exe')
    ExplorerRunning  = [bool](Get-Process explorer -ErrorAction SilentlyContinue)
}

''
'Recent AppX deployment events:'
$recentEvents | Format-List

''
'Manual verification:'
'1. In File Explorer, open a normal local folder.'
'2. Right-click empty folder background and look for Refresh in the compact Windows 11 menu.'
'3. Repeat in the Google Drive-backed folder.'
'4. Confirm the command does not appear when right-clicking a selected file or folder.'
