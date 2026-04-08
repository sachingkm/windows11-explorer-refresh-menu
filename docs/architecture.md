# Architecture

## Components

- `RefreshExplorerCommand.dll`
  - Implements `IExplorerCommand`.
  - Exposes a single COM class referenced by the sparse package manifest.
  - Launches the helper EXE when the menu item is invoked.
- `RefreshExplorerHost.exe`
  - Runs without a visible console.
  - Waits briefly for the context menu to dismiss.
  - Validates that the foreground top-level window is Explorer.
  - Sends `F5` to trigger a refresh.
- Sparse MSIX package
  - Gives the shell extension package identity.
  - Registers `Directory\Background` and maps the verb to the COM CLSID.
  - Uses `AllowExternalContent` so the DLL and EXE live outside the MSIX.

## Install model

- Package assets stay inside the sparse package.
- The DLL and EXE are copied to `C:\Program Files\Windows11ExplorerRefreshMenu`.
- The sparse package is provisioned for future users and registered for the current user.

