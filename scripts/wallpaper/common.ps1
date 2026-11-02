# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Common Utilities
# Concurrency locking, debouncing, atomic JSON IO, and helper routines
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:UserConfigDir = Join-Path $env:USERPROFILE '.config\6e5tz'
$script:ConfigFilePath = Join-Path $script:UserConfigDir 'wallpaper-manager.json'
$script:StateFilePath = Join-Path $script:UserConfigDir 'wallpaper-state.json'
$script:LogFilePath = Join-Path $script:UserConfigDir 'wallpaper.log'
$script:LockFilePath = Join-Path $env:TEMP '6e5tz_wp_debounce.lock'
$script:MutexName = 'Local\6e5tz_Wallpaper_Mutex'

function Ensure-DirectoryExists {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-WpDiagnosticLog {
    param(
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$ErrorDetails = ''
    )
    try {
        Ensure-DirectoryExists -Path $script:UserConfigDir
        # Limit log size to 512KB to avoid excessive disk writes
        if (Test-Path -LiteralPath $script:LogFilePath) {
            $fi = Get-Item -LiteralPath $script:LogFilePath -ErrorAction SilentlyContinue
            if ($fi -and $fi.Length -gt 524288) {
                $old = "$script:LogFilePath.old"
                Move-Item -LiteralPath $script:LogFilePath -Destination $old -Force -ErrorAction SilentlyContinue
            }
        }
        $ts = [System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff')
        $line = "[$ts] [$Category] $Message"
        if (-not [string]::IsNullOrWhiteSpace($ErrorDetails)) {
            $line += " | ERROR: $ErrorDetails"
        }
        [System.IO.File]::AppendAllText($script:LogFilePath, "$line`r`n", $script:Utf8NoBom)
    } catch {}
}

function Write-WpLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')][string]$Level = 'Info'
    )
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Debug'   { 'DarkGray' }
        default   { 'Cyan' }
    }
    Write-Host ("[WP-MGR] [{0}] {1}" -f $Level.ToUpperInvariant(), $Message) -ForegroundColor $color
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [object]$Default = $null
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $Default
    }
    try {
        $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
        return ($raw | ConvertFrom-Json)
    } catch {
        Write-WpLog -Message "Failed to read JSON from ${Path}: $($_.Exception.Message)" -Level Warning
        return $Default
    }
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Data
    )
    try {
        $parent = Split-Path -Parent $Path
        Ensure-DirectoryExists -Path $parent
        $tempPath = "$Path.tmp.$([System.Guid]::NewGuid().ToString('N'))"
        $json = $Data | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($tempPath, $json, $script:Utf8NoBom)
        Move-Item -LiteralPath $tempPath -Destination $Path -Force
        return $true
    } catch {
        Write-WpLog -Message "Failed to write JSON to ${Path}: $($_.Exception.Message)" -Level Error
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}

# -----------------------------------------------------------------------------
# Concurrency & Debounce Protection (Fixes Alt + W Double Switching)
# -----------------------------------------------------------------------------
function Invoke-WithWallpaperLock {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Script,
        [int]$DebounceMs = 350,
        [int]$TimeoutMs = 1500
    )

    # 1. Fast-path debounce check before waiting on mutex
    $now = [System.DateTime]::UtcNow.Ticks
    if (Test-Path -LiteralPath $script:LockFilePath) {
        try {
            $lastTicksStr = [System.IO.File]::ReadAllText($script:LockFilePath).Trim()
            $lastTicks = 0L
            if ([long]::TryParse($lastTicksStr, [ref]$lastTicks)) {
                $elapsedMs = ($now - $lastTicks) / 10000.0
                if ($elapsedMs -lt $DebounceMs) {
                    Write-WpLog -Message "Debounced rapid invocation (${elapsedMs}ms < ${DebounceMs}ms)" -Level Debug
                    return $null
                }
            }
        } catch {
            # Ignore lock file read race
        }
    }

    # 2. Named Mutex concurrency guard
    $mutexCreated = $false
    $mutex = $null
    try {
        $mutex = New-Object System.Threading.Mutex($false, $script:MutexName, [ref]$mutexCreated)
        $hasLock = $mutex.WaitOne($TimeoutMs)
        if (-not $hasLock) {
            Write-WpLog -Message "Could not acquire concurrency lock within ${TimeoutMs}ms" -Level Warning
            return $null
        }

        # 3. Double-check debounce timestamp inside mutex lock
        $nowLocked = [System.DateTime]::UtcNow.Ticks
        if (Test-Path -LiteralPath $script:LockFilePath) {
            try {
                $lastTicksStr = [System.IO.File]::ReadAllText($script:LockFilePath).Trim()
                $lastTicks = 0L
                if ([long]::TryParse($lastTicksStr, [ref]$lastTicks)) {
                    $elapsedMs = ($nowLocked - $lastTicks) / 10000.0
                    if ($elapsedMs -lt $DebounceMs) {
                        Write-WpLog -Message "Debounced rapid invocation (${elapsedMs}ms < ${DebounceMs}ms)" -Level Debug
                        return $null
                    }
                }
            } catch {}
        }

        # Update last execution timestamp
        try {
            [System.IO.File]::WriteAllText($script:LockFilePath, $nowLocked.ToString(), $script:Utf8NoBom)
        } catch {}

        # Execute payload
        return (& $Script)
    } finally {
        if ($null -ne $mutex) {
            try { $mutex.ReleaseMutex() } catch {}
            $mutex.Dispose()
        }
    }
}

# End of common utilities
