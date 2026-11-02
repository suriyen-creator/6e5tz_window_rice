# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Runtime State Handler
# Persists current wallpaper, active collections, and workspace history
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

function Get-WpState {
    Ensure-DirectoryExists -Path $script:UserConfigDir

    $state = $null
    if (Test-Path -LiteralPath $script:StateFilePath) {
        $state = Read-JsonFile -Path $script:StateFilePath
    }

    if ($null -eq $state) {
        $state = [PSCustomObject]@{
            activeProvider = "Static"
            activeCollection = [PSCustomObject]@{
                Static = "Default"
                WallpaperEngine = "Default"
                Lively = "Default"
            }
            currentWallpaper = ""
            activeWorkspace = "1"
            workspaceHistory = [PSCustomObject]@{}
            rotation = [PSCustomObject]@{
                lastRotated = (Get-Date).ToString('o')
                isPaused = $false
            }
            lastSwitched = (Get-Date).ToString('o')
        }
        $null = Save-WpState -State $state
    }

    # Ensure all required properties exist
    if ($null -eq $state.PSObject.Properties['rotation']) {
        $state | Add-Member -NotePropertyName 'rotation' -NotePropertyValue ([PSCustomObject]@{
            lastRotated = (Get-Date).ToString('o')
            isPaused = $false
        })
    }
    if ($null -eq $state.PSObject.Properties['activeCollection']) {
        $state | Add-Member -NotePropertyName 'activeCollection' -NotePropertyValue ([PSCustomObject]@{
            Static = "Default"
            WallpaperEngine = "Default"
            Lively = "Default"
        })
    }
    if ($null -eq $state.PSObject.Properties['workspaceHistory']) {
        $state | Add-Member -NotePropertyName 'workspaceHistory' -NotePropertyValue ([PSCustomObject]@{})
    }

    return $state
}

function Save-WpState {
    param([Parameter(Mandatory = $true)][object]$State)
    Ensure-DirectoryExists -Path $script:UserConfigDir
    $State.lastSwitched = (Get-Date).ToString('o')
    return (Write-JsonFile -Path $script:StateFilePath -Data $State)
}

function Update-WpWorkspaceState {
    param(
        [Parameter(Mandatory = $true)][string]$WorkspaceId,
        [Parameter(Mandatory = $true)][string]$Provider,
        [Parameter(Mandatory = $true)][string]$Collection,
        [string]$Wallpaper = ""
    )
    $state = Get-WpState
    $historyObj = $state.workspaceHistory

    $entry = [PSCustomObject]@{
        provider = $Provider
        collection = $Collection
        wallpaper = $Wallpaper
        updatedAt = (Get-Date).ToString('o')
    }

    if ($null -ne $historyObj.PSObject.Properties[$WorkspaceId]) {
        $historyObj.$WorkspaceId = $entry
    } else {
        $historyObj.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new($WorkspaceId, $entry))
    }

    $state.activeWorkspace = $WorkspaceId
    $null = Save-WpState -State $state
}

function Get-WpWorkspaceHistory {
    param([Parameter(Mandatory = $true)][string]$WorkspaceId)
    $state = Get-WpState
    if ($null -ne $state.workspaceHistory.PSObject.Properties[$WorkspaceId]) {
        return $state.workspaceHistory.$WorkspaceId
    }
    return $null
}

function Reset-RotationTimer {
    try {
        $state = Get-WpState
        if ($null -eq $state.PSObject.Properties['rotation']) {
            $state | Add-Member -NotePropertyName 'rotation' -NotePropertyValue ([PSCustomObject]@{})
        }
        $state.rotation | Add-Member -NotePropertyName 'lastRotated' -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
        return (Save-WpState -State $state)
    } catch {
        return $false
    }
}

# End of state handler
