# Recovery

This is the exact manual recovery path that produced the working `Refresh` menu and still worked after reboot on April 8, 2026.

Use this if the menu disappears and the one-shot installer script is not reliable.

## 1. Build the binaries

Open a normal PowerShell window:

```powershell
Set-Location -LiteralPath 'C:\Users\sachi\My Drive\Codex\Desktop\windows11-explorer-refresh-menu'
Set-ExecutionPolicy -Scope Process Bypass -Force

.\scripts\Build.ps1 -Configuration Release -Platform x64
```

## 2. Generate the signing certificate and sign the artifacts

Still in the normal PowerShell window:

```powershell
$cert = .\scripts\New-CodeSigningCertificate.ps1
$pwd = Get-Content '.\artifacts\cert\Windows11ExplorerRefreshMenu.pfx.password.txt' -Raw
$signtool = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe'

& $signtool sign /fd SHA256 /f '.\artifacts\cert\Windows11ExplorerRefreshMenu.pfx' /p $pwd '.\artifacts\Release\x64\external\RefreshExplorerCommand.dll'
& $signtool sign /fd SHA256 /f '.\artifacts\cert\Windows11ExplorerRefreshMenu.pfx' /p $pwd '.\artifacts\Release\x64\external\RefreshExplorerHost.exe'
& $signtool sign /fd SHA256 /f '.\artifacts\cert\Windows11ExplorerRefreshMenu.pfx' /p $pwd '.\artifacts\Release\x64\package\Windows11ExplorerRefreshMenu.msix'
```

Each command should report `Successfully signed`.

## 3. Trust the certificate and install the package

Open PowerShell as Administrator and run:

```powershell
Set-Location -LiteralPath 'C:\Users\sachi\My Drive\Codex\Desktop\windows11-explorer-refresh-menu'
Set-ExecutionPolicy -Scope Process Bypass -Force

$cer = '.\artifacts\cert\Windows11ExplorerRefreshMenu.cer'
$config = Import-PowerShellDataFile .\config\PackageConfig.psd1
$dst = Join-Path $env:LOCALAPPDATA $config.InstallDirectoryName

Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' | Out-Null
Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\CurrentUser\Root' | Out-Null

New-Item -ItemType Directory -Path $dst -Force | Out-Null
Copy-Item -Path '.\artifacts\Release\x64\external\*' -Destination $dst -Recurse -Force

Get-AppxPackage -Name $config.PackageName -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-AppxPackage -Package $_.PackageFullName
}

Add-AppxPackage -Path '.\artifacts\Release\x64\package\Windows11ExplorerRefreshMenu.msix' -ExternalLocation $dst -ForceUpdateFromAnyVersion

Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process explorer.exe
```

## 4. Verify

Check in File Explorer:

1. Open a normal local folder.
2. Right-click empty background.
3. Confirm `Refresh` appears in the main Windows 11 context menu.
4. Repeat in the Google Drive folder.
5. Reboot and check again.

## Notes

- The final working install used the manual sign-and-install flow above.
- If `signtool.exe` is not found, check the installed Windows SDK version under `C:\Program Files (x86)\Windows Kits\10\bin\`.
- The extension installs for the current user, with the external files copied to `%LOCALAPPDATA%\Windows11ExplorerRefreshMenu`.
