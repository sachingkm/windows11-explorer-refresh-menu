[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [ValidateSet('x64')]
    [string]$Platform = 'x64',

    [switch]$SignArtifacts,

    [string]$PfxPath,

    [SecureString]$PfxPassword,

    [string]$PfxPasswordFilePath
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$signTool = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe'
$makeAppx = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\makeappx.exe'
$vsWhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
$cmdExe = 'C:\Windows\System32\cmd.exe'

$pathValue = [Environment]::GetEnvironmentVariable('Path', 'Process')
[Environment]::SetEnvironmentVariable('Path', $pathValue, 'Process')
[Environment]::SetEnvironmentVariable('PATH', $null, 'Process')

$externalRoot = Join-Path $repoRoot "artifacts\$Configuration\$Platform\external"
$packageStageRoot = Join-Path $repoRoot "artifacts\$Configuration\$Platform\package-stage"
$packageRoot = Join-Path $repoRoot "artifacts\$Configuration\$Platform\package"
$commandObjRoot = Join-Path $repoRoot "artifacts\obj\RefreshExplorerCommand\$Configuration\$Platform"
$hostObjRoot = Join-Path $repoRoot "artifacts\obj\RefreshExplorerHost\$Configuration\$Platform"
$packageFile = Join-Path $packageRoot 'Windows11ExplorerRefreshMenu.msix'

function Get-BuildTools {
    $installationPath = & $vsWhere -latest -products * -property installationPath
    if (-not $installationPath) {
        throw 'Visual Studio Build Tools installation not found.'
    }

    $vcVars = Join-Path $installationPath 'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path $vcVars)) {
        throw "vcvars64.bat not found at $vcVars"
    }

    return @{
        DevCmd = $vcVars
    }
}

function Get-PlainTextPassword {
    param([SecureString]$SecurePassword)

    if (-not $SecurePassword) {
        return $null
    }

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

if (-not $PfxPassword -and $PfxPasswordFilePath) {
    if (-not (Test-Path $PfxPasswordFilePath)) {
        throw "PFX password file not found: $PfxPasswordFilePath"
    }

    $PfxPassword = ConvertTo-SecureString -String ((Get-Content $PfxPasswordFilePath -Raw).Trim()) -AsPlainText -Force
}

function Sign-File {
    param(
        [string]$FilePath,
        [string]$CertificatePath,
        [SecureString]$CertificatePassword
    )

    $plainPassword = Get-PlainTextPassword -SecurePassword $CertificatePassword
    & $signTool sign /fd SHA256 /f $CertificatePath /p $plainPassword $FilePath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "SignTool failed for $FilePath"
    }
}

function Invoke-DevCommand {
    param(
        [string]$DevCmd,
        [string]$Command
    )

    $fullCommand = "`"$DevCmd`" && $Command"
    & $cmdExe /c $fullCommand
    if ($LASTEXITCODE -ne 0) {
        throw "Native build command failed: $Command"
    }
}

function Get-CompileFlags {
    if ($Configuration -eq 'Debug') {
        return '/nologo /std:c++17 /permissive- /Zc:__cplusplus /EHsc /MDd /Od /Zi /W4'
    }

    return '/nologo /std:c++17 /permissive- /Zc:__cplusplus /EHsc /MD /O2 /Zi /W4'
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

& (Join-Path $PSScriptRoot 'Generate-Assets.ps1')

$buildTools = Get-BuildTools
$compileFlags = Get-CompileFlags

Ensure-Directory -Path $externalRoot
Ensure-Directory -Path $commandObjRoot
Ensure-Directory -Path $hostObjRoot
Ensure-Directory -Path $packageStageRoot
Ensure-Directory -Path (Join-Path $packageStageRoot 'Assets')
Ensure-Directory -Path $packageRoot

$commandSourceRoot = Join-Path $repoRoot 'src\RefreshExplorerCommand'
$hostSourceRoot = Join-Path $repoRoot 'src\RefreshExplorerHost'
$commandObj1 = Join-Path $commandObjRoot 'RefreshExplorerCommand.obj'
$commandObj2 = Join-Path $commandObjRoot 'dllmain.obj'
$hostObj = Join-Path $hostObjRoot 'main.obj'

$commandCompile = @(
    "cd /d `"$commandSourceRoot`"",
    "cl $compileFlags /c /D_WINDOWS /DWIN32_LEAN_AND_MEAN /DUNICODE /D_UNICODE /Fo`"$commandObj1`" RefreshExplorerCommand.cpp",
    "cl $compileFlags /c /D_WINDOWS /DWIN32_LEAN_AND_MEAN /DUNICODE /D_UNICODE /Fo`"$commandObj2`" dllmain.cpp",
    "link /NOLOGO /DLL /SUBSYSTEM:WINDOWS /OUT:`"$externalRoot\RefreshExplorerCommand.dll`" /IMPLIB:`"$externalRoot\RefreshExplorerCommand.lib`" /PDB:`"$externalRoot\RefreshExplorerCommand.pdb`" /DEF:`"$commandSourceRoot\RefreshExplorerCommand.def`" `"$commandObj1`" `"$commandObj2`" ole32.lib shell32.lib shlwapi.lib pathcch.lib"
) -join ' && '

Invoke-DevCommand -DevCmd $buildTools.DevCmd -Command $commandCompile

$hostCompile = @(
    "cd /d `"$hostSourceRoot`"",
    "cl $compileFlags /c /DWIN32_LEAN_AND_MEAN /DUNICODE /D_UNICODE /Fo`"$hostObj`" /Fd`"$hostObjRoot\vc143.pdb`" main.cpp",
    "link /NOLOGO /SUBSYSTEM:WINDOWS /OUT:`"$externalRoot\RefreshExplorerHost.exe`" /PDB:`"$externalRoot\RefreshExplorerHost.pdb`" /MANIFEST:EMBED /MANIFESTINPUT:`"$hostSourceRoot\RefreshExplorerHost.exe.manifest`" `"$hostObj`" user32.lib shell32.lib"
) -join ' && '

Invoke-DevCommand -DevCmd $buildTools.DevCmd -Command $hostCompile

Copy-Item -LiteralPath (Join-Path $repoRoot 'packaging\AppxManifest.xml') -Destination (Join-Path $packageStageRoot 'AppxManifest.xml') -Force
Copy-Item -Path (Join-Path $repoRoot 'packaging\Assets\*.png') -Destination (Join-Path $packageStageRoot 'Assets') -Force

if (Test-Path $packageFile) {
    Remove-Item -LiteralPath $packageFile -Force
}

& $makeAppx pack /d $packageStageRoot /p $packageFile /nv /o | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "MakeAppx failed for $packageFile"
}

if ($SignArtifacts) {
    if (-not $PfxPath -or -not (Test-Path $PfxPath)) {
        throw 'A valid PFX path is required when -SignArtifacts is used.'
    }

    if (-not $PfxPassword) {
        throw 'A PFX password is required when -SignArtifacts is used.'
    }

    Sign-File -FilePath (Join-Path $externalRoot 'RefreshExplorerCommand.dll') -CertificatePath $PfxPath -CertificatePassword $PfxPassword
    Sign-File -FilePath (Join-Path $externalRoot 'RefreshExplorerHost.exe') -CertificatePath $PfxPath -CertificatePassword $PfxPassword
    Sign-File -FilePath $packageFile -CertificatePath $PfxPath -CertificatePassword $PfxPassword
}
