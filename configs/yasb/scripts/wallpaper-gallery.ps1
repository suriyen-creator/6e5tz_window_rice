[CmdletBinding()]
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Log-GalleryDiagnostic {
    param([string]$Message, [string]$ErrorDetail = '')
    try {
        $logDir = Join-Path $env:USERPROFILE '.config\6e5tz'
        if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $logFile = Join-Path $logDir 'wallpaper.log'
        $ts = [System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff')
        $line = "[$ts] [SHORTCUT_GALLERY] $Message"
        if (-not [string]::IsNullOrWhiteSpace($ErrorDetail)) { $line += " | ERROR: $ErrorDetail" }
        [System.IO.File]::AppendAllText($logFile, "$line`r`n", [System.Text.Encoding]::UTF8)
    } catch {}
}

Log-GalleryDiagnostic -Message "Shortcut Alt+Shift+G received in wallpaper-gallery.ps1"

# 1. Prefer native zero-console Floating Acrylic Side Panel binary
$panelExeCandidates = @(
    (Join-Path $scriptDir 'wallpaper-gallery.exe'),
    (Join-Path $scriptDir 'WallpaperSidePanel.exe'),
    (Join-Path $env:USERPROFILE '.config\yasb\scripts\wallpaper-gallery.exe'),
    (Join-Path $env:USERPROFILE '.config\yasb\scripts\WallpaperSidePanel.exe')
)
$panelExe = $panelExeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if ($panelExe) {
    Log-GalleryDiagnostic -Message "Launching Side Panel binary directly via $panelExe"
    try {
        $p = Start-Process -FilePath $panelExe -WindowStyle Hidden -PassThru
        if ($p) {
            Log-GalleryDiagnostic -Message "Side Panel process started successfully (PID: $($p.Id))"
            exit 0
        }
    } catch {
        Log-GalleryDiagnostic -Message "Exception launching Side Panel binary" -ErrorDetail $_.Exception.Message
    }
}

# 2. Fallback to gallery.ps1 across known locations
$galleryCandidates = @(
    (Join-Path $env:USERPROFILE '.config\6e5tz\scripts\wallpaper\ui\panel.ps1'),
    (Join-Path $env:USERPROFILE '.config\6e5tz\scripts\wallpaper\ui\gallery.ps1'),
    (Join-Path $env:USERPROFILE 'Documents\window_rice\scripts\wallpaper\ui\panel.ps1'),
    (Join-Path $env:USERPROFILE 'Documents\window_rice\scripts\wallpaper\ui\gallery.ps1'),
    (Join-Path $env:USERPROFILE '.dotfiles\window_rice\scripts\wallpaper\ui\gallery.ps1'),
    (Join-Path $scriptDir '..\..\scripts\wallpaper\ui\gallery.ps1'),
    (Join-Path $scriptDir '..\..\..\scripts\wallpaper\ui\gallery.ps1')
)
$galleryScript = $galleryCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if ($galleryScript) {
    Log-GalleryDiagnostic -Message "Resolved gallery script: $galleryScript"
    # Find best PowerShell host (prefer pwsh, fallback to powershell)
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

    Log-GalleryDiagnostic -Message "Launching Gallery process via $pwshExe -Sta -File `"$galleryScript`""
    try {
        $p = Start-Process -FilePath $pwshExe -ArgumentList "-Sta", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$galleryScript`"" -WindowStyle Hidden -PassThru
        if ($p) {
            Log-GalleryDiagnostic -Message "Gallery process started successfully (PID: $($p.Id))"
        } else {
            Log-GalleryDiagnostic -Message "Start-Process returned null" -ErrorDetail "Failed to spawn process"
        }
    } catch {
        Log-GalleryDiagnostic -Message "Exception launching Gallery process" -ErrorDetail $_.Exception.Message
    }
} else {
    Log-GalleryDiagnostic -Message "Wallpaper Gallery script not found in candidates" -ErrorDetail ($galleryCandidates -join '; ')
    Write-Warning "Wallpaper Gallery script not found."
}
