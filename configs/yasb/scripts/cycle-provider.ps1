[CmdletBinding()]
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Log-CycleDiagnostic {
    param([string]$Message, [string]$ErrorDetail = '')
    try {
        $logDir = Join-Path $env:USERPROFILE '.config\6e5tz'
        if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $logFile = Join-Path $logDir 'wallpaper.log'
        $ts = [System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff')
        $line = "[$ts] [SHORTCUT_CYCLE_PROVIDER] $Message"
        if (-not [string]::IsNullOrWhiteSpace($ErrorDetail)) { $line += " | ERROR: $ErrorDetail" }
        [System.IO.File]::AppendAllText($logFile, "$line`r`n", [System.Text.Encoding]::UTF8)
    } catch {}
}

Log-CycleDiagnostic -Message "Shortcut Alt+Ctrl+W received in cycle-provider.ps1"

$candidates = @(
    (Join-Path $env:USERPROFILE '.config\6e5tz\scripts\wallpaper\manager.ps1'),
    (Join-Path $env:USERPROFILE 'Documents\window_rice\scripts\wallpaper\manager.ps1'),
    (Join-Path $env:USERPROFILE '.dotfiles\window_rice\scripts\wallpaper\manager.ps1'),
    (Join-Path $scriptDir '..\..\scripts\wallpaper\manager.ps1'),
    (Join-Path $scriptDir '..\..\..\scripts\wallpaper\manager.ps1'),
    (Join-Path $scriptDir '..\scripts\wallpaper\manager.ps1')
)

$managerScript = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if ($managerScript) {
    Log-CycleDiagnostic -Message "Resolved manager script: $managerScript"
    # Find best PowerShell host
    $pwshCandidates = @(
        (Join-Path $env:USERPROFILE 'scoop\apps\pwsh\current\pwsh.exe'),
        'C:\Program Files\PowerShell\7\pwsh.exe',
        'pwsh.exe',
        'powershell.exe'
    )
    $pwshExe = $pwshCandidates | Where-Object { 
        if ($_ -match '^[a-zA-Z]:') { Test-Path -LiteralPath $_ }
        else { [bool](Get-Command $_ -ErrorAction SilentlyContinue) }
    } | Select-Object -First 1
    if (-not $pwshExe) { $pwshExe = 'powershell.exe' }

    try {
        $stateFile = Join-Path $env:USERPROFILE '.config\6e5tz\wallpaper-state.json'
        $curProv = 'Unknown'
        if (Test-Path -LiteralPath $stateFile) {
            try {
                $raw = [System.IO.File]::ReadAllText($stateFile, [System.Text.Encoding]::UTF8)
                $st = $raw | ConvertFrom-Json
                $curProv = $st.activeProvider
            } catch {}
        }
        Log-CycleDiagnostic -Message "Current active provider before cycle: $curProv"

        # Execute cycle-provider action via manager.ps1 (in-process if pwsh 7+, else via pwshExe)
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $output = & $managerScript -Action cycle-provider 2>&1
        } else {
            $output = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File "$managerScript" -Action cycle-provider 2>&1
        }
        $outStr = ($output | Out-String).Trim()
        
        $newProv = $curProv
        if (Test-Path -LiteralPath $stateFile) {
            try {
                $raw = [System.IO.File]::ReadAllText($stateFile, [System.Text.Encoding]::UTF8)
                $st = $raw | ConvertFrom-Json
                $newProv = $st.activeProvider
            } catch {}
        }
        
        Log-CycleDiagnostic -Message "Cycle completed: $curProv -> $newProv. Output: $outStr"
    } catch {
        Log-CycleDiagnostic -Message "Exception during provider cycling" -ErrorDetail $_.Exception.Message
    }
} else {
    Log-CycleDiagnostic -Message "Universal Wallpaper Manager script not found in candidates" -ErrorDetail ($candidates -join '; ')
    Write-Warning "Universal Wallpaper Manager not found."
}
