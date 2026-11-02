# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Lively Wallpaper Provider
# Communicates with Lively Wallpaper via official CLI controls (livelycu.exe)
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\common.ps1')
. (Join-Path $PSScriptRoot '..\config.ps1')
. (Join-Path $PSScriptRoot '..\state.ps1')
. (Join-Path $PSScriptRoot '..\detection.ps1')
. (Join-Path $PSScriptRoot '..\collections\folders.ps1')

function Get-LivelyInfo {
    return (Detect-LivelyWallpaper)
}

function Ensure-LivelyRunning {
    $info = Get-LivelyInfo
    if (-not $info.Available) {
        Write-WpLog -Message "Lively Wallpaper is not installed on this system." -Level Warning
        return $false
    }

    $proc = Get-Process -Name 'Lively', 'livelycu' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc -and $info.ExePath -and (Test-Path -LiteralPath $info.ExePath)) {
        Write-WpLog -Message "Starting Lively Wallpaper ($($info.ExePath))..." -Level Info
        Start-Process -FilePath $info.ExePath -WindowStyle Hidden
        Start-Sleep -Milliseconds 1200
    }
    return $true
}

function Invoke-LivelyCli {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $info = Get-LivelyInfo
    if (-not $info.Available) {
        Write-WpLog -Message "Lively Wallpaper is unavailable. Cannot execute CLI." -Level Warning
        return $false
    }

    Ensure-LivelyRunning | Out-Null

    $targetExe = if ($info.CliPath -and (Test-Path -LiteralPath $info.CliPath)) {
        $info.CliPath
    } else {
        $info.ExePath
    }

    try {
        Start-Process -FilePath $targetExe -ArgumentList $Arguments -WindowStyle Hidden
        return $true
    } catch {
        Write-WpLog -Message "Failed to execute Lively CLI: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-LivelyCollections {
    return (Get-CollectionFolders -Provider 'Lively')
}

function Set-LivelyWallpaper {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-WpLog -Message "Lively wallpaper target not found: $Path" -Level Warning
        return $false
    }

    $full = [System.IO.Path]::GetFullPath($Path)
    Write-WpLog -Message "Setting Lively wallpaper: $full" -Level Info

    # Official syntax: livelycu.exe setwp --file <path>
    $success = Invoke-LivelyCli -Arguments @('setwp', '--file', $full)
    if ($success) {
        $state = Get-WpState
        $state.currentWallpaper = $full
        $state.activeProvider = 'Lively'
        $null = Save-WpState -State $state
    }
    return $success
}

function Next-LivelyWallpaper {
    param(
        [string]$CollectionName = 'Default',
        [switch]$Random
    )

    $wallpapers = @(Get-CollectionWallpapers -CollectionName $CollectionName -Provider 'Lively')
    if ($wallpapers.Count -eq 0) {
        Write-WpLog -Message "No Lively wallpapers found in collection '$CollectionName'" -Level Warning
        return $null
    }

    $state = Get-WpState
    $current = [string]$state.currentWallpaper
    $currentIndex = -1
    for ($i = 0; $i -lt $wallpapers.Count; $i++) {
        if ($wallpapers[$i].FullName -ieq $current) {
            $currentIndex = $i
            break
        }
    }

    $nextIndex = 0
    if ($Random) {
        if ($wallpapers.Count -gt 1) {
            do {
                $nextIndex = Get-Random -Minimum 0 -Maximum $wallpapers.Count
            } while ($nextIndex -eq $currentIndex)
        } else {
            $nextIndex = 0
        }
    } else {
        $nextIndex = ($currentIndex + 1) % $wallpapers.Count
    }

    $target = $wallpapers[$nextIndex].FullName
    $success = Set-LivelyWallpaper -Path $target
    if ($success) { return $target }
    return $null
}

function Previous-LivelyWallpaper {
    param([string]$CollectionName = 'Default')

    $wallpapers = @(Get-CollectionWallpapers -CollectionName $CollectionName -Provider 'Lively')
    if ($wallpapers.Count -eq 0) {
        Write-WpLog -Message "No Lively wallpapers found in collection '$CollectionName'" -Level Warning
        return $null
    }

    $state = Get-WpState
    $current = [string]$state.currentWallpaper
    $currentIndex = -1
    for ($i = 0; $i -lt $wallpapers.Count; $i++) {
        if ($wallpapers[$i].FullName -ieq $current) {
            $currentIndex = $i
            break
        }
    }

    $prevIndex = if ($currentIndex -le 0) { $wallpapers.Count - 1 } else { $currentIndex - 1 }
    $target = $wallpapers[$prevIndex].FullName
    $success = Set-LivelyWallpaper -Path $target
    if ($success) { return $target }
    return $null
}

function Pause-Lively {
    return (Invoke-LivelyCli -Arguments @('app', '--play', 'false'))
}

function Resume-Lively {
    return (Invoke-LivelyCli -Arguments @('app', '--play', 'true'))
}

function Stop-Lively {
    return (Invoke-LivelyCli -Arguments @('closewp', '--monitor', '-1'))
}

# End of Lively wallpaper provider
