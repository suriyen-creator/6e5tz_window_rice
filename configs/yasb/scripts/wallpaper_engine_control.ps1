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

function Get-WallpaperEngineProjects {
    $projects = [System.Collections.Generic.List[string]]::new()
    
    # 1. Workshop items (Steam App ID 431960)
    $wsDirs = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\workshop\content\431960'),
        (Join-Path $env:ProgramFiles 'Steam\steamapps\workshop\content\431960')
    )
    
    # Check Steam libraryfolders.vdf for custom Steam library paths
    $vdfPath = Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\libraryfolders.vdf'
    if (Test-Path $vdfPath) {
        $vdf = Get-Content -Path $vdfPath -Raw -ErrorAction SilentlyContinue
        $matches = [regex]::Matches($vdf, '"path"\s+"([^"]+)"')
        foreach ($m in $matches) {
            $libPath = $m.Groups[1].Value.Replace('\\', '\')
            $ws = Join-Path $libPath 'steamapps\workshop\content\431960'
            if (($wsDirs -notcontains $ws) -and (Test-Path $ws)) {
                $wsDirs += $ws
            }
        }
    }

    foreach ($wsDir in $wsDirs) {
        if (Test-Path $wsDir) {
            $found = Get-ChildItem -Path $wsDir -Filter 'project.json' -Recurse -Depth 2 -File -ErrorAction SilentlyContinue
            foreach ($f in $found) {
                $projects.Add($f.FullName)
            }
        }
    }

    # 2. Local default/myprojects
    $localDirs = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\wallpaper_engine\projects\defaultprojects'),
        (Join-Path $env:ProgramFiles 'Steam\steamapps\common\wallpaper_engine\projects\defaultprojects'),
        (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\wallpaper_engine\projects\myprojects'),
        (Join-Path $env:ProgramFiles 'Steam\steamapps\common\wallpaper_engine\projects\myprojects')
    )
    foreach ($ld in $localDirs) {
        if (Test-Path $ld) {
            $found = Get-ChildItem -Path $ld -Filter 'project.json' -Recurse -Depth 2 -File -ErrorAction SilentlyContinue
            foreach ($f in $found) {
                $projects.Add($f.FullName)
            }
        }
    }

    return $projects
}

$stateFile = Join-Path $env:TEMP 'yasb_we_state.txt'

switch ($Action) {
    'next' {
        # Intelligent cycling: If user has workshop or local wallpapers installed, cycle through them directly
        $projList = Get-WallpaperEngineProjects
        if ($projList.Count -gt 0) {
            $idxFile = Join-Path $env:LOCALAPPDATA 'yasb_we_index.txt'
            $currentIdx = 0
            if (Test-Path $idxFile) {
                try {
                    $val = (Get-Content -Path $idxFile -Raw -ErrorAction SilentlyContinue).Trim()
                    $currentIdx = [int]$val
                } catch { $currentIdx = 0 }
            }
            $nextIdx = ($currentIdx + 1) % $projList.Count
            Set-Content -Path $idxFile -Value "$nextIdx" -Force
            
            $chosen = $projList[$nextIdx]
            Start-Process -FilePath $weExe -ArgumentList '-control', 'openWallpaper', '-file', "`"$chosen`"" -WindowStyle Hidden
        }

        # Also send nextWallpaper for playlist rotations
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
