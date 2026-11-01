[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$ConfigOnly,
    [switch]$SkipPackages,
    [switch]$InstallFont,
    [switch]$UseLinks,
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# -------------------------------------------------------------------------
# 1. Bootstrap: If invoked remotely via `irm ... | iex`, download repo first
# -------------------------------------------------------------------------
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$isLocalRepo = (Test-Path (Join-Path $scriptDir 'configs')) -and (Test-Path (Join-Path $scriptDir 'install.ps1'))

if (-not $isLocalRepo) {
    Write-Host "`n[INFO] Remote execution detected. Bootstrapping repository to $HOME\.dotfiles..." -ForegroundColor Cyan
    $targetDir = Join-Path $env:USERPROFILE '.dotfiles\window_rice'
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($null -ne $gitCmd) {
        if (Test-Path (Join-Path $targetDir '.git')) {
            Write-Host "[INFO] Updating existing repository in $targetDir..." -ForegroundColor Cyan
            git -C $targetDir pull --quiet
        } else {
            Write-Host "[INFO] Cloning repository into $targetDir..." -ForegroundColor Cyan
            git clone --depth 1 https://github.com/suriyen-creator/6e5tz_window_rice.git $targetDir
        }
    } else {
        Write-Host "[INFO] Git not found. Downloading repository zip archive..." -ForegroundColor Cyan
        $zipUrl = "https://github.com/suriyen-creator/6e5tz_window_rice/archive/refs/heads/main.zip"
        $zipPath = Join-Path $env:TEMP "window_rice_main.zip"
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath (Join-Path $env:TEMP "rice_extracted") -Force
        Copy-Item -Path (Join-Path $env:TEMP "rice_extracted\6e5tz_window_rice-main\*") -Destination $targetDir -Recurse -Force
        Remove-Item -Path $zipPath, (Join-Path $env:TEMP "rice_extracted") -Recurse -Force -ErrorAction SilentlyContinue
    }

    $localInstaller = Join-Path $targetDir 'install.ps1'
    if (Test-Path $localInstaller) {
        & $localInstaller @PSBoundParameters
        return
    } else {
        throw "Failed to locate $localInstaller after bootstrap."
    }
}

$RepoRoot = [IO.Path]::GetFullPath($scriptDir)
$PackagesFile = Join-Path $RepoRoot 'packages.json'
$ConfigRoot = Join-Path $RepoRoot 'configs'
$InstallStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Results = New-Object 'System.Collections.Generic.List[object]'

# -------------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------------
function Write-Status {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('Info', 'Success', 'Skipped', 'Failed', 'Warning')][string]$Level = 'Info'
    )
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Skipped' { 'Yellow' }
        'Failed' { 'Red' }
        'Warning' { 'DarkYellow' }
        default { 'Cyan' }
    }
    Write-Host ("[{0}] {1}" -f $Level.ToUpperInvariant(), $Message) -ForegroundColor $color
}

function Add-Result {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('Success', 'Skipped', 'Failed')][string]$Status,
        [Parameter(Mandatory = $true)][string]$Detail
    )
    $Results.Add([PSCustomObject]@{ Name = $Name; Status = $Status; Detail = $Detail })
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Stop-RunningRiceProcesses {
    Write-Status "Closing running rice processes temporarily to safely update configs..." 'Info'
    $procs = @('yasb', 'glazewm', 'glazetiler', 'HideTaskbar', 'cava')
    foreach ($p in $procs) {
        $found = Get-Process -Name $p -ErrorAction SilentlyContinue
        if ($found) {
            Stop-Process -Name $p -Force -ErrorAction SilentlyContinue
            Write-Status "Stopped $p" 'Info'
        }
    }
    Start-Sleep -Milliseconds 500
}

