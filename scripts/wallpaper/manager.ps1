# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Unified Orchestrator & CLI Facade
# Engine switching, collections management, workspace routing, and concurrency lock
# ==============================================================================

[CmdletBinding()]
param(
    [ValidateSet('next', 'prev', 'shuffle', 'set', 'provider', 'collection', 'workspace', 'status', 'gallery', 'pause', 'resume', 'toggle-pause', 'open-ui', 'cycle-provider')]
    [string]$Action = 'next',

    [ValidateSet('Static', 'WallpaperEngine', 'Lively', 'Auto', '')]
    [string]$Provider = '',

    [string]$Collection = '',
    [string]$Path = '',
    [string]$Workspace = '',

    # Legacy parameter support
    [ValidateSet('Static', 'WallpaperEngine', 'Lively', 'Auto', '')]
    [string]$Mode = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'config.ps1')
. (Join-Path $PSScriptRoot 'state.ps1')
. (Join-Path $PSScriptRoot 'detection.ps1')
. (Join-Path $PSScriptRoot 'collections\folders.ps1')
. (Join-Path $PSScriptRoot 'providers\static.ps1')
. (Join-Path $PSScriptRoot 'providers\wallpaper-engine.ps1')
. (Join-Path $PSScriptRoot 'providers\lively.ps1')
. (Join-Path $PSScriptRoot 'workspace\watcher.ps1')

# Reconcile Mode with Provider for backward compatibility
if ([string]::IsNullOrWhiteSpace($Provider) -and -not [string]::IsNullOrWhiteSpace($Mode)) {
    $Provider = $Mode
}

function Get-ActiveProviderName {
    $state = Get-WpState
    $prov = if (-not [string]::IsNullOrWhiteSpace($state.activeProvider)) { $state.activeProvider } else { 'Static' }
    
    # Verify provider availability; fallback to Static if missing
    if ($prov -ne 'Static' -and -not (Test-ProviderAvailable -Name $prov)) {
        Write-WpLog -Message "Configured provider '$prov' is unavailable. Falling back to Static." -Level Warning
        $prov = 'Static'
        $state.activeProvider = 'Static'
        Save-WpState -State $state
    }
    return $prov
}

function Get-ActiveCollectionName {
    param([string]$ProviderName)
    $state = Get-WpState
    $col = 'Default'
    if ($null -ne $state.activeCollection.PSObject.Properties[$ProviderName]) {
        $cVal = [string]$state.activeCollection.$ProviderName
        if (-not [string]::IsNullOrWhiteSpace($cVal)) { $col = $cVal }
    }
    return $col
}

function Set-ActiveCollectionName {
    param(
        [Parameter(Mandatory = $true)][string]$ProviderName,
        [Parameter(Mandatory = $true)][string]$CollectionName
    )
    $state = Get-WpState
    if ($null -ne $state.activeCollection.PSObject.Properties[$ProviderName]) {
        $state.activeCollection.$ProviderName = $CollectionName
    } else {
        $state.activeCollection.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new($ProviderName, $CollectionName))
    }
    $null = Save-WpState -State $state
    Write-WpLog -Message "Active collection for $ProviderName set to: $CollectionName" -Level Success
}

