# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Wallpaper Engine Provider
# Communicates with Steam Wallpaper Engine via official CLI controls
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\common.ps1')
. (Join-Path $PSScriptRoot '..\config.ps1')
. (Join-Path $PSScriptRoot '..\state.ps1')
. (Join-Path $PSScriptRoot '..\detection.ps1')

function Get-WallpaperEngineInfo {
    return (Detect-WallpaperEngine)
}

function Ensure-WallpaperEngineRunning {
    $info = Get-WallpaperEngineInfo
    if (-not $info.Available) {
        Write-WpLog -Message "Wallpaper Engine is not installed." -Level Warning
        return $false
    }

    $proc = Get-Process -Name 'wallpaper64', 'wallpaper32' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) {
        Write-WpLog -Message "Starting Wallpaper Engine ($($info.ExePath))..." -Level Info
        Start-Process -FilePath $info.ExePath -WindowStyle Hidden
        Start-Sleep -Milliseconds 1200
    }
    return $true
}

function Invoke-WallpaperEngineCli {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $info = Get-WallpaperEngineInfo
    if (-not $info.Available) {
        Write-WpLog -Message "Wallpaper Engine is unavailable. Cannot execute CLI." -Level Warning
        return $false
    }

    # If the command is pause/stop and engine is not running, skip launching it
    if ($Arguments -contains 'pause' -or $Arguments -contains 'stop') {
        if (-not $info.Running) {
            return $true
        }
    } else {
        Ensure-WallpaperEngineRunning | Out-Null
    }

    try {
        Start-Process -FilePath $info.ExePath -ArgumentList $Arguments -WindowStyle Hidden
        return $true
    } catch {
        Write-WpLog -Message "Failed to execute Wallpaper Engine CLI: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-WallpaperEnginePlaylists {
    $info = Get-WallpaperEngineInfo
    if (-not $info.Available -or -not $info.ConfigPath -or -not (Test-Path -LiteralPath $info.ConfigPath)) {
        return @()
    }

    try {
        $raw = [System.IO.File]::ReadAllText($info.ConfigPath, [System.Text.Encoding]::UTF8)
        $cfg = $raw | ConvertFrom-Json
        $playlists = [System.Collections.Generic.List[object]]::new()

        # Find user profiles in config
        foreach ($prop in $cfg.PSObject.Properties) {
            $val = $prop.Value
            if ($null -ne $val -and $null -ne $val.PSObject.Properties['general']) {
                $gen = $val.general
                if ($null -ne $gen.PSObject.Properties['playlists']) {
                    foreach ($pl in @($gen.playlists)) {
                        $pName = if ($null -ne $pl.PSObject.Properties['name']) { [string]$pl.name } else { 'Unnamed' }
                        $pCount = if ($null -ne $pl.PSObject.Properties['count']) { [int]$pl.count } else { 0 }
                        $playlists.Add([PSCustomObject]@{
                            Name = $pName
                            Count = $pCount
                            Provider = 'WallpaperEngine'
                            IsPlaylist = $true
                        })
                    }
                }
            }
        }
        return @($playlists)
    } catch {
        Write-WpLog -Message "Failed to read Wallpaper Engine playlists: $($_.Exception.Message)" -Level Warning
        return @()
    }
}

function Get-WallpaperEngineCollections {
    $list = [System.Collections.Generic.List[object]]::new()
    $playlists = Get-WallpaperEnginePlaylists

    if ($playlists.Count -gt 0) {
        foreach ($p in $playlists) {
            $list.Add([PSCustomObject]@{
                Name = $p.Name
                Path = "Playlist://$($p.Name)"
                Provider = 'WallpaperEngine'
                ItemCount = $p.Count
                IsRoot = $false
            })
        }
    } else {
        $list.Add([PSCustomObject]@{
            Name = 'Default'
            Path = 'WallpaperEngine://Active'
            Provider = 'WallpaperEngine'
            ItemCount = 1
            IsRoot = $true
        })
    }

    return @($list)
}

function Set-WallpaperEngineWallpaper {
    param([Parameter(Mandatory = $true)][string]$PathOrPlaylist)

    if ($PathOrPlaylist.StartsWith('Playlist://')) {
        $plName = $PathOrPlaylist.Substring('Playlist://'.Length)
        Write-WpLog -Message "Activating Wallpaper Engine playlist: $plName" -Level Info
        $success = Invoke-WallpaperEngineCli -Arguments @('-control', 'openPlaylist', '-playlist', $plName)
        if ($success) {
            $state = Get-WpState
            $state.currentWallpaper = $PathOrPlaylist
            $state.activeProvider = 'WallpaperEngine'
            $null = Save-WpState -State $state
        }
        return $success
    }

    if (Test-Path -LiteralPath $PathOrPlaylist) {
        $full = [System.IO.Path]::GetFullPath($PathOrPlaylist)
        Write-WpLog -Message "Activating Wallpaper Engine file: $full" -Level Info
        $success = Invoke-WallpaperEngineCli -Arguments @('-control', 'openWallpaper', '-file', $full)
        if ($success) {
            $state = Get-WpState
            $state.currentWallpaper = $full
            $state.activeProvider = 'WallpaperEngine'
            $null = Save-WpState -State $state
        }
        return $success
    }

    # Assume playlist name by default
    $success = Invoke-WallpaperEngineCli -Arguments @('-control', 'openPlaylist', '-playlist', $PathOrPlaylist)
    if ($success) {
        $state = Get-WpState
        $state.currentWallpaper = $PathOrPlaylist
        $state.activeProvider = 'WallpaperEngine'
        $null = Save-WpState -State $state
    }
    return $success
}

function Next-WallpaperEngineWallpaper {
    param([string]$CollectionName = '')
    
    # If a specific playlist was passed and differs from current, switch playlist
    if (-not [string]::IsNullOrWhiteSpace($CollectionName) -and $CollectionName -ne 'Default') {
        $state = Get-WpState
        $currPl = if ($null -ne $state.activeCollection.PSObject.Properties['WallpaperEngine']) {
            [string]$state.activeCollection.WallpaperEngine
        } else { '' }

        if ($currPl -ne $CollectionName) {
            Set-WallpaperEngineWallpaper -PathOrPlaylist $CollectionName | Out-Null
            return "Playlist:$CollectionName"
        }
    }

    Write-WpLog -Message "Advancing to next Wallpaper Engine wallpaper..." -Level Info
    $success = Invoke-WallpaperEngineCli -Arguments @('-control', 'nextWallpaper')
    if ($success) { return 'next' }
    return $null
}

function Pause-WallpaperEngine {
    return (Invoke-WallpaperEngineCli -Arguments @('-control', 'pause'))
}

function Resume-WallpaperEngine {
    return (Invoke-WallpaperEngineCli -Arguments @('-control', 'play'))
}

function Stop-WallpaperEngine {
    return (Invoke-WallpaperEngineCli -Arguments @('-control', 'stop'))
}

function Open-WallpaperEngineUi {
    Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'start', 'steam://rungameid/431960' -WindowStyle Hidden
}

# End of Wallpaper Engine provider
