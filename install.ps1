[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$ConfigOnly,
    [switch]$SkipPackages,
    [switch]$InstallFont,
    [switch]$UseLinks,
    [switch]$NonInteractive,
    [ValidateSet('Auto', 'WallpaperEngine', 'Static')]
    [string]$WallpaperMode = 'Auto'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Ensure script execution is enabled for current user on clean Windows installations
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
} catch {}

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
    $procs = @('yasb', 'glazewm', 'glazetiler', 'HideTaskbar', 'cava', 'ModernFlyouts', 'btop')
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
    $allowed = @('.yaml', '.yml', '.json', '.jsonc', '.css', '.ps1', '.psm1', '.ini', '.toml', '.conf', '.cfg', '.txt', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.webp', '.ttf', '.otf', '.py', '.cmd', '.bat', '.exe', '')
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
    $userSlash = ($env:USERPROFILE).Replace('\', '/')
    $userValue = if ($PowerShellProfile) { '$HOME' } else { $userSlash }
    $Content = $Content.Replace('__USERPROFILE__/', "$userSlash/")
    $Content = $Content.Replace('__USERPROFILE__\', "$userSlash/")
    $Content = $Content.Replace('__USERPROFILE__', $userValue)
    $Content = $Content.Replace('__APPDATA__/', (($env:APPDATA).Replace('\', '/')) + '/')
    $Content = $Content.Replace('__APPDATA__\', (($env:APPDATA).Replace('\', '/')) + '/')
    $Content = $Content.Replace('__APPDATA__', ($env:APPDATA).Replace('\', '/'))
    $Content = $Content.Replace('__LOCALAPPDATA__/', (($env:LOCALAPPDATA).Replace('\', '/')) + '/')
    $Content = $Content.Replace('__LOCALAPPDATA__\', (($env:LOCALAPPDATA).Replace('\', '/')) + '/')
    $Content = $Content.Replace('__LOCALAPPDATA__', ($env:LOCALAPPDATA).Replace('\', '/'))
    $Content = $Content.Replace('__PROGRAMFILES__/', (($env:ProgramFiles).Replace('\', '/')) + '/')
    $Content = $Content.Replace('__PROGRAMFILES__\', (($env:ProgramFiles).Replace('\', '/')) + '/')
    $Content = $Content.Replace('__PROGRAMFILES__', ($env:ProgramFiles).Replace('\', '/'))
    $Content = $Content.Replace('__PROGRAMFILES_X86__/', ((${env:ProgramFiles(x86)}).Replace('\', '/')) + '/')
    $Content = $Content.Replace('__PROGRAMFILES_X86__\', ((${env:ProgramFiles(x86)}).Replace('\', '/')) + '/')
    $Content = $Content.Replace('__PROGRAMFILES_X86__', (${env:ProgramFiles(x86)}).Replace('\', '/'))
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
            $content = [System.IO.File]::ReadAllText($Source, [System.Text.Encoding]::UTF8)
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
                $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
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

    $packageRaw = [System.IO.File]::ReadAllText($PackagesFile, [System.Text.Encoding]::UTF8)
    $packageData = $packageRaw | ConvertFrom-Json
    foreach ($package in @($packageData.winget)) {
        try {
            Write-Status "Installing/Verifying $($package.name)..." 'Info'
            & $wingetCommand.Source 'install' '--id' $package.id '--exact' '--accept-package-agreements' '--accept-source-agreements' '--disable-interactivity'
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

    # Scoop bootstrap (ensures TUI packages work on brand-new Windows machines)
    $scoopCommand = Get-Command scoop -ErrorAction SilentlyContinue
    if ($null -eq $scoopCommand) {
        Write-Status "Scoop is not installed. Bootstrapping Scoop package manager..." 'Info'
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
            Invoke-RestMethod -Uri https://get.scoop.sh -UseBasicParsing | Invoke-Expression
            $env:SCOOP = "$env:USERPROFILE\scoop"
            $env:PATH = "$env:USERPROFILE\scoop\shims;$env:USERPROFILE\scoop\apps\scoop\current\bin;" + $env:PATH
            $scoopCommand = Get-Command scoop -ErrorAction SilentlyContinue
            if ($null -ne $scoopCommand) {
                Write-Status "Scoop installed successfully!" 'Success'
            }
        } catch {
            Write-Status "Could not auto-install Scoop: $($_.Exception.Message)" 'Warning'
        }
    }

    if ($null -ne $scoopCommand) {
        try {
            & $scoopCommand.Source 'bucket' 'add' 'extras' 2>$null
        } catch {}

        if ($null -ne $packageData.PSObject.Properties['scoop']) {
            foreach ($pkg in @($packageData.scoop)) {
                try {
                    Write-Status "Installing/Verifying Scoop package $($pkg.name)..." 'Info'
                    & $scoopCommand.Source 'install' $pkg.name
                    Write-Status "$($pkg.name): ready (scoop)" 'Success'
                    Add-Result -Name "Scoop/$($pkg.name)" -Status 'Success' -Detail $pkg.name
                } catch {
                    Write-Status "Scoop $($pkg.name): $($_.Exception.Message)" 'Warning'
                }
            }
        }
    }

    # Python terminal tools (windows-curses for unimatrix)
    $pyCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $pyCommand) {
        try {
            Write-Status "Installing Python packages for terminal tools (windows-curses)..." 'Info'
            & $pyCommand.Source '-m' 'pip' 'install' '--quiet' 'windows-curses'
            Write-Status "Python windows-curses: ready" 'Success'
        } catch {
            Write-Status "Python windows-curses: $($_.Exception.Message)" 'Warning'
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

    # Detect & apply wallpaper configuration mode
    $wePaths = @(
        'C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe',
        'C:\Program Files\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe',
        'C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper32.exe',
        'C:\Program Files\Steam\steamapps\common\wallpaper_engine\wallpaper32.exe'
    )
    $hasWE = [bool]($wePaths | Where-Object { Test-Path $_ } | Select-Object -First 1)

    $targetMode = $WallpaperMode
    if ($targetMode -eq 'Auto') {
        if (-not $NonInteractive) {
            Write-Host "`nWallpaper Mode Configuration:" -ForegroundColor Yellow
            if ($hasWE) {
                Write-Host "  [1] Wallpaper Engine (Detected on this system) [Default]" -ForegroundColor Green
                Write-Host "  [2] Static Wallpaper Gallery (Windows Desktop Wallpapers)" -ForegroundColor Cyan
                $choice = Read-Host "Select wallpaper mode (1/2) [Default: 1]"
                $targetMode = if ($choice -eq '2') { 'Static' } else { 'WallpaperEngine' }
            } else {
                Write-Host "  [1] Static Wallpaper Gallery (Recommended - Built-in YASB Gallery) [Default]" -ForegroundColor Green
                Write-Host "  [2] Wallpaper Engine (Requires Steam Wallpaper Engine)" -ForegroundColor DarkGray
                $choice = Read-Host "Select wallpaper mode (1/2) [Default: 1]"
                $targetMode = if ($choice -eq '2') { 'WallpaperEngine' } else { 'Static' }
            }
        } else {
            $targetMode = if ($hasWE) { 'WallpaperEngine' } else { 'Static' }
        }
    }

    if ($targetMode -eq 'Static') {
        $staticTmpl = Join-Path $ConfigRoot 'yasb\config.static.yaml'
        if (Test-Path $staticTmpl) {
            Restore-File -Name 'YASB/config (Static Wallpapers)' -Source $staticTmpl -Target (Join-Path $env:USERPROFILE '.config\yasb\config.yaml')
        }
    } else {
        $weTmpl = Join-Path $ConfigRoot 'yasb\config.wallpaper-engine.yaml'
        if (Test-Path $weTmpl) {
            Restore-File -Name 'YASB/config (Wallpaper Engine)' -Source $weTmpl -Target (Join-Path $env:USERPROFILE '.config\yasb\config.yaml')
        }
    }

    # Ensure silent next-wallpaper.exe launcher exists (GUI subsystem, zero console flash)
    $targetExe = Join-Path $env:USERPROFILE '.config\yasb\scripts\next-wallpaper.exe'
    if (-not (Test-Path $targetExe)) {
        $csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
        $srcCs = Join-Path $ConfigRoot 'yasb\scripts\NextWallpaperLauncher.cs'
        if ((Test-Path $csc) -and (Test-Path $srcCs)) {
            & $csc /target:winexe /optimize /nologo /out:"$targetExe" "$srcCs" | Out-Null
        }
    }

    # Always ensure sample wallpapers are available in ~/Pictures/Wallpapers
    $targetWallpapersDir = Join-Path $env:USERPROFILE 'Pictures\Wallpapers'
    Ensure-Directory $targetWallpapersDir
    $repoWallpapersDir = Join-Path $scriptDir 'wallpapers'
    if (Test-Path $repoWallpapersDir) {
        $sampleImgs = Get-ChildItem -Path $repoWallpapersDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '\.(jpg|jpeg|png|webp)$' }
        if ($sampleImgs) {
            foreach ($img in $sampleImgs) {
                $destImg = Join-Path $targetWallpapersDir $img.Name
                if (-not (Test-Path $destImg)) {
                    Copy-Item -LiteralPath $img.FullName -Destination $destImg -Force
                }
            }
            Write-Status "Wallpapers sample pack: copied to $targetWallpapersDir" 'Success'
        }
    }

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

    # 11. Btop
    if (Test-Path (Join-Path $ConfigRoot 'btop')) {
        Restore-Directory -Name 'Btop' -Source (Join-Path $ConfigRoot 'btop') -Target (Join-Path $env:USERPROFILE '.config\btop')
        $scoopBtopPersist = Join-Path $env:USERPROFILE 'scoop\persist\btop'
        if (Test-Path $scoopBtopPersist) {
            if (Test-Path (Join-Path $ConfigRoot 'btop\btop.conf')) {
                Copy-Item (Join-Path $ConfigRoot 'btop\btop.conf') "$scoopBtopPersist\btop.conf" -Force
            }
            if (Test-Path (Join-Path $ConfigRoot 'btop\themes')) {
                Ensure-Directory "$scoopBtopPersist\themes"
                Copy-Item (Join-Path $ConfigRoot 'btop\themes\*') "$scoopBtopPersist\themes\" -Recurse -Force
            }
        }
    }

    # 12. ExplorerBlurMica
    $ebmSource = Join-Path $ConfigRoot 'explorer-blur-mica'
    if (Test-Path $ebmSource) {
        $ebmTarget = Join-Path $env:USERPROFILE '.config\ExplorerBlurMica'
        Restore-Directory -Name 'ExplorerBlurMica' -Source $ebmSource -Target $ebmTarget
    }

    # 13. Spicetify
    $spicetifySource = Join-Path $ConfigRoot 'spicetify'
    if (Test-Path $spicetifySource) {
        $spicetifyTarget = Join-Path $env:APPDATA 'spicetify'
        Ensure-Directory $spicetifyTarget
        if (Test-Path (Join-Path $spicetifySource 'config-xpui.ini')) {
            Restore-File -Name 'Spicetify/config' -Source (Join-Path $spicetifySource 'config-xpui.ini') -Target (Join-Path $spicetifyTarget 'config-xpui.ini')
        }
        if (Test-Path (Join-Path $spicetifySource 'Themes')) {
            Restore-Directory -Name 'Spicetify/themes' -Source (Join-Path $spicetifySource 'Themes') -Target (Join-Path $spicetifyTarget 'Themes')
        }
        if (Test-Path (Join-Path $spicetifySource 'CustomApps')) {
            Restore-Directory -Name 'Spicetify/customapps' -Source (Join-Path $spicetifySource 'CustomApps') -Target (Join-Path $spicetifyTarget 'CustomApps')
        }
        if (Test-Path (Join-Path $spicetifySource 'Extensions')) {
            Restore-Directory -Name 'Spicetify/extensions' -Source (Join-Path $spicetifySource 'Extensions') -Target (Join-Path $spicetifyTarget 'Extensions')
        }
    }

    # 14. Terminal Tools (Clock / Unimatrix)
    $toolsSource = Join-Path $ConfigRoot 'tools'
    if (Test-Path $toolsSource) {
        Restore-Directory -Name 'Tools (Clock/Unimatrix)' -Source $toolsSource -Target (Join-Path $env:USERPROFILE '.config\tools')
    }

    # Stop ModernFlyouts if running (prevents Win + Space keyboard layout conflict #584)
    $mfProc = Get-Process -Name 'ModernFlyoutsHost', 'ModernFlyouts' -ErrorAction SilentlyContinue
    if ($mfProc) {
        Stop-Process -Name $mfProc.ProcessName -Force -ErrorAction SilentlyContinue
        Write-Status "Stopped ModernFlyouts (avoids Win+Space conflict)" 'Info'
    }

    # 15. Vencord (Discord)
    $vencordSource = Join-Path $ConfigRoot 'vencord'
    if (Test-Path $vencordSource) {
        $vencordTarget = Join-Path $env:APPDATA 'Vencord'
        Ensure-Directory $vencordTarget
        if (Test-Path (Join-Path $vencordSource 'settings.json')) {
            Restore-File -Name 'Vencord/settings' -Source (Join-Path $vencordSource 'settings.json') -Target (Join-Path $vencordTarget 'settings\settings.json')
        }
        if (Test-Path (Join-Path $vencordSource 'themes')) {
            Restore-Directory -Name 'Vencord/themes' -Source (Join-Path $vencordSource 'themes') -Target (Join-Path $vencordTarget 'themes')
        }
    }

    # 16. Nilesoft Shell
    $nsSource = Join-Path $ConfigRoot 'nilesoft-shell\shell.nss'
    if (Test-Path $nsSource) {
        $scoopNsTarget = Join-Path $env:USERPROFILE 'scoop\persist\nilesoft-shell\shell.nss'
        $scoopNsCurrent = Join-Path $env:USERPROFILE 'scoop\apps\nilesoft-shell\current\shell.nss'
        $nsUserTarget = Join-Path $env:USERPROFILE '.config\nilesoft-shell\shell.nss'
        if (Test-Path 'C:\Program Files\Nilesoft Shell') {
            Restore-File -Name 'Nilesoft Shell (Program Files)' -Source $nsSource -Target 'C:\Program Files\Nilesoft Shell\shell.nss'
        }
        if (Test-Path (Split-Path -Parent $scoopNsTarget)) {
            Restore-File -Name 'Nilesoft Shell (Scoop Persist)' -Source $nsSource -Target $scoopNsTarget
        }
        if (Test-Path (Split-Path -Parent $scoopNsCurrent)) {
            Restore-File -Name 'Nilesoft Shell (Scoop Current)' -Source $nsSource -Target $scoopNsCurrent
        }
        Restore-File -Name 'Nilesoft Shell (User Config)' -Source $nsSource -Target $nsUserTarget
    }
}

# -------------------------------------------------------------------------
# Main Execution Logic
# -------------------------------------------------------------------------
try { Clear-Host } catch {}
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
Write-Host "Tips & Hotkeys:" -ForegroundColor Yellow
Write-Host "  - Alt + Enter         : Open Windows Terminal (Hyprland style)"
Write-Host "  - Alt + D / Ctrl+Space: Open Flow Launcher (Search applications)"
Write-Host "  - Alt + 1..9          : Switch GlazeWM workspaces"
Write-Host "  - Alt + H / J / K / L : Move focus between windows (Vim keys)"
Write-Host "  - Alt + Shift + Q     : Close focused window"
Write-Host "  - Alt + Shift + Space : Toggle floating window"
Write-Host "  - Alt + W             : Next Wallpaper (Wallpaper Engine or Static Gallery)"
Write-Host "  - Win + Space         : Native Windows language switch (100% free of conflicts)"
Write-Host "  - Terminal Arsenal    : 'clock' (aesthetic clock), 'matrix' (rain screensaver), 'pipes', 'ff', 'btop', 'y' (Yazi), 'lg' (Lazygit), 'ls' (Eza), 'cat' (Bat), 'z' (Zoxide)"
Write-Host "  - ExplorerBlurMica    : Press Ctrl + F1 in File Explorer to minimize Ribbon for full Acrylic Blur"
Write-Host "  - Spicetify           : Run 'spicetify backup apply' once Spotify is installed"
Write-Host ""

$startNow = $false
if (-not $NonInteractive) {
    $askStart = Read-Host "Would you like to start GlazeWM & YASB now? (Y/N) [Default: Y]"
    if ([string]::IsNullOrWhiteSpace($askStart) -or ($askStart -match '^(y|yes)$')) {
        $startNow = $true
    }
}

if ($startNow) {
    $glazeExe = @(
        'C:\Program Files\glzr.io\GlazeWM\glazewm.exe',
        (Join-Path $env:LOCALAPPDATA 'Programs\glazewm\glazewm.exe')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($glazeExe) {
        Start-Process $glazeExe
        Write-Host "[SUCCESS] GlazeWM started! (YASB will automatically start with it)" -ForegroundColor Green
    } else {
        $yasbCmd = Get-Command yasb -ErrorAction SilentlyContinue
        if ($yasbCmd) { Start-Process $yasbCmd.Source }
    }
}
