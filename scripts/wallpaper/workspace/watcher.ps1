# ==============================================================================
# 6e5tz Universal Wallpaper Manager - GlazeWM Workspace Watcher Daemon
# Listens to GlazeWM IPC WebSocket events and switches wallpapers per workspace
# ==============================================================================

[CmdletBinding()]
param(
    [ValidateSet('Start', 'Stop', 'Restart', 'Status', 'RunOnce', 'RunDaemon')]
    [string]$Command = 'RunDaemon',

    [string]$GlazeUri = 'ws://127.0.0.1:6123',
    [int]$DebounceMs = 250
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\common.ps1')
. (Join-Path $PSScriptRoot '..\config.ps1')
. (Join-Path $PSScriptRoot '..\state.ps1')

$script:PidFile = Join-Path $env:TEMP '6e5tz_wp_watcher.pid'
$script:ManagerScript = Join-Path $PSScriptRoot '..\manager.ps1'

function Get-WatcherProcess {
    if (Test-Path -LiteralPath $script:PidFile) {
        try {
            $pidStr = [System.IO.File]::ReadAllText($script:PidFile).Trim()
            $procId = 0
            if ([int]::TryParse($pidStr, [ref]$procId)) {
                $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
                if ($proc -and $proc.ProcessName -match 'pwsh|powershell') {
                    return $proc
                }
            }
        } catch {}
    }
    return $null
}

function Stop-WatcherDaemon {
    $proc = Get-WatcherProcess
    if ($proc) {
        Write-WpLog -Message "Stopping existing Workspace Watcher daemon (PID $($proc.Id))..." -Level Info
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $script:PidFile) {
        Remove-Item -LiteralPath $script:PidFile -Force -ErrorAction SilentlyContinue
    }
}

function Start-WatcherBackground {
    Stop-WatcherDaemon
    
    $pwshExe = (Get-Process -Id $PID).Path
    if (-not (Test-Path -LiteralPath $pwshExe)) {
        $pwshExe = 'powershell.exe'
    }

    $thisScript = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
    $args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$thisScript`" -Command RunDaemon"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $pwshExe
    $psi.Arguments = $args
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $child = [System.Diagnostics.Process]::Start($psi)
    [System.IO.File]::WriteAllText($script:PidFile, $child.Id.ToString(), $script:Utf8NoBom)
    Write-WpLog -Message "Workspace Watcher daemon started in background (PID $($child.Id))." -Level Success
}

function Query-CurrentGlazeWorkspace {
    $glazeCmd = Get-Command glazewm -ErrorAction SilentlyContinue
    if (-not $glazeCmd) { return $null }

    try {
        $jsonStr = & $glazeCmd.Source query workspaces 2>$null
        if (-not [string]::IsNullOrWhiteSpace($jsonStr)) {
            $obj = $jsonStr | ConvertFrom-Json
            if ($null -ne $obj -and $null -ne $obj.data -and $null -ne $obj.data.workspaces) {
                foreach ($ws in @($obj.data.workspaces)) {
                    if ($ws.hasFocus -eq $true -or $ws.isDisplayed -eq $true) {
                        return [string]$ws.name
                    }
                }
            }
        }
    } catch {}
    return $null
}

function Run-OnceWorkspaceSync {
    $activeWs = Query-CurrentGlazeWorkspace
    if (-not [string]::IsNullOrWhiteSpace($activeWs)) {
        Write-WpLog -Message "Synchronizing wallpaper for active GlazeWM workspace: $activeWs" -Level Info
        & $script:ManagerScript -Action workspace -Workspace $activeWs | Out-Null
    } else {
        Write-WpLog -Message "Could not determine active GlazeWM workspace." -Level Warning
    }
}

function Check-AutoRotationTrigger {
    try {
        $config = Get-WpConfig
        if ($null -eq $config.PSObject.Properties['rotation']) { return }
        $rotConfig = $config.rotation
        if (-not $rotConfig.enabled) { return }

        $intervalMin = if ($null -ne $rotConfig.intervalMinutes) { [int]$rotConfig.intervalMinutes } else { 30 }
        if ($intervalMin -le 0) { $intervalMin = 30 }

        $state = Get-WpState
        $lastRotStr = if ($null -ne $state.PSObject.Properties['rotation'] -and $null -ne $state.rotation.PSObject.Properties['lastRotated']) {
            [string]$state.rotation.lastRotated
        } else { "" }

        $lastRotTime = [DateTime]::MinValue
        if (-not [string]::IsNullOrWhiteSpace($lastRotStr)) {
            [DateTime]::TryParse($lastRotStr, [ref]$lastRotTime) | Out-Null
        }

        $elapsedMin = ([DateTime]::UtcNow - $lastRotTime.ToUniversalTime()).TotalMinutes
        if ($elapsedMin -ge $intervalMin) {
            Write-WpLog -Message "Auto-rotation timer triggered after $([Math]::Round($elapsedMin, 1))m (interval: ${intervalMin}m)." -Level Info
            & $script:ManagerScript -Action rotate | Out-Null
        }
    } catch {}
}

function Run-WatcherDaemonLoop {
    [System.IO.File]::WriteAllText($script:PidFile, $PID.ToString(), $script:Utf8NoBom)
    Write-WpLog -Message "Starting Workspace Watcher event listener on $GlazeUri (PID $PID)..." -Level Info

    # Synchronize current active workspace initially
    Run-OnceWorkspaceSync

    $buffer = [byte[]]::new(16384)
    $pendingWs = $null
    $lastEventTicks = 0L

    while ($true) {
        $ws = $null
        try {
            $ws = [System.Net.WebSockets.ClientWebSocket]::new()
            $connectCts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(5))
            
            Write-WpLog -Message "Connecting to GlazeWM IPC WebSocket..." -Level Debug
            $ws.ConnectAsync([Uri]$GlazeUri, $connectCts.Token).Wait()

            # Subscribe to workspace_activated events
            $subPayload = [System.Text.Encoding]::UTF8.GetBytes("sub -e workspace_activated")
            $ws.SendAsync([ArraySegment[byte]]$subPayload, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
            Write-WpLog -Message "Subscribed to GlazeWM workspace_activated events." -Level Success

            while ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                $segment = [ArraySegment[byte]]$buffer
                $timeoutCts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(5))
                $resultTask = $ws.ReceiveAsync($segment, $timeoutCts.Token)
                
                try {
                    $resultTask.Wait()
                } catch [System.AggregateException] {
                    if ($_.InnerException -is [System.OperationCanceledException] -or $_.InnerException -is [System.Threading.Tasks.TaskCanceledException]) {
                        # Timeout interval: perform auto-rotation check
                        Check-AutoRotationTrigger
                        continue
                    }
                    throw
                }

                $result = $resultTask.Result

                if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
                    Write-WpLog -Message "GlazeWM closed WebSocket connection." -Level Warning
                    break
                }

                $msgJson = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)
                if ([string]::IsNullOrWhiteSpace($msgJson)) {
                    Check-AutoRotationTrigger
                    continue
                }

                try {
                    $evt = $msgJson | ConvertFrom-Json
                    $wsName = $null

                    # Check GlazeWM workspace_activated event format
                    if ($null -ne $evt -and $null -ne $evt.data) {
                        $data = $evt.data
                        if ($null -ne $data.PSObject.Properties['workspace'] -and $null -ne $data.workspace) {
                            $wsName = [string]$data.workspace.name
                        } elseif ($null -ne $data.PSObject.Properties['focusedContainer'] -and $null -ne $data.focusedContainer) {
                            if ($data.focusedContainer.type -eq 'workspace') {
                                $wsName = [string]$data.focusedContainer.name
                            }
                        }
                    }

                    # If event didn't give explicit workspace name, query GlazeWM
                    if ([string]::IsNullOrWhiteSpace($wsName)) {
                        $wsName = Query-CurrentGlazeWorkspace
                    }

                    if (-not [string]::IsNullOrWhiteSpace($wsName)) {
                        $now = [System.DateTime]::UtcNow.Ticks
                        $pendingWs = $wsName
                        $lastEventTicks = $now

                        Start-Sleep -Milliseconds $DebounceMs

                        if ($pendingWs -eq $wsName) {
                            Write-WpLog -Message "Workspace activated: $wsName" -Level Info
                            & $script:ManagerScript -Action workspace -Workspace $wsName | Out-Null
                            $pendingWs = $null
                        }
                    }
                } catch {}

                Check-AutoRotationTrigger
            }
        } catch {
            Write-WpLog -Message "GlazeWM IPC connection error: $($_.Exception.Message). Reconnecting in 3 seconds..." -Level Debug
            Start-Sleep -Seconds 3
        } finally {
            if ($null -ne $ws) {
                try { $ws.Dispose() } catch {}
            }
        }
    }
}

# -----------------------------------------------------------------------------
# Dispatcher
# -----------------------------------------------------------------------------
if ($MyInvocation.InvocationName -eq '.') {
    return
}

switch ($Command) {
    'Start' {
        Start-WatcherBackground
    }
    'Stop' {
        Stop-WatcherDaemon
    }
    'Restart' {
        Stop-WatcherDaemon
        Start-WatcherBackground
    }
    'Status' {
        $proc = Get-WatcherProcess
        if ($proc) {
            Write-Host "Workspace Watcher is RUNNING (PID $($proc.Id))" -ForegroundColor Green
        } else {
            Write-Host "Workspace Watcher is STOPPED" -ForegroundColor Yellow
        }
    }
    'RunOnce' {
        Run-OnceWorkspaceSync
    }
    'RunDaemon' {
        Run-WatcherDaemonLoop
    }
}
