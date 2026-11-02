# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Folder-Based Collections System
# Manages collections, file discovery, filtering, validation, and caching
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\common.ps1')
. (Join-Path $PSScriptRoot '..\config.ps1')

$script:StaticExtensions = @('.jpg', '.jpeg', '.png', '.webp')
$script:LivelyExtensions = @('.mp4', '.webm', '.zip')
$script:CollectionCache = @{}
$script:CollectionCacheTime = @{}
$script:CacheTtlSeconds = 60

function Get-SupportedExtensions {
    param([Parameter(Mandatory = $true)][string]$Provider)
    switch ($Provider) {
        'Lively'          { return $script:LivelyExtensions }
        'WallpaperEngine' { return @('.pkg', '.json', '.mp4', '.webm') }
        default           { return $script:StaticExtensions }
    }
}

function Get-CollectionFolders {
    param(
        [string]$Provider = 'Static',
        [switch]$ForceRefresh
    )

    $config = Get-WpConfig
    $root = if ($null -ne $config.PSObject.Properties['collectionRoot']) { [string]$config.collectionRoot } else { '' }
    if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root -PathType Container)) {
        $root = Join-Path $env:USERPROFILE 'Pictures\Wallpapers'
        Ensure-DirectoryExists -Path $root
    }

    $collections = [System.Collections.Generic.List[object]]::new()
    $seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # 1. Check if Root contains direct wallpaper files
    $exts = Get-SupportedExtensions -Provider $Provider
    $rootFiles = @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue | Where-Object {
        $exts -contains $_.Extension.ToLowerInvariant()
    })

    if ($rootFiles.Count -gt 0) {
        $collections.Add([PSCustomObject]@{
            Name = 'Default'
            Path = $root
            Provider = $Provider
            ItemCount = $rootFiles.Count
            IsRoot = $true
        })
        [void]$seenPaths.Add($root)
    }

    # 2. Check Subfolders of Root
    $subfolders = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notmatch '(?i)^(\.git|\.cache|\.temp|thumbs)$'
    })

    foreach ($sub in $subfolders) {
        if (-not $seenPaths.Contains($sub.FullName)) {
            # Count valid files inside
            $files = @(Get-ChildItem -LiteralPath $sub.FullName -File -ErrorAction SilentlyContinue | Where-Object {
                $exts -contains $_.Extension.ToLowerInvariant()
            })
            $collections.Add([PSCustomObject]@{
                Name = $sub.Name
                Path = $sub.FullName
                Provider = $Provider
                ItemCount = $files.Count
                IsRoot = $false
            })
            [void]$seenPaths.Add($sub.FullName)
        }
    }

    # 3. User configured custom collections from config.json
    if ($null -ne $config.PSObject.Properties['collections']) {
        foreach ($c in @($config.collections)) {
            $cPath = [string]$c.path
            $cName = [string]$c.name
            $cProvider = if ($null -ne $c.PSObject.Properties['provider']) { [string]$c.provider } else { 'Static' }

            if ($cProvider -eq $Provider -and (Test-Path -LiteralPath $cPath -PathType Container)) {
                if (-not $seenPaths.Contains($cPath)) {
                    $files = @(Get-ChildItem -LiteralPath $cPath -File -ErrorAction SilentlyContinue | Where-Object {
                        $exts -contains $_.Extension.ToLowerInvariant()
                    })
                    $collections.Add([PSCustomObject]@{
                        Name = $cName
                        Path = $cPath
                        Provider = $cProvider
                        ItemCount = $files.Count
                        IsRoot = $false
                    })
                    [void]$seenPaths.Add($cPath)
                }
            }
        }
    }

    # If no collections found, ensure at least one empty Default collection is returned
    if ($collections.Count -eq 0) {
        $collections.Add([PSCustomObject]@{
            Name = 'Default'
            Path = $root
            Provider = $Provider
            ItemCount = 0
            IsRoot = $true
        })
    }

    return @($collections)
}