function Get-RestorableFiles {
    param([Parameter(Mandatory = $true)][string]$Source)
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { return @() }
    $allowed = @('.yaml', '.yml', '.json', '.jsonc', '.css', '.ps1', '.psm1', '.ini', '.toml', '.conf', '.cfg', '.txt', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.webp', '.ttf', '.otf', '')
    return @(Get-ChildItem -LiteralPath $Source -File -Recurse -Force | Where-Object {
        ($allowed -contains $_.Extension.ToLowerInvariant()) -and
        ($_.Name -notmatch '(?i)(^README\.md$|^\.gitkeep$|\.example$|\.bak$|\.log$|history|cache|state)')
    })
}

function Convert-ToTargetText {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [switch]$PowerShellProfile
    )
    $userValue = if ($PowerShellProfile) { '$HOME' } else { $env:USERPROFILE }
    $Content = $Content.Replace('__USERPROFILE__', $userValue)
    $Content = $Content.Replace('__APPDATA__', $env:APPDATA)
    $Content = $Content.Replace('__LOCALAPPDATA__', $env:LOCALAPPDATA)
    $Content = $Content.Replace('__PROGRAMFILES__', $env:ProgramFiles)
    $Content = $Content.Replace('__PROGRAMFILES_X86__', ${env:ProgramFiles(x86)})
    $Content = $Content.Replace('__REPO_ROOT__', $RepoRoot)
    return $Content
}

function Prepare-Target {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Source
    )
    $parent = Split-Path -Parent $Target
    Ensure-Directory -Path $parent
    if (Test-Path -LiteralPath $Target) {
        $backup = "$Target.backup-$InstallStamp"
        try {
            Move-Item -LiteralPath $Target -Destination $backup -Force -ErrorAction Stop
            Write-Status "Backed up existing target to $backup" 'Warning'
        } catch {
            if (Test-Path -LiteralPath $Target -PathType Container) {
                # If target is locked folder, copy to backup instead of moving
                Copy-Item -LiteralPath $Target -Destination $backup -Recurse -Force -ErrorAction SilentlyContinue
                Write-Status "Copied folder backup to $backup" 'Warning'
            } else {
                Write-Status "Could not move target to ${backup}: $($_.Exception.Message)" 'Warning'
            }
        }
    }
}

function Restore-File {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Target,
        [switch]$PowerShellProfile
    )
    try {
        if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
            Write-Status "${Name}: repository file not found" 'Skipped'
            Add-Result -Name $Name -Status 'Skipped' -Detail 'Repository file not found.'
            return
        }
        Prepare-Target -Target $Target -Source $Source
        $extension = [IO.Path]::GetExtension($Source).ToLowerInvariant()
        $textExtensions = @('.yaml', '.yml', '.json', '.jsonc', '.css', '.ps1', '.psm1', '.ini', '.toml', '.conf', '.cfg', '.txt', '.md', '')
        if ($textExtensions -contains $extension) {
            $content = Get-Content -LiteralPath $Source -Raw
            $converted = Convert-ToTargetText -Content $content -PowerShellProfile:$PowerShellProfile
            [System.IO.File]::WriteAllText($Target, $converted, $utf8NoBom)
        } else {
            Copy-Item -LiteralPath $Source -Destination $Target -Force
        }
        Write-Status "${Name}: restored" 'Success'
        Add-Result -Name $Name -Status 'Success' -Detail $Target
    } catch {
        Write-Status "${Name}: $($_.Exception.Message)" 'Failed'
        Add-Result -Name $Name -Status 'Failed' -Detail $_.Exception.Message
    }
}

function Restore-Directory {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Target
    )
    try {
        $files = @(Get-RestorableFiles -Source $Source)
        if ($files.Count -eq 0) {
            Write-Status "${Name}: no restorable files" 'Skipped'
            Add-Result -Name $Name -Status 'Skipped' -Detail 'No restorable config files in repository.'
            return
        }
        Prepare-Target -Target $Target -Source $Source
        Ensure-Directory -Path $Target
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($Source.TrimEnd('\').Length).TrimStart('\')
            $destination = Join-Path $Target $relative
            $extension = $file.Extension.ToLowerInvariant()
            $textExtensions = @('.yaml', '.yml', '.json', '.jsonc', '.css', '.ps1', '.psm1', '.ini', '.toml', '.conf', '.cfg', '.txt', '.md', '')
            Ensure-Directory -Path (Split-Path -Parent $destination)
            if ($textExtensions -contains $extension) {
                $content = Get-Content -LiteralPath $file.FullName -Raw
                $converted = Convert-ToTargetText -Content $content
                [System.IO.File]::WriteAllText($destination, $converted, $utf8NoBom)
            } else {
                Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
            }
        }
        Write-Status "${Name}: restored" 'Success'
        Add-Result -Name $Name -Status 'Success' -Detail $Target
    } catch {
        Write-Status "${Name}: $($_.Exception.Message)" 'Failed'
        Add-Result -Name $Name -Status 'Failed' -Detail $_.Exception.Message
    }
}

