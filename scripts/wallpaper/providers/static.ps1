# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Static Wallpaper Provider
# Windows Desktop Wallpaper controller (JPG, PNG, WEBP) via Win32 API
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\common.ps1')
. (Join-Path $PSScriptRoot '..\config.ps1')
. (Join-Path $PSScriptRoot '..\state.ps1')
. (Join-Path $PSScriptRoot '..\collections\folders.ps1')

# Win32 API definition for SystemParametersInfo
$win32Code = @"
using System;
using System.Runtime.InteropServices;
public static class WinWallpaperNative {
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
if (-not ([System.Management.Automation.PSTypeName]'WinWallpaperNative').Type) {
    try {
        Add-Type -TypeDefinition $win32Code -ErrorAction SilentlyContinue
    } catch {}
}

function Test-StaticAvailable {
    return $true
}

function Get-StaticStatus {
    $current = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -ErrorAction SilentlyContinue).Wallpaper
    return [PSCustomObject]@{
        Name = 'Static'
        Available = $true
        Running = $true
        CurrentWallpaper = $current
    }
}

function Get-StaticCollections {
    return (Get-CollectionFolders -Provider 'Static')
}

function Get-StaticCurrentWallpaper {
    $current = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -ErrorAction SilentlyContinue).Wallpaper
    if ([string]::IsNullOrWhiteSpace($current)) {
        $state = Get-WpState
        $current = [string]$state.currentWallpaper
    }
    return $current
}

function Set-StaticWallpaper {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-WpLog -Message "Static wallpaper file not found: $Path" -Level Warning
        return $false
    }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        
        # SPI_SETDESKWALLPAPER = 0x0014, SPIF_UPDATEINIFILE = 0x01, SPIF_SENDCHANGE = 0x02
        [WinWallpaperNative]::SystemParametersInfo(0x0014, 0, $fullPath, 0x01 -bor 0x02) | Out-Null
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $fullPath -Force -ErrorAction SilentlyContinue

        # Update state
        $state = Get-WpState
        $state.currentWallpaper = $fullPath
        $state.activeProvider = 'Static'
        $null = Save-WpState -State $state

        Write-WpLog -Message "Set desktop wallpaper to $fullPath" -Level Success
        return $true
    } catch {
        Write-WpLog -Message "Failed to set static wallpaper: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Next-StaticWallpaper {
    param(
        [string]$CollectionName = 'Default',
        [switch]$Random
    )

    $wallpapers = @(Get-CollectionWallpapers -CollectionName $CollectionName -Provider 'Static')
    if ($wallpapers.Count -eq 0) {
        Write-WpLog -Message "No wallpapers found in collection '$CollectionName'" -Level Warning
        return $null
    }

    $current = Get-StaticCurrentWallpaper
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
    $success = Set-StaticWallpaper -Path $target
    if ($success) { return $target }
    return $null
}

function Previous-StaticWallpaper {
    param([string]$CollectionName = 'Default')

    $wallpapers = @(Get-CollectionWallpapers -CollectionName $CollectionName -Provider 'Static')
    if ($wallpapers.Count -eq 0) {
        Write-WpLog -Message "No wallpapers found in collection '$CollectionName'" -Level Warning
        return $null
    }

    $current = Get-StaticCurrentWallpaper
    $currentIndex = -1
    for ($i = 0; $i -lt $wallpapers.Count; $i++) {
        if ($wallpapers[$i].FullName -ieq $current) {
            $currentIndex = $i
            break
        }
    }

    $prevIndex = if ($currentIndex -le 0) { $wallpapers.Count - 1 } else { $currentIndex - 1 }
    $target = $wallpapers[$prevIndex].FullName
    $success = Set-StaticWallpaper -Path $target
    if ($success) { return $target }
    return $null
}

function Toggle-StaticFavorite {
    param([string]$Path = '')
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Get-StaticCurrentWallpaper
    }
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $config = Get-WpConfig
    $favList = [System.Collections.Generic.List[string]]::new()
    if ($null -ne $config.PSObject.Properties['favorites']) {
        foreach ($f in @($config.favorites)) {
            if (-not [string]::IsNullOrWhiteSpace($f)) { $favList.Add($f) }
        }
    }

    $isFav = $favList.Contains($Path)
    if ($isFav) {
        [void]$favList.Remove($Path)
        Write-WpLog -Message "Removed from favorites: $Path" -Level Info
    } else {
        $favList.Add($Path)
        Write-WpLog -Message "Added to favorites: $Path" -Level Success
    }

    $config.favorites = @($favList)
    $null = Save-WpConfig -Config $config
    return (-not $isFav)
}

# End of static wallpaper provider