function Get-CollectionWallpapers {
    param(
        [Parameter(Mandatory = $true)][string]$CollectionName,
        [string]$Provider = 'Static',
        [switch]$ForceRefresh
    )

    $cacheKey = "${Provider}:${CollectionName}"
    $now = [System.DateTime]::UtcNow

    if (-not $ForceRefresh -and $script:CollectionCache.ContainsKey($cacheKey)) {
        $cachedTime = $script:CollectionCacheTime[$cacheKey]
        if (($now - $cachedTime).TotalSeconds -lt $script:CacheTtlSeconds) {
            return $script:CollectionCache[$cacheKey]
        }
    }

    $folders = Get-CollectionFolders -Provider $Provider -ForceRefresh:$ForceRefresh
    $matched = $folders | Where-Object { $_.Name -ieq $CollectionName } | Select-Object -First 1

    if (-not $matched) {
        $matched = $folders | Select-Object -First 1
    }

    if (-not $matched -or -not (Test-Path -LiteralPath $matched.Path -PathType Container)) {
        return @()
    }

    $exts = Get-SupportedExtensions -Provider $Provider
    $files = @(Get-ChildItem -LiteralPath $matched.Path -File -ErrorAction SilentlyContinue | Where-Object {
        $exts -contains $_.Extension.ToLowerInvariant()
    } | Sort-Object Name)

    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($f in $files) {
        $items.Add([PSCustomObject]@{
            Name = $f.Name
            FullName = $f.FullName
            Extension = $f.Extension.ToLowerInvariant()
            Size = $f.Length
            LastModified = $f.LastWriteTimeUtc
            Collection = $matched.Name
            Provider = $Provider
        })
    }

    $script:CollectionCache[$cacheKey] = @($items)
    $script:CollectionCacheTime[$cacheKey] = $now

    return @($items)
}

function Add-CollectionFolder {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Provider = 'Static'
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Ensure-DirectoryExists -Path $Path
    }

    $config = Get-WpConfig
    $list = [System.Collections.Generic.List[object]]::new()
    if ($null -ne $config.PSObject.Properties['collections']) {
        foreach ($c in @($config.collections)) {
            if ($c.name -ine $Name -and $c.path -ine $Path) {
                $list.Add($c)
            }
        }
    }
    $list.Add([PSCustomObject]@{
        name = $Name
        path = $Path
        provider = $Provider
    })
    $config.collections = @($list)
    Save-WpConfig -Config $config
    Clear-CollectionCache
    Write-WpLog -Message "Added collection '$Name' -> '$Path'" -Level Success
    return $true
}

function Remove-CollectionFolder {
    param([Parameter(Mandatory = $true)][string]$Name)
    $config = Get-WpConfig
    $list = [System.Collections.Generic.List[object]]::new()
    if ($null -ne $config.PSObject.Properties['collections']) {
        foreach ($c in @($config.collections)) {
            if ($c.name -ine $Name) {
                $list.Add($c)
            }
        }
    }
    $config.collections = @($list)
    Save-WpConfig -Config $config
    Clear-CollectionCache
    Write-WpLog -Message "Removed collection '$Name' from configuration" -Level Success
    return $true
}

function Rename-CollectionFolder {
    param(
        [Parameter(Mandatory = $true)][string]$OldName,
        [Parameter(Mandatory = $true)][string]$NewName
    )
    $config = Get-WpConfig
    if ($null -ne $config.PSObject.Properties['collections']) {
        foreach ($c in @($config.collections)) {
            if ($c.name -ieq $OldName) {
                $c.name = $NewName
            }
        }
    }
    Save-WpConfig -Config $config
    Clear-CollectionCache
    Write-WpLog -Message "Renamed collection '$OldName' to '$NewName'" -Level Success
    return $true
}

function Clear-CollectionCache {
    $script:CollectionCache.Clear()
    $script:CollectionCacheTime.Clear()
}

# End of folders collections module
