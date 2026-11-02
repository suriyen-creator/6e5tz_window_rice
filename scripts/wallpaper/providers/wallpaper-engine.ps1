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

$script:WeWallpaperCache = @{}

function Get-WallpaperEngineWallpapers {
    param(
        [string]$CollectionName = '',
        [switch]$Force
    )

    $cacheKey = if (-not [string]::IsNullOrWhiteSpace($CollectionName)) { $CollectionName } else { '__ALL__' }
    if (-not $Force -and $script:WeWallpaperCache.ContainsKey($cacheKey) -and $null -ne $script:WeWallpaperCache[$cacheKey]) {
        return @($script:WeWallpaperCache[$cacheKey])
    }

    $info = Get-WallpaperEngineInfo
    if (-not $info.Available -or -not $info.ExePath) {
        return @()
    }

    $weDir = [System.IO.Path]::GetDirectoryName($info.ExePath)
    $steamAppsDir = [System.IO.Path]::GetFullPath((Join-Path $weDir '..\..'))
    $workshopDir = Join-Path $steamAppsDir 'workshop\content\431960'
    $defaultProjectsDir = Join-Path $weDir 'projects\defaultprojects'
    $myProjectsDir = Join-Path $weDir 'projects\myprojects'

    $results = [System.Collections.Generic.List[object]]::new()
    $seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $parseProject = {
        param([string]$projJsonPath, [string]$colName)
        if (-not (Test-Path -LiteralPath $projJsonPath)) { return }
        $fullProj = [System.IO.Path]::GetFullPath($projJsonPath)
        if ($seenPaths.Contains($fullProj)) { return }
        $null = $seenPaths.Add($fullProj)

        $dir = [System.IO.Path]::GetDirectoryName($fullProj)
        $title = [System.IO.Path]::GetFileName($dir)
        $type = 'Scene'
        $preview = $null

        try {
            $raw = [System.IO.File]::ReadAllText($fullProj, [System.Text.Encoding]::UTF8)
            $meta = $raw | ConvertFrom-Json
            if ($null -ne $meta) {
                if ($null -ne $meta.PSObject.Properties['title'] -and -not [string]::IsNullOrWhiteSpace($meta.title)) {
                    $title = [string]$meta.title
                }
                if ($null -ne $meta.PSObject.Properties['type'] -and -not [string]::IsNullOrWhiteSpace($meta.type)) {
                    $type = [string]$meta.type
                }
                if ($null -ne $meta.PSObject.Properties['preview'] -and -not [string]::IsNullOrWhiteSpace($meta.preview)) {
                    $cand = Join-Path $dir $meta.preview
                    if (Test-Path -LiteralPath $cand) { $preview = $cand }
                }
            }
        } catch {}

        if (-not $preview) {
            foreach ($candName in @('preview.jpg', 'preview.png', 'preview.gif', 'preview.jpeg')) {
                $cand = Join-Path $dir $candName
                if (Test-Path -LiteralPath $cand) { $preview = $cand; break }
            }
        }

        $results.Add([PSCustomObject]@{
            Title = $title
            Type = $type
            Preview = $preview
            Path = $fullProj
            Collection = $colName
            Provider = 'WallpaperEngine'
        })
    }

    # If Playlist specified or found
    if ($CollectionName -and $CollectionName -ne 'Default Projects' -and $CollectionName -ne 'Workshop Subscriptions' -and $CollectionName -ne 'All') {
        if ($info.ConfigPath -and (Test-Path -LiteralPath $info.ConfigPath)) {
            try {
                $raw = [System.IO.File]::ReadAllText($info.ConfigPath, [System.Text.Encoding]::UTF8)
                $cfg = $raw | ConvertFrom-Json
                foreach ($prop in $cfg.PSObject.Properties) {
                    $val = $prop.Value
                    if ($null -ne $val -and $null -ne $val.PSObject.Properties['general'] -and $null -ne $val.general.PSObject.Properties['playlists']) {
                        foreach ($pl in @($val.general.playlists)) {
                            if ($pl.name -eq $CollectionName -and $null -ne $pl.PSObject.Properties['items']) {
                                foreach ($item in @($pl.items)) {
                                    $itemStr = [string]$item
                                    $projFile = $null
                                    if ($itemStr -like '*project.json*') {
                                        $projFile = $itemStr
                                    } else {
                                        $parent = [System.IO.Path]::GetDirectoryName($itemStr)
                                        $c = Join-Path $parent 'project.json'
                                        if (Test-Path -LiteralPath $c) { $projFile = $c }
                                        elseif (Test-Path -LiteralPath $itemStr) { $projFile = $itemStr }
                                    }
                                    if ($projFile -and (Test-Path -LiteralPath $projFile)) {
                                        & $parseProject $projFile $CollectionName
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {}
        }
    }

    # Scan Default Projects
    if (-not $CollectionName -or $CollectionName -eq 'All' -or $CollectionName -eq 'Default Projects') {
        if (Test-Path -LiteralPath $defaultProjectsDir) {
            Get-ChildItem -LiteralPath $defaultProjectsDir -Filter 'project.json' -Recurse -File -Depth 2 -ErrorAction SilentlyContinue | ForEach-Object {
                & $parseProject $_.FullName 'Default Projects'
            }
        }
    }

    # Scan Workshop Subscriptions
    if (-not $CollectionName -or $CollectionName -eq 'All' -or $CollectionName -eq 'Workshop Subscriptions') {
        if (Test-Path -LiteralPath $workshopDir) {
            Get-ChildItem -LiteralPath $workshopDir -Filter 'project.json' -Recurse -File -Depth 2 -ErrorAction SilentlyContinue | ForEach-Object {
                & $parseProject $_.FullName 'Workshop Subscriptions'
            }
        }
    }

    # Scan My Projects
    if (Test-Path -LiteralPath $myProjectsDir) {
        Get-ChildItem -LiteralPath $myProjectsDir -Filter 'project.json' -Recurse -File -Depth 2 -ErrorAction SilentlyContinue | ForEach-Object {
            & $parseProject $_.FullName 'My Projects'
        }
    }

    $resArray = @($results)
    $script:WeWallpaperCache[$cacheKey] = $resArray
    return $resArray
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
    }

    # Add Default Projects & Workshop Subscriptions collections
    $info = Get-WallpaperEngineInfo
    if ($info.Available -and $info.ExePath) {
        $weDir = [System.IO.Path]::GetDirectoryName($info.ExePath)
        $defDir = Join-Path $weDir 'projects\defaultprojects'
        if (Test-Path -LiteralPath $defDir) {
            $defCount = @(Get-ChildItem -LiteralPath $defDir -Filter 'project.json' -Recurse -File -Depth 2 -ErrorAction SilentlyContinue).Count
            $list.Add([PSCustomObject]@{
                Name = 'Default Projects'
                Path = $defDir
                Provider = 'WallpaperEngine'
                ItemCount = $defCount
                IsRoot = ($list.Count -eq 0)
            })
        }

        $steamAppsDir = [System.IO.Path]::GetFullPath((Join-Path $weDir '..\..'))
        $wsDir = Join-Path $steamAppsDir 'workshop\content\431960'
        if (Test-Path -LiteralPath $wsDir) {
            $wsCount = @(Get-ChildItem -LiteralPath $wsDir -Filter 'project.json' -Recurse -File -Depth 2 -ErrorAction SilentlyContinue).Count
            $list.Add([PSCustomObject]@{
                Name = 'Workshop Subscriptions'
                Path = $wsDir
                Provider = 'WallpaperEngine'
                ItemCount = $wsCount
                IsRoot = $false
            })
        }
    }

    if ($list.Count -eq 0) {
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
        if (Test-Path -LiteralPath (Join-Path $full 'project.json')) {
            $full = Join-Path $full 'project.json'
        }
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
