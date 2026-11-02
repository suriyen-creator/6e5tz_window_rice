# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Provider Detection System
# Automatically identifies installed engines, library paths, and running processes
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

function Get-SteamLibraryPaths {
    $steamLibraries = [System.Collections.Generic.List[string]]::new()
    
    # 1. Main Steam installation from Registry
    $regPaths = @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam'
    )
    foreach ($rp in $regPaths) {
        if (Test-Path -LiteralPath $rp) {
            $item = Get-ItemProperty -LiteralPath $rp -ErrorAction SilentlyContinue
            if ($null -ne $item) {
                $val = if ($null -ne $item.PSObject.Properties['SteamPath']) { $item.SteamPath } `
                       elseif ($null -ne $item.PSObject.Properties['InstallPath']) { $item.InstallPath } `
                       else { $null }
                if (-not [string]::IsNullOrWhiteSpace($val)) {
                    $steamLibraries.Add(($val -replace '/', '\'))
                }
            }
        }
    }

    # Common default paths
    $common = @(
        "${env:ProgramFiles(x86)}\Steam",
        "$env:ProgramFiles\Steam",
        "D:\Steam",
        "D:\SteamLibrary",
        "E:\Steam",
        "E:\SteamLibrary"
    )
    foreach ($c in $common) {
        if ((Test-Path -LiteralPath $c) -and ($steamLibraries -notcontains $c)) {
            $steamLibraries.Add($c)
        }
    }

    # 2. Parse libraryfolders.vdf for extra Steam libraries on other drives
    foreach ($lib in @($steamLibraries.ToArray())) {
        $vdf = Join-Path $lib 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            try {
                $lines = [System.IO.File]::ReadAllLines($vdf, [System.Text.Encoding]::UTF8)
                foreach ($line in $lines) {
                    if ($line -match '"path"\s+"([^"]+)"') {
                        $extraPath = ($matches[1] -replace '\\\\', '\') -replace '/', '\'
                        if ((Test-Path -LiteralPath $extraPath) -and ($steamLibraries -notcontains $extraPath)) {
                            $steamLibraries.Add($extraPath)
                        }
                    }
                }
            } catch {}
        }
    }

    return @($steamLibraries | Select-Object -Unique)
}

function Detect-WallpaperEngine {
    $proc = Get-Process -Name 'wallpaper64', 'wallpaper32' -ErrorAction SilentlyContinue | Select-Object -First 1
    $running = ($null -ne $proc)
    $exePath = $null

    if ($running) {
        try { $exePath = $proc.Path } catch {}
    }

    if (-not $exePath -or -not (Test-Path -LiteralPath $exePath)) {
        $libraries = Get-SteamLibraryPaths
        foreach ($lib in $libraries) {
            $cands = @(
                (Join-Path $lib 'steamapps\common\wallpaper_engine\wallpaper64.exe'),
                (Join-Path $lib 'steamapps\common\wallpaper_engine\wallpaper32.exe')
            )
            foreach ($cand in $cands) {
                if (Test-Path -LiteralPath $cand) {
                    $exePath = $cand
                    break
                }
            }
            if ($exePath) { break }
        }
    }

    $available = (-not [string]::IsNullOrWhiteSpace($exePath) -and (Test-Path -LiteralPath $exePath))
    $configPath = $null
    if ($available) {
        $dir = Split-Path -Parent $exePath
        $candCfg = Join-Path $dir 'config.json'
        if (Test-Path -LiteralPath $candCfg) {
            $configPath = $candCfg
        }
    }

    return [PSCustomObject]@{
        Name = 'WallpaperEngine'
        DisplayName = 'Wallpaper Engine'
        Available = $available
        Running = $running
        ExePath = $exePath
        ConfigPath = $configPath
        Description = if ($available) { "Installed at $(Split-Path -Parent $exePath)" } else { "Wallpaper Engine was not detected on this system" }
    }
}

function Detect-LivelyWallpaper {
    $proc = Get-Process -Name 'Lively', 'livelycu' -ErrorAction SilentlyContinue | Select-Object -First 1
    $running = ($null -ne $proc)
    $exePath = $null
    $cliPath = $null

    if ($running) {
        try { $exePath = $proc.Path } catch {}
    }

    # Check PATH first
    $cliCmd = Get-Command 'livelycu' -ErrorAction SilentlyContinue
    if ($cliCmd) { $cliPath = $cliCmd.Source }

    $livelyCmd = Get-Command 'Lively' -ErrorAction SilentlyContinue
    if ($livelyCmd -and -not $exePath) { $exePath = $livelyCmd.Source }

    # Candidate paths for standalone / installer / Scoop / AppX
    $candidates = @(
        "$env:ProgramFiles\Lively Wallpaper\Lively.exe",
        "${env:ProgramFiles(x86)}\Lively Wallpaper\Lively.exe",
        "$env:LOCALAPPDATA\Programs\Lively Wallpaper\Lively.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\livelycu.exe",
        "$env:USERPROFILE\scoop\apps\lively\current\Lively.exe"
    )

    foreach ($cand in $candidates) {
        if (-not $exePath -and (Test-Path -LiteralPath $cand)) {
            $exePath = $cand
        }
    }

    if ($exePath -and -not $cliPath) {
        $dir = Split-Path -Parent $exePath
        $candCli = Join-Path $dir 'livelycu.exe'
        if (Test-Path -LiteralPath $candCli) {
            $cliPath = $candCli
        } else {
            $cliPath = $exePath
        }
    }

    $available = (-not [string]::IsNullOrWhiteSpace($exePath) -and (Test-Path -LiteralPath $exePath)) -or
                 (-not [string]::IsNullOrWhiteSpace($cliPath) -and (Test-Path -LiteralPath $cliPath))

    return [PSCustomObject]@{
        Name = 'Lively'
        DisplayName = 'Lively Wallpaper'
        Available = $available
        Running = $running
        ExePath = $exePath
        CliPath = $cliPath
        Description = if ($available) { "Installed at $(Split-Path -Parent $exePath)" } else { "Lively Wallpaper was not detected on this system" }
    }
}

function Detect-StaticWallpaper {
    return [PSCustomObject]@{
        Name = 'Static'
        DisplayName = 'Static Wallpaper'
        Available = $true
        Running = $true
        ExePath = 'explorer.exe'
        CliPath = $null
        Description = 'Native Windows desktop wallpaper management (JPG, PNG, WEBP)'
    }
}

function Get-WallpaperProviders {
    return @{
        Static = Detect-StaticWallpaper
        WallpaperEngine = Detect-WallpaperEngine
        Lively = Detect-LivelyWallpaper
    }
}

function Test-ProviderAvailable {
    param([Parameter(Mandatory = $true)][string]$Name)
    $providers = Get-WallpaperProviders
    if ($providers.ContainsKey($Name)) {
        return [bool]$providers[$Name].Available
    }
    return $false
}

# End of detection system
