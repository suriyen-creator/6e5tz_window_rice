[CmdletBinding()]
param(
    [ValidateSet('next', 'toggle', 'pause', 'play', 'open')]
    [string]$Action = 'next'
)

$ErrorActionPreference = 'SilentlyContinue'

$wePaths = @(
    '__PROGRAMFILES__ (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe',
    '__PROGRAMFILES__\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe',
    '__PROGRAMFILES__ (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper32.exe',
    '__PROGRAMFILES__\Steam\steamapps\common\wallpaper_engine\wallpaper32.exe'
)

$weExe = $wePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $weExe) {
    Write-Warning "Wallpaper Engine executable not found."
    exit 1
}

$stateFile = Join-Path $env:TEMP 'yasb_we_state.txt'

switch ($Action) {
    'next' {
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
