# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Floating Acrylic Side Panel UI (PowerShell)
# Catppuccin Mocha aesthetic, smooth slide-in, auto-hide, zero-console integration
# ==============================================================================

[CmdletBinding()]
param(
    [string]$Notice = '',
    [string]$Provider = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Ensure STA thread for WPF
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    $scriptPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
    $pwshCandidates = @(
        (Join-Path $env:USERPROFILE 'scoop\apps\pwsh\current\pwsh.exe'),
        'C:\Program Files\PowerShell\7\pwsh.exe',
        'powershell.exe'
    )
    $hostExe = $pwshCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $hostExe) { $hostExe = 'powershell.exe' }

    $argList = @("-Sta", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"")
    if (-not [string]::IsNullOrWhiteSpace($Notice)) { $argList += "-Notice", "`"$Notice`"" }
    if (-not [string]::IsNullOrWhiteSpace($Provider)) { $argList += "-Provider", "`"$Provider`"" }

    Start-Process -FilePath $hostExe -ArgumentList $argList -WindowStyle Hidden
    exit 0
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$scriptRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $scriptRoot 'common.ps1')
. (Join-Path $scriptRoot 'config.ps1')
. (Join-Path $scriptRoot 'state.ps1')
. (Join-Path $scriptRoot 'detection.ps1')
. (Join-Path $scriptRoot 'collections\folders.ps1')
. (Join-Path $scriptRoot 'providers\static.ps1')
. (Join-Path $scriptRoot 'providers\wallpaper-engine.ps1')
. (Join-Path $scriptRoot 'providers\lively.ps1')
. (Join-Path $scriptRoot 'manager.ps1')

# If native binary exists, prefer executing it for zero latency
$binCandidates = @(
    (Join-Path $scriptRoot '..\..\configs\yasb\scripts\wallpaper-gallery.exe'),
    (Join-Path $env:USERPROFILE '.config\yasb\scripts\wallpaper-gallery.exe'),
    (Join-Path $scriptRoot '..\..\configs\yasb\scripts\WallpaperSidePanel.exe')
)
$bin = $binCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($bin) {
    $argList = @()
    if (-not [string]::IsNullOrWhiteSpace($Notice)) { $argList += "-Notice", "`"$Notice`"" }
    if (-not [string]::IsNullOrWhiteSpace($Provider)) { $argList += "-Provider", "`"$Provider`"" }
    Start-Process -FilePath $bin -ArgumentList $argList -WindowStyle Hidden
    exit 0
}

# Fallback: launch gallery.ps1
$galleryPs1 = Join-Path $PSScriptRoot 'gallery.ps1'
if (Test-Path -LiteralPath $galleryPs1) {
    & $galleryPs1
}