function Resolve-TargetStaticWallpaper {
    $config = Get-WpConfig
    $state = Get-WpState

    # Step 1: Resolve current workspace ID
    $wsId = '1'
    try {
        $glazeWs = Query-CurrentGlazeWorkspace
        if (-not [string]::IsNullOrWhiteSpace($glazeWs)) {
            $wsId = $glazeWs
        }
    } catch {}

    if ([string]::IsNullOrWhiteSpace($wsId) -and $null -ne $state.PSObject.Properties['activeWorkspace'] -and -not [string]::IsNullOrWhiteSpace($state.activeWorkspace)) {
        $wsId = [string]$state.activeWorkspace
    }

    # Step 2: Check workspace mapping
    $targetCol = 'Default'
    if ($null -ne $config.PSObject.Properties['workspaceMapping'] -and $null -ne $config.workspaceMapping.PSObject.Properties[$wsId]) {
        $m = $config.workspaceMapping.$wsId
        if ($null -ne $m.PSObject.Properties['collection'] -and -not [string]::IsNullOrWhiteSpace($m.collection)) {
            $targetCol = [string]$m.collection
        }
    } else {
        $targetCol = Get-ActiveCollectionName -ProviderName 'Static'
    }

    # Step 3: Check workspace history
    $hist = Get-WpWorkspaceHistory -WorkspaceId $wsId
    if ($null -ne $hist -and -not [string]::IsNullOrWhiteSpace([string]$hist.wallpaper) -and (Test-Path -LiteralPath [string]$hist.wallpaper)) {
        return [string]$hist.wallpaper
    }

    # Step 4: Check if current wallpaper in state is valid and belongs to collection
    if ($null -ne $state.PSObject.Properties['currentWallpaper'] -and -not [string]::IsNullOrWhiteSpace($state.currentWallpaper) -and (Test-Path -LiteralPath $state.currentWallpaper)) {
        $curr = [string]$state.currentWallpaper
        if ($curr -match '\.(jpg|jpeg|png|webp|bmp)$') {
            return $curr
        }
    }

    # Step 5: First valid wallpaper in collection folder
    try {
        $files = Get-CollectionFiles -CollectionName $targetCol
        if ($files.Count -gt 0) {
            return $files[0].FullName
        }
    } catch {}

    # Step 6: First valid image in collectionRoot
    try {
        if (-not [string]::IsNullOrWhiteSpace($config.collectionRoot) -and (Test-Path -LiteralPath $config.collectionRoot)) {
            $rootFiles = @(Get-ChildItem -Path $config.collectionRoot -File | Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|webp|bmp)$' })
            if ($rootFiles.Count -gt 0) {
                return $rootFiles[0].FullName
            }
        }
    } catch {}

    return $null
}