# -------------------------------------------------------------------------
# Packages & Fonts
# -------------------------------------------------------------------------
function Install-Packages {
    if (-not (Test-Path -LiteralPath $PackagesFile -PathType Leaf)) {
        Write-Status 'packages.json not found; skipping package installation' 'Skipped'
        return
    }
    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $wingetCommand) {
        Write-Status 'winget is not available on PATH; skipping automatic package installs' 'Skipped'
        return
    }

    $packageData = Get-Content -LiteralPath $PackagesFile -Raw | ConvertFrom-Json
    foreach ($package in @($packageData.winget)) {
        try {
            Write-Status "Installing/Verifying $($package.name)..." 'Info'
            & $wingetCommand.Source 'install' '--id' $package.id '--exact' '--accept-package-agreements' '--accept-source-agreements'
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) { # 0 = success, -1978335189 = already installed
                Write-Status "$($package.name): ready" 'Success'
                Add-Result -Name "Package/$($package.name)" -Status 'Success' -Detail $package.id
            } else {
                Write-Status "$($package.name): winget code $LASTEXITCODE" 'Warning'
                Add-Result -Name "Package/$($package.name)" -Status 'Skipped' -Detail "Exit code $LASTEXITCODE"
            }
        } catch {
            Write-Status "$($package.name): $($_.Exception.Message)" 'Failed'
            Add-Result -Name "Package/$($package.name)" -Status 'Failed' -Detail $_.Exception.Message
        }
    }
}

function Install-NerdFont {
    Write-Status "Installing MesloLGL Nerd Font..." 'Info'
    $omp = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    if ($null -ne $omp) {
        try {
            & $omp.Source 'font' 'install' 'Meslo' '--headless'
            Write-Status "Meslo Nerd Font installed via Oh My Posh!" 'Success'
            return
        } catch {
            Write-Status "Oh My Posh font install failed; attempting direct download..." 'Warning'
        }
    }

    try {
        $fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
        $fontZip = Join-Path $env:TEMP "Meslo.zip"
        $fontExtract = Join-Path $env:TEMP "Meslo_extracted"
        Invoke-WebRequest -Uri $fontUrl -OutFile $fontZip -UseBasicParsing
        Expand-Archive -Path $fontZip -DestinationPath $fontExtract -Force
        
        $fontsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        Ensure-Directory -Path $fontsDir
        Get-ChildItem -Path $fontExtract -Filter "*.ttf" | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $fontsDir -Force
        }
        Remove-Item -Path $fontZip, $fontExtract -Recurse -Force -ErrorAction SilentlyContinue
        Write-Status "Meslo Nerd Font installed successfully!" 'Success'
    } catch {
        Write-Status "Could not auto-install font: $($_.Exception.Message)" 'Warning'
    }
}

