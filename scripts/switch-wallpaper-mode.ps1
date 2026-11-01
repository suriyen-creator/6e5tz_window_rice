[CmdletBinding()]
param(
    [ValidateSet('Static', 'WallpaperEngine', 'Auto')]
    [string]$Mode = 'Auto'
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$userConfigDir = Join-Path $env:USERPROFILE '.config\yasb'
$userConfigFile = Join-Path $userConfigDir 'config.yaml'
$wallpapersDir = Join-Path $env:USERPROFILE 'Pictures\Wallpapers'
$repoWallpapers = Join-Path $repoRoot 'wallpapers'

# Detect Wallpaper Engine executable
$wePaths = @(
    'C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe',
    'C:\Program Files\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe',
    'C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper32.exe',
    'C:\Program Files\Steam\steamapps\common\wallpaper_engine\wallpaper32.exe'
)
$weInstalled = [bool]($wePaths | Where-Object { Test-Path $_ } | Select-Object -First 1)

if ($Mode -eq 'Auto') {
    Write-Host "`n=======================================================" -ForegroundColor Cyan
    Write-Host "   Select Desktop Wallpaper Mode for YASB              " -ForegroundColor Magenta
    Write-Host "=======================================================" -ForegroundColor Cyan
    if ($weInstalled) {
        Write-Host " [1] Wallpaper Engine (Detected on this system) [Default]" -ForegroundColor Green
        Write-Host "     - Direct CLI control via YASB (Next / Pause / Play / Open)"
        Write-Host " [2] Static Wallpapers (Windows Desktop Gallery)" -ForegroundColor Yellow
        Write-Host "     - YASB Popup Gallery with thumbnails & manual picker"
        $choice = Read-Host "`nEnter option (1 or 2) [Default: 1]"
        $Mode = if ($choice -eq '2') { 'Static' } else { 'WallpaperEngine' }
    } else {
        Write-Host " [1] Static Wallpapers (Windows Desktop Gallery) [Default]" -ForegroundColor Green
        Write-Host "     - YASB Popup Gallery with thumbnails & manual picker"
        Write-Host " [2] Wallpaper Engine (CLI Control)" -ForegroundColor DarkGray
        Write-Host "     - Requires Wallpaper Engine via Steam"
        $choice = Read-Host "`nEnter option (1 or 2) [Default: 1]"
        $Mode = if ($choice -eq '2') { 'WallpaperEngine' } else { 'Static' }
    }
}

Write-Host "`n[INFO] Switching to $Mode Wallpaper Mode..." -ForegroundColor Cyan

if ($Mode -eq 'Static') {
    if (-not (Test-Path $wallpapersDir)) {
        New-Item -ItemType Directory -Path $wallpapersDir -Force | Out-Null
    }
    $existing = Get-ChildItem -Path $wallpapersDir -Filter '*.jpg' -ErrorAction SilentlyContinue
    if (($null -eq $existing -or $existing.Count -eq 0) -and (Test-Path $repoWallpapers)) {
        Write-Host "[INFO] Copying sample anime wallpapers to $wallpapersDir..." -ForegroundColor Cyan
        Copy-Item -Path (Join-Path $repoWallpapers '*.jpg') -Destination $wallpapersDir -Force
    }
    
    $sourceTemplate = @(
        (Join-Path $repoRoot 'configs\yasb\config.static.yaml'),
        (Join-Path $userConfigDir 'config.static.yaml')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $sourceTemplate) {
        Write-Error "Static wallpaper template config not found."
        exit 1
    }
    $content = [System.IO.File]::ReadAllText($sourceTemplate, [System.Text.Encoding]::UTF8)
    $userSlash = ($env:USERPROFILE).Replace('\', '/')
    $content = $content.Replace('__USERPROFILE__/', "$userSlash/")
    $content = $content.Replace('__USERPROFILE__', $userSlash)
    [System.IO.File]::WriteAllText($userConfigFile, $content, $utf8NoBom)
    Write-Host "[SUCCESS] Deployed Static Wallpapers configuration to $userConfigFile" -ForegroundColor Green
} else {
    $sourceTemplate = @(
        (Join-Path $repoRoot 'configs\yasb\config.wallpaper-engine.yaml'),
        (Join-Path $userConfigDir 'config.wallpaper-engine.yaml')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $sourceTemplate) {
        Write-Error "Wallpaper Engine template config not found."
        exit 1
    }
    $content = [System.IO.File]::ReadAllText($sourceTemplate, [System.Text.Encoding]::UTF8)
    $userSlash = ($env:USERPROFILE).Replace('\', '/')
    $content = $content.Replace('__USERPROFILE__/', "$userSlash/")
    $content = $content.Replace('__USERPROFILE__', $userSlash)
    [System.IO.File]::WriteAllText($userConfigFile, $content, $utf8NoBom)
    Write-Host "[SUCCESS] Deployed Wallpaper Engine configuration to $userConfigFile" -ForegroundColor Green
}

# Restart YASB smoothly
Write-Host "[INFO] Restarting YASB..." -ForegroundColor Cyan
Stop-Process -Name yasb -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 800
$glazeCmd = Get-Command glazewm -ErrorAction SilentlyContinue
if ($glazeCmd) {
    glazewm command shell-exec yasb | Out-Null
} else {
    Start-Process "C:\Program Files\YASB\yasb.exe"
}
Write-Host "[SUCCESS] YASB restarted successfully in $Mode mode!" -ForegroundColor Green
