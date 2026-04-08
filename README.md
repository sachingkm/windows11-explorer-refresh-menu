# Windows 11 Explorer Refresh Menu

Adds a `Refresh` command to the Windows 11 compact File Explorer context menu for folder background right-clicks by using a packaged `IExplorerCommand` shell extension and a sparse MSIX registration.

## What this repo contains

- `src/RefreshExplorerCommand`: native in-process Explorer command DLL.
- `src/RefreshExplorerHost`: hidden helper EXE that refreshes the active Explorer window.
- `packaging`: sparse-package manifest and MSBuild packaging project.
- `scripts`: build, sign, install, uninstall, and asset-generation scripts.
- `docs`: short architecture notes.

## Requirements

- Windows 11 x64.
- Visual Studio Build Tools 2022 with the C++ workload.
- Windows 11 SDK (`10.0.26100.0` validated on this machine).
- Administrator rights for install/uninstall and certificate trust.

## Build

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\Build.ps1
```

Build output lands under `artifacts\Release\x64\`.

## Install

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\Install-RefreshMenu.ps1
```

## Uninstall

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\Uninstall-RefreshMenu.ps1
```

