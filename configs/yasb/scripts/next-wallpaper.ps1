[CmdletBinding()]
param(
    [ValidateSet('Auto', 'Static', 'WallpaperEngine')]
    [string]$Mode = 'Auto'
)

$ErrorActionPreference = 'SilentlyContinue'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$weControlScript = Join-Path $scriptDir "wallpaper_engine_control.ps1"

# Determine target mode
$target = $Mode
if ($target -eq 'Auto') {
    $weProc = Get-Process -Name 'wallpaper64', 'wallpaper32' -ErrorAction SilentlyContinue | Select-Object -First 1
    $yasbConfig = Join-Path $env:USERPROFILE '.config\yasb\config.yaml'
    $isWeInConfig = $false
    if (Test-Path $yasbConfig) {
        $content = Get-Content -Path $yasbConfig -Raw -ErrorAction SilentlyContinue
        if ($content -match 'wallpaper_engine') {
            $isWeInConfig = $true
        }
    }
    
    $weCandidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\wallpaper_engine\wallpaper64.exe'),
        (Join-Path $env:ProgramFiles 'Steam\steamapps\common\wallpaper_engine\wallpaper64.exe')
    )
    $hasWeBinary = [bool]($weCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1)

    if (($weProc -or $isWeInConfig) -and $hasWeBinary -and (Test-Path $weControlScript)) {
        $target = 'WallpaperEngine'
    } else {
        $target = 'Static'
    }
}

if ($target -eq 'WallpaperEngine' -and (Test-Path $weControlScript)) {
    & $weControlScript -Action next
}

# -------------------------------------------------------------
# Static Wallpaper Cycling (Windows Desktop)
# We update static wallpaper as well so:
# 1) If WE is closed, paused, or uninstalled, desktop is fresh.
# 2) If in Static mode, changes desktop wallpaper immediately.
# -------------------------------------------------------------
$wallDir = Join-Path $env:USERPROFILE "Pictures\Wallpapers"
if (-not (Test-Path $wallDir)) {
    $repoWall = Join-Path $scriptDir "..\..\..\wallpapers"
    if (Test-Path $repoWall) {
        $wallDir = (Resolve-Path $repoWall).Path
    } else {
        exit 0
    }
}

$exts = @('.jpg', '.jpeg', '.png', '.webp')
$wallpapers = @(Get-ChildItem -Path $wallDir -File -ErrorAction SilentlyContinue | Where-Object { $exts -contains $_.Extension.ToLowerInvariant() } | Sort-Object Name)

if ($wallpapers.Count -gt 0) {
    $current = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -ErrorAction SilentlyContinue).Wallpaper
    $currentIndex = -1
    for ($i = 0; $i -lt $wallpapers.Count; $i++) {
        if ($wallpapers[$i].FullName -ieq $current) {
            $currentIndex = $i
            break
        }
    }

    $nextIndex = ($currentIndex + 1) % $wallpapers.Count
    $nextWallpaper = $wallpapers[$nextIndex].FullName

    $code = @"
using System;
using System.Runtime.InteropServices;
public class WinWallpaperSwitcher {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
    if (-not ([System.Management.Automation.PSTypeName]'WinWallpaperSwitcher').Type) {
        Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
    }

    [WinWallpaperSwitcher]::SystemParametersInfo(0x0014, 0, $nextWallpaper, 0x01 -bor 0x02)
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $nextWallpaper -Force -ErrorAction SilentlyContinue
}
