# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Configuration Handler
# Load, validate, defaults, migrations, and atomic persistence
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

function Get-DefaultConfigPath {
    $repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $defaultFile = Join-Path $repoRoot 'configs\wallpaper\manager.default.json'
    if (Test-Path -LiteralPath $defaultFile) {
        return $defaultFile
    }
    return $null
}

function Expand-ConfigPaths {
    param([Parameter(Mandatory = $true)][object]$Config)
    
    $userSlash = ($env:USERPROFILE).Replace('\', '/')
    $userBack = $env:USERPROFILE

    if ($null -ne $Config.PSObject.Properties['collectionRoot'] -and [string]$Config.collectionRoot) {
        $Config.collectionRoot = [string]$Config.collectionRoot -replace '__USERPROFILE__', $userBack
        $Config.collectionRoot = [string]$Config.collectionRoot -replace '/', '\'
    }

    if ($null -ne $Config.PSObject.Properties['collections']) {
        foreach ($col in @($Config.collections)) {
            if ($null -ne $col.PSObject.Properties['path'] -and [string]$col.path) {
                $col.path = [string]$col.path -replace '__USERPROFILE__', $userBack
                $col.path = [string]$col.path -replace '/', '\'
            }
        }
    }

    return $Config
}

function Get-WpConfig {
    Ensure-DirectoryExists -Path $script:UserConfigDir

    $config = $null
    if (Test-Path -LiteralPath $script:ConfigFilePath) {
        $config = Read-JsonFile -Path $script:ConfigFilePath
    }

    if ($null -eq $config) {
        $defaultPath = Get-DefaultConfigPath
        if ($defaultPath) {
            $config = Read-JsonFile -Path $defaultPath
        }

        # Fallback in-memory defaults if file missing
        if ($null -eq $config) {
            $config = [PSCustomObject]@{
                version = "1.0.0"
                provider = "Static"
                collectionRoot = (Join-Path $env:USERPROFILE 'Pictures\Wallpapers')
                collections = @(
                    [PSCustomObject]@{
                        name = "Default"
                        path = (Join-Path $env:USERPROFILE 'Pictures\Wallpapers')
                        provider = "Static"
                    }
                )
                workspaceMapping = [PSCustomObject]@{
                    "1" = [PSCustomObject]@{ provider = "Static"; collection = "Default" }
                    "2" = [PSCustomObject]@{ provider = "Static"; collection = "Default" }
                    "3" = [PSCustomObject]@{ provider = "Static"; collection = "Default" }
                    "4" = [PSCustomObject]@{ provider = "Static"; collection = "Default" }
                    "5" = [PSCustomObject]@{ provider = "Static"; collection = "Default" }
                    "6" = [PSCustomObject]@{ provider = "Static"; collection = "Default" }
                    "7" = [PSCustomObject]@{ provider = "Static"; collection = "Default" }
                    "8" = [PSCustomObject]@{ provider = "Static"; collection = "Default" }
                    "9" = [PSCustomObject]@{ provider = "Static"; collection = "Default" }
                }
                favorites = @()
                ui = [PSCustomObject]@{
                    position = "right"
                    width = 420
                    acrylic = $true
                    autoHideOnFocusLost = $true
                    closeOnOutsideClick = $true
                    animation = $true
                    launchMode = "grid"
                    coverFlow = [PSCustomObject]@{
                        fullscreen = $true
                        backgroundBlur = $true
                        darkOverlayOpacity = 0.55
                    }
                    viewMode = [PSCustomObject]@{
                        WallpaperEngine = "coverflow"
                        Static = "grid"
                        Lively = "coverflow"
                    }
                }
                rotation = [PSCustomObject]@{
                    enabled = $false
                    intervalMinutes = 30
                    pauseWhileBrowsing = $true
                    resumeAfterSleep = $true
                }
                debounceMs = 350
                historyLimit = 50
                autoStartWatcher = $true
            }
        }

        # Save freshly initialized config to user profile
        $null = Save-WpConfig -Config $config
    }

    # Ensure ui and rotation blocks exist on existing configurations
    if ($null -eq $config.PSObject.Properties['ui']) {
        $config | Add-Member -MemberType NoteProperty -Name 'ui' -Value ([PSCustomObject]@{
            position = "right"
            width = 420
            acrylic = $true
            autoHideOnFocusLost = $true
            closeOnOutsideClick = $true
            animation = $true
            launchMode = "grid"
            coverFlow = [PSCustomObject]@{
                fullscreen = $true
                backgroundBlur = $true
                darkOverlayOpacity = 0.55
            }
            viewMode = [PSCustomObject]@{
                WallpaperEngine = "coverflow"
                Static = "grid"
                Lively = "coverflow"
            }
        })
    } else {
        if ($null -eq $config.ui.PSObject.Properties['launchMode'] -or @('grid', 'coverFlow') -notcontains [string]$config.ui.launchMode) {
            if ($null -eq $config.ui.PSObject.Properties['launchMode']) {
                $config.ui | Add-Member -MemberType NoteProperty -Name 'launchMode' -Value 'grid'
            } else {
                $config.ui.launchMode = 'grid'
            }
        }
        if ($null -eq $config.ui.PSObject.Properties['coverFlow']) {
            $config.ui | Add-Member -MemberType NoteProperty -Name 'coverFlow' -Value ([PSCustomObject]@{
                fullscreen = $true
                backgroundBlur = $true
                darkOverlayOpacity = 0.55
            })
        }
        if ($null -eq $config.ui.PSObject.Properties['viewMode']) {
            $config.ui | Add-Member -MemberType NoteProperty -Name 'viewMode' -Value ([PSCustomObject]@{
                WallpaperEngine = "coverflow"
                Static = "grid"
                Lively = "coverflow"
            })
        }
    }

    if ($null -eq $config.PSObject.Properties['rotation']) {
        $config | Add-Member -MemberType NoteProperty -Name 'rotation' -Value ([PSCustomObject]@{
            enabled = $false
            intervalMinutes = 30
            pauseWhileBrowsing = $true
            resumeAfterSleep = $true
        })
    }

    $config = Expand-ConfigPaths -Config $config

    # Validate provider name
    $validProviders = @('Static', 'WallpaperEngine', 'Lively')
    if ($validProviders -notcontains [string]$config.provider) {
        $config.provider = 'Static'
    }

    # Ensure collectionRoot exists on disk
    if (-not [string]::IsNullOrWhiteSpace([string]$config.collectionRoot)) {
        Ensure-DirectoryExists -Path ([string]$config.collectionRoot)
    }

    return $config
}

function Save-WpConfig {
    param([Parameter(Mandatory = $true)][object]$Config)
    Ensure-DirectoryExists -Path $script:UserConfigDir
    return (Write-JsonFile -Path $script:ConfigFilePath -Data $Config)
}

# End of config handler
