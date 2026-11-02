[CmdletBinding()]
param(
    [ValidateSet('Static', 'WallpaperEngine', 'Lively', 'Auto')]
    [string]$Mode = 'Auto'
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$userConfigDir = Join-Path $env:USERPROFILE '.config\yasb'
$userConfigFile = Join-Path $userConfigDir 'config.yaml'
$wallpapersDir = Join-Path $env:USERPROFILE 'Pictures\Wallpapers'
$repoWallpapers = Join-Path $repoRoot 'wallpapers'
$managerScript = Join-Path $repoRoot 'scripts\wallpaper\manager.ps1'

# Detect providers
. (Join-Path $repoRoot 'scripts\wallpaper\detection.ps1')
$providers = Get-WallpaperProviders
$weInstalled = $providers['WallpaperEngine'].Available
$livelyInstalled = $providers['Lively'].Available

if ($Mode -eq 'Auto') {
    Write-Host "`n=======================================================" -ForegroundColor Cyan
    Write-Host "   6e5tz Universal Wallpaper Manager - Mode Selector   " -ForegroundColor Magenta
    Write-Host "=======================================================" -ForegroundColor Cyan
    
    Write-Host " [1] Static Wallpapers (Windows Desktop Gallery) [Always Available]" -ForegroundColor Green
    Write-Host "     - Pure Windows desktop wallpapers with folder collections"
    
    if ($weInstalled) {
        Write-Host " [2] Wallpaper Engine (Detected on this system)" -ForegroundColor Cyan
        Write-Host "     - Playlist & CLI control via Steam"
    } else {
        Write-Host " [2] Wallpaper Engine (Offline / Not installed)" -ForegroundColor DarkGray
    }

    if ($livelyInstalled) {
        Write-Host " [3] Lively Wallpaper (Detected on this system)" -ForegroundColor Yellow
        Write-Host "     - Video, GIF, and interactive web wallpapers"
    } else {
        Write-Host " [3] Lively Wallpaper (Offline / Not installed)" -ForegroundColor DarkGray
    }

    $choice = Read-Host "`nEnter option (1, 2, or 3) [Default: 1]"
    $Mode = switch ($choice) {
        '2' { if ($weInstalled) { 'WallpaperEngine' } else { 'Static' } }
        '3' { if ($livelyInstalled) { 'Lively' } else { 'Static' } }
        default { 'Static' }
    }
}

Write-Host "`n[INFO] Switching to $Mode Wallpaper Mode..." -ForegroundColor Cyan

# Update Universal Wallpaper Manager state
if (Test-Path -LiteralPath $managerScript) {
    & $managerScript -Action provider -Provider $Mode | Out-Null
}

if ($Mode -eq 'Static') {
    if (-not (Test-Path $wallpapersDir)) {
        New-Item -ItemType Directory -Path $wallpapersDir -Force | Out-Null
    }
    $existing = Get-ChildItem -Path $wallpapersDir -Filter '*.png' -ErrorAction SilentlyContinue
    if (($null -eq $existing -or $existing.Count -eq 0) -and (Test-Path $repoWallpapers)) {
        Write-Host "[INFO] Copying sample anime wallpapers to $wallpapersDir..." -ForegroundColor Cyan
        Copy-Item -Path (Join-Path $repoWallpapers '*.png') -Destination $wallpapersDir -Force
    }
    
    $sourceTemplate = @(
        (Join-Path $repoRoot 'configs\yasb\config.static.yaml'),
        (Join-Path $userConfigDir 'config.static.yaml')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($sourceTemplate) {
        $content = [System.IO.File]::ReadAllText($sourceTemplate, [System.Text.Encoding]::UTF8)
        $userSlash = ($env:USERPROFILE).Replace('\', '/')
        $content = $content.Replace('__USERPROFILE__/', "$userSlash/")
        $content = $content.Replace('__USERPROFILE__', $userSlash)
        [System.IO.File]::WriteAllText($userConfigFile, $content, $utf8NoBom)
        Write-Host "[SUCCESS] Deployed Static Wallpapers configuration to $userConfigFile" -ForegroundColor Green
    }
} else {
    $sourceTemplate = @(
        (Join-Path $repoRoot 'configs\yasb\config.wallpaper-engine.yaml'),
        (Join-Path $userConfigDir 'config.wallpaper-engine.yaml')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($sourceTemplate) {
        $content = [System.IO.File]::ReadAllText($sourceTemplate, [System.Text.Encoding]::UTF8)
        $userSlash = ($env:USERPROFILE).Replace('\', '/')
        $content = $content.Replace('__USERPROFILE__/', "$userSlash/")
        $content = $content.Replace('__USERPROFILE__', $userSlash)
        [System.IO.File]::WriteAllText($userConfigFile, $content, $utf8NoBom)
        Write-Host "[SUCCESS] Deployed $Mode configuration to $userConfigFile" -ForegroundColor Green
    }
}

# Restart YASB smoothly if running
$yasbProc = Get-Process -Name 'yasb' -ErrorAction SilentlyContinue
if ($yasbProc) {
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
}