# -------------------------------------------------------------------------
# Deploy All Configs
# -------------------------------------------------------------------------
function Deploy-AllConfigs {
    Stop-RunningRiceProcesses

    # 1. GlazeWM
    Restore-File -Name 'GlazeWM/config' -Source (Join-Path $ConfigRoot 'glazewm\config.yaml') -Target (Join-Path $env:USERPROFILE '.glzr\glazewm\config.yaml')

    # 2. YASB
    Restore-Directory -Name 'YASB' -Source (Join-Path $ConfigRoot 'yasb') -Target (Join-Path $env:USERPROFILE '.config\yasb')

    # 3. Flow Launcher
    Restore-File -Name 'Flow Launcher/settings' -Source (Join-Path $ConfigRoot 'flow-launcher\Settings.json') -Target (Join-Path $env:APPDATA 'FlowLauncher\Settings\Settings.json')
    Restore-Directory -Name 'Flow Launcher/plugins' -Source (Join-Path $ConfigRoot 'flow-launcher\plugins') -Target (Join-Path $env:APPDATA 'FlowLauncher\Settings\Plugins')
    Restore-Directory -Name 'Flow Launcher/themes' -Source (Join-Path $ConfigRoot 'flow-launcher\themes') -Target (Join-Path $env:APPDATA 'FlowLauncher\Themes')

    # 4. Windows Terminal
    $wtPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    $wtRestored = $false
    foreach ($wt in $wtPaths) {
        $parent = Split-Path -Parent $wt
        if (Test-Path $parent) {
            Restore-File -Name 'Windows Terminal/settings' -Source (Join-Path $ConfigRoot 'terminal\settings.json') -Target $wt
            $wtRestored = $true
            break
        }
    }
    if (-not $wtRestored) {
        Restore-File -Name 'Windows Terminal/settings' -Source (Join-Path $ConfigRoot 'terminal\settings.json') -Target $wtPaths[0]
    }

    # 5. PowerShell Profile
    $profilePath = if ($PROFILE) { $PROFILE } else { (Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1') }
    Restore-File -Name 'PowerShell/profile' -Source (Join-Path $ConfigRoot 'powershell\Microsoft.PowerShell_profile.ps1') -Target $profilePath -PowerShellProfile

    # 6. Oh My Posh
    if (Test-Path (Join-Path $ConfigRoot 'oh-my-posh\jandedobbeleer.omp.json')) {
        Restore-File -Name 'Oh My Posh/theme' -Source (Join-Path $ConfigRoot 'oh-my-posh\jandedobbeleer.omp.json') -Target (Join-Path $env:USERPROFILE '.config\jandedobbeleer.omp.json')
    }
    if (Test-Path (Join-Path $ConfigRoot 'oh-my-posh\omp_cache.ps1')) {
        Restore-File -Name 'Oh My Posh/cache' -Source (Join-Path $ConfigRoot 'oh-my-posh\omp_cache.ps1') -Target (Join-Path $env:USERPROFILE '.config\omp_cache.ps1')
    }

    # 7. Fastfetch
    Restore-Directory -Name 'Fastfetch (config)' -Source (Join-Path $ConfigRoot 'fastfetch') -Target (Join-Path $env:USERPROFILE '.config\fastfetch')
    Restore-File -Name 'Fastfetch (home)' -Source (Join-Path $ConfigRoot 'fastfetch\fastfetch.json') -Target (Join-Path $env:USERPROFILE 'fastfetch\fastfetch.json')
    Restore-File -Name 'Fastfetch/logo' -Source (Join-Path $ConfigRoot 'fastfetch\frieren.txt') -Target (Join-Path $env:USERPROFILE 'fastfetch\frieren.txt')

    # 8. CAVA
    if (Test-Path (Join-Path $ConfigRoot 'cava\config')) {
        Restore-File -Name 'CAVA/config' -Source (Join-Path $ConfigRoot 'cava\config') -Target (Join-Path $env:USERPROFILE '.config\cava\config')
    }
    if (Test-Path (Join-Path $ConfigRoot 'cava\yasb_cava_config_1')) {
        Restore-File -Name 'CAVA/yasb_config' -Source (Join-Path $ConfigRoot 'cava\yasb_cava_config_1') -Target (Join-Path $env:LOCALAPPDATA 'YASB\yasb_cava_config_1')
    }
    if (Test-Path (Join-Path $ConfigRoot 'cava\themes')) {
        Restore-Directory -Name 'CAVA/themes' -Source (Join-Path $ConfigRoot 'cava\themes') -Target (Join-Path $env:USERPROFILE '.config\cava\themes')
    }

    # 9. HideTaskbar & GlazeTiler
    if (Test-Path (Join-Path $ConfigRoot 'hidetaskbar\HideTaskbar.exe')) {
        Restore-File -Name 'HideTaskbar' -Source (Join-Path $ConfigRoot 'hidetaskbar\HideTaskbar.exe') -Target (Join-Path $env:USERPROFILE 'Downloads\HideTaskbar.exe')
    }
    if (Test-Path (Join-Path $ConfigRoot 'glazetiler\glazetiler.exe')) {
        Restore-File -Name 'GlazeTiler' -Source (Join-Path $ConfigRoot 'glazetiler\glazetiler.exe') -Target (Join-Path $env:USERPROFILE '.cargo\bin\glazetiler.exe')
    }

    # 10. Wallpaper Engine (if installed)
    if (Test-Path (Join-Path $ConfigRoot 'wallpaper-engine\config.json')) {
        $steamWeCandidates = @(
            'C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\config.json',
            'C:\Program Files\Steam\steamapps\common\wallpaper_engine\config.json'
        )
        foreach ($cand in $steamWeCandidates) {
            if (Test-Path (Split-Path -Parent $cand)) {
                Restore-File -Name 'Wallpaper Engine' -Source (Join-Path $ConfigRoot 'wallpaper-engine\config.json') -Target $cand
                break
            }
        }
    }
}

# -------------------------------------------------------------------------
# Main Execution Logic
# -------------------------------------------------------------------------
Clear-Host
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "   🌸 6e5tz Windows Desktop Rice Installer                               " -ForegroundColor Magenta
Write-Host "   GlazeWM • YASB • Flow Launcher • Oh My Posh • Fastfetch • CAVA         " -ForegroundColor Cyan
Write-Host "   Base setup credits: SleepyCatHey (https://github.com/SleepyCatHey)     " -ForegroundColor DarkGray
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

$doFull = $Full
$doConfig = $ConfigOnly -or $SkipPackages
$doFont = $InstallFont

if (-not ($doFull -or $doConfig -or $doFont) -and (-not $NonInteractive)) {
    Write-Host "Choose an installation option:" -ForegroundColor Yellow
    Write-Host "  [1] Full Installation (Recommended)" -ForegroundColor Green
    Write-Host "      - Install software packages via WinGet"
    Write-Host "      - Install MesloLGL Nerd Font (for icons)"
    Write-Host "      - Deploy and link all rice configs"
    Write-Host "  [2] Deploy Configs Only" -ForegroundColor Cyan
    Write-Host "      - Deploy all configuration files (skip WinGet package downloads)"
    Write-Host "  [3] Install Meslo Nerd Font Only" -ForegroundColor Blue
    Write-Host "  [Q] Cancel / Exit" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host "Enter option [1-3, Q] (Default: 1)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }

    switch ($choice) {
        '1' { $doFull = $true }
        '2' { $doConfig = $true }
        '3' { $doFont = $true }
        default {
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            return
        }
    }
}

if ($doFull) {
    Install-Packages
    Install-NerdFont
    Deploy-AllConfigs
} elseif ($doConfig) {
    Deploy-AllConfigs
} elseif ($doFont) {
    Install-NerdFont
}

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "  Installation Completed!" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
$Results | Group-Object Status | Sort-Object Name | ForEach-Object { Write-Host ("  {0}: {1}" -f $_.Name, $_.Count) }
Write-Host ""
Write-Host "Tips:" -ForegroundColor Yellow
Write-Host "  - Alt + Space      : Open Flow Launcher"
Write-Host "  - Alt + 1..9       : Switch GlazeWM workspaces"
Write-Host "  - Alt + H/J/K/L    : Move focus between windows"
Write-Host "  - Type 'ff' in pwsh: Launch Fastfetch with Frieren ASCII art"
Write-Host ""

$startNow = $false
if (-not $NonInteractive) {
    $askStart = Read-Host "Would you like to start GlazeWM & YASB now? (Y/N) [Default: Y]"
    if ([string]::IsNullOrWhiteSpace($askStart) -or ($askStart -match '^(y|yes)$')) {
        $startNow = $true
    }
}

if ($startNow) {
    $glazeCmd = Get-Command glazewm -ErrorAction SilentlyContinue
    if ($glazeCmd) {
        Start-Process $glazeCmd.Source
        Write-Host "[SUCCESS] GlazeWM started! (YASB will automatically start with it)" -ForegroundColor Green
    } else {
        $yasbCmd = Get-Command yasb -ErrorAction SilentlyContinue
        if ($yasbCmd) { Start-Process $yasbCmd.Source }
    }
}