function Open-WallpaperSidePanel {
    param(
        [string]$Notice = '',
        [string]$Provider = ''
    )
    try {
        $panelCandidates = @(
            (Join-Path $env:USERPROFILE '.config\yasb\scripts\wallpaper-gallery.exe'),
            (Join-Path $env:USERPROFILE '.config\yasb\scripts\WallpaperSidePanel.exe'),
            (Join-Path $PSScriptRoot '..\..\configs\yasb\scripts\wallpaper-gallery.exe'),
            (Join-Path $PSScriptRoot '..\..\configs\yasb\scripts\WallpaperSidePanel.exe')
        )
        $panelExe = $panelCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($panelExe) {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $panelExe
            $argsList = [System.Collections.Generic.List[string]]::new()
            if (-not [string]::IsNullOrWhiteSpace($Notice)) {
                $argsList.Add("-Notice")
                $argsList.Add("`"$Notice`"")
            }
            if (-not [string]::IsNullOrWhiteSpace($Provider)) {
                $argsList.Add("-Provider")
                $argsList.Add("`"$Provider`"")
            }
            $psi.Arguments = $argsList -join ' '
            $psi.CreateNoWindow = $true
            $psi.UseShellExecute = $false
            $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        }
    } catch {
        Write-WpDiagnosticLog -Category 'CYCLE_PROVIDER' -Message "Failed to launch Side Panel notice: $($_.Exception.Message)"
    }
}

function Switch-Provider {
    param([Parameter(Mandatory = $true)][string]$NewProvider)

    if ($NewProvider -eq 'Auto') {
        $weInfo = Detect-WallpaperEngine
        $NewProvider = if ($weInfo.Available) { 'WallpaperEngine' } else { 'Static' }
    }

    if ($NewProvider -ne 'Static' -and -not (Test-ProviderAvailable -Name $NewProvider)) {
        Write-WpLog -Message "Provider '$NewProvider' is not installed or available on this system." -Level Warning
        return $false
    }

    $currentProvider = Get-ActiveProviderName
    if ($currentProvider -eq $NewProvider) {
        Write-WpLog -Message "Provider is already $NewProvider." -Level Info
        return $true
    }

    Write-WpLog -Message "Switching wallpaper provider: $currentProvider -> $NewProvider" -Level Info

    # Cleanly stop previous engine to unhook/clear render window
    if ($currentProvider -eq 'WallpaperEngine') {
        try { Stop-WallpaperEngine | Out-Null } catch {}
    } elseif ($currentProvider -eq 'Lively') {
        try { Stop-Lively | Out-Null } catch {}
    }

    # Activate new provider
    $state = Get-WpState
    $state.activeProvider = $NewProvider
    $state.lastSwitched = [System.DateTime]::Now.ToString('o')
    $null = Save-WpState -State $state

    $config = Get-WpConfig
    $config.provider = $NewProvider
    $null = Save-WpConfig -Config $config

    $col = Get-ActiveCollectionName -ProviderName $NewProvider
    switch ($NewProvider) {
        'Static' {
            $targetWp = Resolve-TargetStaticWallpaper
            if ($targetWp -and (Test-Path -LiteralPath $targetWp)) {
                Set-StaticWallpaper -Path $targetWp | Out-Null
            } else {
                Next-StaticWallpaper -CollectionName $col | Out-Null
            }
            # Enforce unhooking of Wallpaper Engine hook window
            try { Stop-WallpaperEngine | Out-Null } catch {}
        }
        'WallpaperEngine' {
            Ensure-WallpaperEngineRunning | Out-Null
            $weTarget = if ($null -ne $state.PSObject.Properties['activeCollection'] -and $null -ne $state.activeCollection.PSObject.Properties['WallpaperEngine']) {
                [string]$state.activeCollection.WallpaperEngine
            } else { 'Default' }

            if ($weTarget -and $weTarget -ne 'Default') {
                Set-WallpaperEngineWallpaper -PathOrPlaylist $weTarget | Out-Null
            } else {
                $pls = Get-WallpaperEnginePlaylists
                if ($pls.Count -gt 0) {
                    Set-WallpaperEngineWallpaper -PathOrPlaylist $pls[0].Name | Out-Null
                } else {
                    Resume-WallpaperEngine | Out-Null
                }
            }
        }
        'Lively' {
            Ensure-LivelyRunning | Out-Null
            Resume-Lively | Out-Null
        }
    }

    Write-WpLog -Message "Successfully switched provider to $NewProvider." -Level Success
    return $true
}

function Cycle-NextProvider {
    $providers = Get-WallpaperProviders
    $order = @('Static', 'WallpaperEngine', 'Lively')
    $current = Get-ActiveProviderName
    $idx = [array]::IndexOf($order, $current)
    if ($idx -lt 0) { $idx = 0 }

    $availNames = @($providers.Keys | Where-Object { $providers[$_].Available })
    Write-WpDiagnosticLog -Category 'CYCLE_PROVIDER' -Message "Shortcut received. Current provider: $current | Available providers: $($availNames -join ', ')"

    for ($i = 1; $i -le $order.Count; $i++) {
        $nextIdx = ($idx + $i) % $order.Count
        $candidate = $order[$nextIdx]
        if ($providers[$candidate].Available) {
            Write-WpDiagnosticLog -Category 'CYCLE_PROVIDER' -Message "Selected next provider: $candidate. Executing switch..."
            try {
                $switchResult = Switch-Provider -NewProvider $candidate
                Write-WpDiagnosticLog -Category 'CYCLE_PROVIDER' -Message "Switching result: $switchResult | Active provider is now $candidate"
                
                # Open Floating Side Panel with visual feedback
                Open-WallpaperSidePanel -Notice "Switched to $candidate Wallpaper" -Provider $candidate

                return $candidate
            } catch {
                Write-WpDiagnosticLog -Category 'CYCLE_PROVIDER' -Message "Switching failed for $candidate" -ErrorDetails $_.Exception.Message
                return $current
            }
        }
    }
    Write-WpDiagnosticLog -Category 'CYCLE_PROVIDER' -Message "No alternative available provider found. Keeping $current."
    return $current
}

function Show-StatusSummary {
    $state = Get-WpState
    $config = Get-WpConfig
    $providers = Get-WallpaperProviders

    Write-Host "`n=======================================================" -ForegroundColor Cyan
    Write-Host "   6e5tz Universal Wallpaper Manager Status            " -ForegroundColor Magenta
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host (" Active Provider  : {0}" -f $state.activeProvider) -ForegroundColor Green
    Write-Host (" Collection Root  : {0}" -f $config.collectionRoot) -ForegroundColor Yellow
    Write-Host (" Current Target   : {0}" -f $state.currentWallpaper) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available Providers:" -ForegroundColor White
    foreach ($p in $providers.Keys) {
        $info = $providers[$p]
        $statusStr = if ($info.Available) {
            if ($info.Running) { "[ACTIVE / RUNNING]" } else { "[AVAILABLE]" }
        } else {
            "[NOT INSTALLED]"
        }
        $col = if ($info.Available) { 'Green' } else { 'DarkGray' }
        Write-Host ("  - {0,-16} : {1,-18} ({2})" -f $info.DisplayName, $statusStr, $info.Description) -ForegroundColor $col
    }
    Write-Host ""
    Write-Host "Collections (Active Provider):" -ForegroundColor White
    $cols = Get-CollectionFolders -Provider $state.activeProvider
    foreach ($c in $cols) {
        $activeBadge = if ($c.Name -eq (Get-ActiveCollectionName -ProviderName $state.activeProvider)) { "*" } else { " " }
        Write-Host ("  [{0}] {1,-14} : {2,3} items ({3})" -f $activeBadge, $c.Name, $c.ItemCount, $c.Path) -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Workspace Mappings:" -ForegroundColor White
    if ($null -ne $config.PSObject.Properties['workspaceMapping']) {
        foreach ($prop in $config.workspaceMapping.PSObject.Properties) {
            $m = $prop.Value
            $pName = if ($null -ne $m.PSObject.Properties['provider']) { $m.provider } else { 'Static' }
            $cName = if ($null -ne $m.PSObject.Properties['collection']) { $m.collection } else { 'Default' }
            Write-Host ("  Workspace {0,-2} -> Provider: {1,-15} Collection: {2}" -f $prop.Name, $pName, $cName) -ForegroundColor Cyan
        }
    }
    Write-Host "=======================================================`n" -ForegroundColor Cyan
}

function Switch-WorkspaceWallpaper {
    param([Parameter(Mandatory = $true)][string]$WorkspaceId)

    $config = Get-WpConfig
    $mappings = $config.workspaceMapping
    if ($null -eq $mappings -or $null -eq $mappings.PSObject.Properties[$WorkspaceId]) {
        Write-WpLog -Message "No wallpaper mapping defined for Workspace $WorkspaceId. Preserving current wallpaper." -Level Debug
        return $false
    }

    $map = $mappings.$WorkspaceId
    $targetProvider = if ($null -ne $map.PSObject.Properties['provider']) { [string]$map.provider } else { 'Static' }
    $targetCollection = if ($null -ne $map.PSObject.Properties['collection']) { [string]$map.collection } else { 'Default' }

    if (-not (Test-ProviderAvailable -Name $targetProvider)) {
        Write-WpLog -Message "Workspace $WorkspaceId mapped to unavailable provider '$targetProvider'. Falling back to Static." -Level Warning
        $targetProvider = 'Static'
    }

    Write-WpLog -Message "Applying Workspace $WorkspaceId mapping: [$targetProvider] '$targetCollection'" -Level Info

    # Switch provider if needed
    if ((Get-ActiveProviderName) -ne $targetProvider) {
        Switch-Provider -NewProvider $targetProvider | Out-Null
    }

    # Set collection
    Set-ActiveCollectionName -ProviderName $targetProvider -CollectionName $targetCollection

    # Check if this workspace has a remembered last wallpaper
    $lastHist = Get-WpWorkspaceHistory -WorkspaceId $WorkspaceId
    $appliedWallpaper = $null

    if ($null -ne $lastHist -and -not [string]::IsNullOrWhiteSpace([string]$lastHist.wallpaper) -and (Test-Path -LiteralPath [string]$lastHist.wallpaper)) {
        $lastWp = [string]$lastHist.wallpaper
        switch ($targetProvider) {
            'Static' { 
                Set-StaticWallpaper -Path $lastWp | Out-Null
                try { Stop-WallpaperEngine | Out-Null } catch {}
                $appliedWallpaper = $lastWp 
            }
            'WallpaperEngine' { Set-WallpaperEngineWallpaper -PathOrPlaylist $lastWp | Out-Null; $appliedWallpaper = $lastWp }
            'Lively' { Set-LivelyWallpaper -Path $lastWp | Out-Null; $appliedWallpaper = $lastWp }
        }
    } else {
        # Advance to next in collection
        switch ($targetProvider) {
            'Static' { 
                $appliedWallpaper = Next-StaticWallpaper -CollectionName $targetCollection 
                try { Stop-WallpaperEngine | Out-Null } catch {}
            }
            'WallpaperEngine' { $appliedWallpaper = Next-WallpaperEngineWallpaper -CollectionName $targetCollection }
            'Lively' { $appliedWallpaper = Next-LivelyWallpaper -CollectionName $targetCollection }
        }
    }

    $wpTarget = if ($null -ne $appliedWallpaper) { [string]$appliedWallpaper } else { "" }
    Update-WpWorkspaceState -WorkspaceId $WorkspaceId -Provider $targetProvider -Collection $targetCollection -Wallpaper $wpTarget
    return $true
}

# -----------------------------------------------------------------------------
# Main Action Dispatcher
# -----------------------------------------------------------------------------
if ($MyInvocation.InvocationName -eq '.') {
    return
}

switch ($Action) {
    'status' {
        Show-StatusSummary
    }
    'provider' {
        if (-not [string]::IsNullOrWhiteSpace($Provider)) {
            Switch-Provider -NewProvider $Provider
        } else {
            Get-ActiveProviderName
        }
    }
    'cycle-provider' {
        Invoke-WithWallpaperLock -Script {
            Cycle-NextProvider
        }
    }
    'collection' {
        $p = if (-not [string]::IsNullOrWhiteSpace($Provider)) { $Provider } else { Get-ActiveProviderName }
        if (-not [string]::IsNullOrWhiteSpace($Collection)) {
            Set-ActiveCollectionName -ProviderName $p -CollectionName $Collection
        } else {
            Get-ActiveCollectionName -ProviderName $p
        }
    }
    'workspace' {
        if ([string]::IsNullOrWhiteSpace($Workspace)) {
            Write-WpLog -Message "Workspace identifier is required for action 'workspace'." -Level Warning
            exit 1
        }
        Invoke-WithWallpaperLock -Script {
            Switch-WorkspaceWallpaper -WorkspaceId $Workspace
        }
    }
    'next' {
        # Critical Alt + W handler with debouncing and concurrency lock
        Invoke-WithWallpaperLock -Script {
            $p = if (-not [string]::IsNullOrWhiteSpace($Provider)) { $Provider } else { Get-ActiveProviderName }
            $c = if (-not [string]::IsNullOrWhiteSpace($Collection)) { $Collection } else { Get-ActiveCollectionName -ProviderName $p }
            
            switch ($p) {
                'WallpaperEngine' { Next-WallpaperEngineWallpaper -CollectionName $c }
                'Lively'          { Next-LivelyWallpaper -CollectionName $c }
                default           { Next-StaticWallpaper -CollectionName $c }
            }
        }
    }
    'prev' {
        Invoke-WithWallpaperLock -Script {
            $p = if (-not [string]::IsNullOrWhiteSpace($Provider)) { $Provider } else { Get-ActiveProviderName }
            $c = if (-not [string]::IsNullOrWhiteSpace($Collection)) { $Collection } else { Get-ActiveCollectionName -ProviderName $p }

            switch ($p) {
                'WallpaperEngine' { Next-WallpaperEngineWallpaper -CollectionName $c } # WE CLI only supports nextWallpaper
                'Lively'          { Previous-LivelyWallpaper -CollectionName $c }
                default           { Previous-StaticWallpaper -CollectionName $c }
            }
        }
    }
    'shuffle' {
        Invoke-WithWallpaperLock -Script {
            $p = if (-not [string]::IsNullOrWhiteSpace($Provider)) { $Provider } else { Get-ActiveProviderName }
            $c = if (-not [string]::IsNullOrWhiteSpace($Collection)) { $Collection } else { Get-ActiveCollectionName -ProviderName $p }

            switch ($p) {
                'WallpaperEngine' { Next-WallpaperEngineWallpaper -CollectionName $c }
                'Lively'          { Next-LivelyWallpaper -CollectionName $c -Random }
                default           { Next-StaticWallpaper -CollectionName $c -Random }
            }
        }
    }
    'set' {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            Write-WpLog -Message "Path parameter is required for action 'set'." -Level Warning
            exit 1
        }
        $p = if (-not [string]::IsNullOrWhiteSpace($Provider)) { $Provider } else { Get-ActiveProviderName }
        switch ($p) {
            'WallpaperEngine' { Set-WallpaperEngineWallpaper -PathOrPlaylist $Path }
            'Lively'          { Set-LivelyWallpaper -Path $Path }
            default           { Set-StaticWallpaper -Path $Path }
        }
    }
    'pause' {
        $p = Get-ActiveProviderName
        switch ($p) {
            'WallpaperEngine' { Pause-WallpaperEngine }
            'Lively'          { Pause-Lively }
        }
    }
    'resume' {
        $p = Get-ActiveProviderName
        switch ($p) {
            'WallpaperEngine' { Resume-WallpaperEngine }
            'Lively'          { Resume-Lively }
        }
    }
    'toggle-pause' {
        $p = Get-ActiveProviderName
        $stateFile = Join-Path $env:TEMP '6e5tz_wp_pause.txt'
        $curr = if (Test-Path $stateFile) { (Get-Content $stateFile -Raw).Trim() } else { 'playing' }
        if ($curr -eq 'paused') {
            if ($p -eq 'WallpaperEngine') { Resume-WallpaperEngine }
            elseif ($p -eq 'Lively') { Resume-Lively }
            Set-Content -Path $stateFile -Value 'playing' -Force
            Write-WpLog -Message "Resumed $p wallpaper" -Level Success
        } else {
            if ($p -eq 'WallpaperEngine') { Pause-WallpaperEngine }
            elseif ($p -eq 'Lively') { Pause-Lively }
            Set-Content -Path $stateFile -Value 'paused' -Force
            Write-WpLog -Message "Paused $p wallpaper" -Level Success
        }
    }
    'open-ui' {
        $p = Get-ActiveProviderName
        if ($p -eq 'WallpaperEngine') {
            Open-WallpaperEngineUi
        }
    }
    'gallery' {
        Write-WpDiagnosticLog -Category 'GALLERY' -Message "Gallery action received in manager.ps1."
        $galleryScript = Join-Path $PSScriptRoot 'ui\gallery.ps1'
        if (Test-Path -LiteralPath $galleryScript) {
            Write-WpDiagnosticLog -Category 'GALLERY' -Message "Executing gallery script: $galleryScript"
            try {
                & $galleryScript
                Write-WpDiagnosticLog -Category 'GALLERY' -Message "Gallery script process completed or delegated."
            } catch {
                Write-WpDiagnosticLog -Category 'GALLERY' -Message "Gallery script failed" -ErrorDetails $_.Exception.Message
                Write-WpLog -Message "Gallery interface error: $($_.Exception.Message)" -Level Error
            }
        } else {
            Write-WpDiagnosticLog -Category 'GALLERY' -Message "Gallery interface script not found at $galleryScript" -ErrorDetails "File not found"
            Write-WpLog -Message "Gallery interface script not found at $galleryScript" -Level Error
        }
    }
}
