[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\packaging\Assets')
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

function New-Logo {
    param(
        [int]$Width,
        [int]$Height,
        [string]$Path
    )

    $bitmap = New-Object System.Drawing.Bitmap $Width, $Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.Clear([System.Drawing.Color]::FromArgb(255, 14, 105, 92))

        $fontSize = [Math]::Max([Math]::Floor([Math]::Min($Width, $Height) * 0.42), 12)
        $font = New-Object System.Drawing.Font('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        $graphics.DrawString('R', $font, $brush, (New-Object System.Drawing.RectangleF 0, 0, $Width, $Height), $format)
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
        if ($font) { $font.Dispose() }
        if ($brush) { $brush.Dispose() }
        if ($format) { $format.Dispose() }
    }
}

New-Logo -Width 44 -Height 44 -Path (Join-Path $OutputDirectory 'Square44x44Logo.png')
New-Logo -Width 150 -Height 150 -Path (Join-Path $OutputDirectory 'Square150x150Logo.png')
New-Logo -Width 310 -Height 150 -Path (Join-Path $OutputDirectory 'Wide310x150Logo.png')
New-Logo -Width 50 -Height 50 -Path (Join-Path $OutputDirectory 'StoreLogo.png')
