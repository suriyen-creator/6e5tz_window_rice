[CmdletBinding()]
param(
    [ValidateSet('next', 'toggle', 'pause', 'play', 'open')]
    [string]$Action = 'next'
)

$ErrorActionPreference = 'SilentlyContinue'

# 1. Resolve executable dynamically (never hardcode static markers)
$candidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\wallpaper_engine\wallpaper64.exe'),
    (Join-Path $env:ProgramFiles 'Steam\steamapps\common\wallpaper_engine\wallpaper64.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\wallpaper_engine\wallpaper32.exe'),
    (Join-Path $env:ProgramFiles 'Steam\steamapps\common\wallpaper_engine\wallpaper32.exe')
)

# Check if a process is already running
$runningProc = Get-Process -Name 'wallpaper64', 'wallpaper32' -ErrorAction SilentlyContinue | Select-Object -First 1

$weExe = $null
if ($runningProc) {
    try {
        $weExe = $runningProc.Path
    } catch {}
}

if (-not $weExe -or -not (Test-Path $weExe)) {
    $weExe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $weExe) {
    Write-Warning "Wallpaper Engine executable not found."
    exit 1
}

# If Wallpaper Engine isn't running yet, launch it
if (-not $runningProc) {
    Start-Process -FilePath $weExe -WindowStyle Hidden
    Start-Sleep -Milliseconds 1200
}

$stateFile = Join-Path $env:TEMP 'yasb_we_state.txt'

switch ($Action) {
    'next' {
        # Trigger next wallpaper
        Start-Process -FilePath $weExe -ArgumentList '-control', 'nextWallpaper' -WindowStyle Hidden
    }
    'pause' {
        Start-Process -FilePath $weExe -ArgumentList '-control', 'pause' -WindowStyle Hidden
        Set-Content -Path $stateFile -Value 'paused' -Force
    }
    'play' {
        Start-Process -FilePath $weExe -ArgumentList '-control', 'play' -WindowStyle Hidden
        Set-Content -Path $stateFile -Value 'playing' -Force
    }
    'toggle' {
        $currentState = if (Test-Path $stateFile) { (Get-Content -Path $stateFile -Raw).Trim() } else { 'playing' }
        if ($currentState -eq 'paused') {
            Start-Process -FilePath $weExe -ArgumentList '-control', 'play' -WindowStyle Hidden
            Set-Content -Path $stateFile -Value 'playing' -Force
        } else {
            Start-Process -FilePath $weExe -ArgumentList '-control', 'pause' -WindowStyle Hidden
            Set-Content -Path $stateFile -Value 'paused' -Force
        }
    }
    'open' {
        Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'start', 'steam://rungameid/431960' -WindowStyle Hidden
    }
}
