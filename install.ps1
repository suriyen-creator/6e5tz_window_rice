[CmdletBinding()]
param(
    [switch]$SkipPackages,
    [switch]$UseLinks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$PackagesFile = Join-Path $RepoRoot 'packages.json'
$ConfigRoot = Join-Path $RepoRoot 'configs'
$InstallStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Results = New-Object 'System.Collections.Generic.List[object]'

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

function Get-RestorableFiles {
    param([Parameter(Mandatory = $true)][string]$Source)
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { return @() }
    $allowed = @('.yaml', '.yml', '.json', '.jsonc', '.css', '.ps1', '.psm1', '.ini', '.toml', '.conf', '.cfg', '.txt', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.webp', '.ttf', '.otf')
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

function Test-OurLink {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Source
    )
    try {
        $targetItem = Get-Item -LiteralPath $Target -Force
        if (($targetItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { return $false }
        $resolvedTarget = (Resolve-Path -LiteralPath $Target -ErrorAction Stop).Path
        $resolvedSource = (Resolve-Path -LiteralPath $Source -ErrorAction Stop).Path
        return $resolvedTarget.TrimEnd('\') -ieq $resolvedSource.TrimEnd('\')
    } catch {
        return $false
    }
}

function Prepare-Target {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Source
    )
    $parent = Split-Path -Parent $Target
    Ensure-Directory -Path $parent
    if (Test-Path -LiteralPath $Target) {
        if (Test-OurLink -Target $Target -Source $Source) {
            Remove-Item -LiteralPath $Target -Force
            Write-Status "Refreshing repository link: $Target" 'Info'
        } else {
            $backup = "$Target.backup-$InstallStamp"
            Move-Item -LiteralPath $Target -Destination $backup
            Write-Status "Backed up existing target to $backup" 'Warning'
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
        $textExtensions = @('.yaml', '.yml', '.json', '.jsonc', '.css', '.ps1', '.psm1', '.ini', '.toml', '.conf', '.cfg', '.txt', '.md')
        if ($textExtensions -contains $extension) {
            $content = Get-Content -LiteralPath $Source -Raw
            Set-Content -LiteralPath $Target -Value (Convert-ToTargetText -Content $content -PowerShellProfile:$PowerShellProfile) -Encoding UTF8
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
        if ($UseLinks) {
            try {
                New-Item -ItemType Junction -Path $Target -Target $Source -Force | Out-Null
                Write-Status "${Name}: junction created" 'Success'
                Add-Result -Name $Name -Status 'Success' -Detail "Junction: $Target -> $Source"
                return
            } catch {
                Write-Status "${Name}: junction unavailable; falling back to copy" 'Warning'
            }
        }
        Ensure-Directory -Path $Target
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($Source.TrimEnd('\').Length).TrimStart('\')
            $destination = Join-Path $Target $relative
            $extension = $file.Extension.ToLowerInvariant()
            $textExtensions = @('.yaml', '.yml', '.json', '.jsonc', '.css', '.ps1', '.psm1', '.ini', '.toml', '.conf', '.cfg', '.txt', '.md')
            Ensure-Directory -Path (Split-Path -Parent $destination)
            if ($textExtensions -contains $extension) {
                $content = Get-Content -LiteralPath $file.FullName -Raw
                Set-Content -LiteralPath $destination -Value (Convert-ToTargetText -Content $content) -Encoding UTF8
            } else {
                Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
            }
        }
        Write-Status "${Name}: restored by copy" 'Success'
        Add-Result -Name $Name -Status 'Success' -Detail $Target
    } catch {
        Write-Status "${Name}: $($_.Exception.Message)" 'Failed'
        Add-Result -Name $Name -Status 'Failed' -Detail $_.Exception.Message
    }
}

function Install-Packages {
    if ($SkipPackages) {
        Write-Status 'Package installation skipped by -SkipPackages' 'Skipped'
        return
    }
    if (-not (Test-Path -LiteralPath $PackagesFile -PathType Leaf)) {
        Write-Status 'packages.json not found; package installation skipped' 'Skipped'
        return
    }
    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $wingetCommand) {
        Write-Status 'winget is not available; install packages manually or install App Installer first' 'Skipped'
        return
    }
    try {
        & $wingetCommand.Source '--info' *> $null
        if ($LASTEXITCODE -ne 0) { throw 'winget exists on PATH but could not be started' }
    } catch {
        Write-Status "winget cannot be started: $($_.Exception.Message)" 'Skipped'
        return
    }

    $packageData = Get-Content -LiteralPath $PackagesFile -Raw | ConvertFrom-Json
    foreach ($package in @($packageData.winget)) {
        try {
            Write-Status "Checking $($package.name) [$($package.id)]" 'Info'
            & $wingetCommand.Source 'install' '--id' $package.id '--exact' '--accept-package-agreements' '--accept-source-agreements'
            if ($LASTEXITCODE -eq 0) {
                Write-Status "$($package.name): package operation completed" 'Success'
                Add-Result -Name "Package/$($package.name)" -Status 'Success' -Detail $package.id
            } else {
                Write-Status "$($package.name): winget exit code $LASTEXITCODE" 'Failed'
                Add-Result -Name "Package/$($package.name)" -Status 'Failed' -Detail "Exit code $LASTEXITCODE"
            }
        } catch {
            Write-Status "$($package.name): $($_.Exception.Message)" 'Failed'
            Add-Result -Name "Package/$($package.name)" -Status 'Failed' -Detail $_.Exception.Message
        }
    }
}

Install-Packages

Restore-File -Name 'GlazeWM/config' -Source (Join-Path $ConfigRoot 'glazewm\config.yaml') -Target (Join-Path $env:USERPROFILE '.glzr\glazewm\config.yaml')
Restore-Directory -Name 'YASB' -Source (Join-Path $ConfigRoot 'yasb') -Target (Join-Path $env:USERPROFILE '.config\yasb')
Restore-File -Name 'Flow Launcher/settings' -Source (Join-Path $ConfigRoot 'flow-launcher\Settings.json') -Target (Join-Path $env:APPDATA 'FlowLauncher\Settings\Settings.json')
Restore-Directory -Name 'Flow Launcher/plugins' -Source (Join-Path $ConfigRoot 'flow-launcher\plugins') -Target (Join-Path $env:APPDATA 'FlowLauncher\Settings\Plugins')
Restore-Directory -Name 'Flow Launcher/themes' -Source (Join-Path $ConfigRoot 'flow-launcher\themes') -Target (Join-Path $env:APPDATA 'FlowLauncher\Themes')
Restore-File -Name 'Windows Terminal/settings' -Source (Join-Path $ConfigRoot 'terminal\settings.json') -Target (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')
Restore-File -Name 'PowerShell/profile' -Source (Join-Path $ConfigRoot 'powershell\Microsoft.PowerShell_profile.ps1') -Target $PROFILE -PowerShellProfile

# Oh My Posh
if (Test-Path (Join-Path $ConfigRoot 'oh-my-posh\jandedobbeleer.omp.json')) {
    Restore-File -Name 'Oh My Posh/theme' -Source (Join-Path $ConfigRoot 'oh-my-posh\jandedobbeleer.omp.json') -Target (Join-Path $env:USERPROFILE '.config\jandedobbeleer.omp.json')
}
if (Test-Path (Join-Path $ConfigRoot 'oh-my-posh\omp_cache.ps1')) {
    Restore-File -Name 'Oh My Posh/cache' -Source (Join-Path $ConfigRoot 'oh-my-posh\omp_cache.ps1') -Target (Join-Path $env:USERPROFILE '.config\omp_cache.ps1')
}
Restore-Directory -Name 'Oh My Posh/themes' -Source (Join-Path $ConfigRoot 'oh-my-posh\themes') -Target (Join-Path $env:USERPROFILE '.config\oh-my-posh\themes')

# Fastfetch
Restore-Directory -Name 'Fastfetch (config)' -Source (Join-Path $ConfigRoot 'fastfetch') -Target (Join-Path $env:USERPROFILE '.config\fastfetch')
if (Test-Path (Join-Path $ConfigRoot 'fastfetch\fastfetch.json')) {
    Restore-File -Name 'Fastfetch (home)' -Source (Join-Path $ConfigRoot 'fastfetch\fastfetch.json') -Target (Join-Path $env:USERPROFILE 'fastfetch\fastfetch.json')
}
if (Test-Path (Join-Path $ConfigRoot 'fastfetch\frieren.txt')) {
    Restore-File -Name 'Fastfetch/logo' -Source (Join-Path $ConfigRoot 'fastfetch\frieren.txt') -Target (Join-Path $env:USERPROFILE 'fastfetch\frieren.txt')
}

# CAVA
if (Test-Path (Join-Path $ConfigRoot 'cava\config')) {
    Restore-File -Name 'CAVA/config' -Source (Join-Path $ConfigRoot 'cava\config') -Target (Join-Path $env:USERPROFILE '.config\cava\config')
}
if (Test-Path (Join-Path $ConfigRoot 'cava\yasb_cava_config_1')) {
    Restore-File -Name 'CAVA/yasb_config' -Source (Join-Path $ConfigRoot 'cava\yasb_cava_config_1') -Target (Join-Path $env:LOCALAPPDATA 'YASB\yasb_cava_config_1')
}

# HideTaskbar
if (Test-Path (Join-Path $ConfigRoot 'hidetaskbar\HideTaskbar.exe')) {
    Restore-File -Name 'HideTaskbar' -Source (Join-Path $ConfigRoot 'hidetaskbar\HideTaskbar.exe') -Target (Join-Path $env:USERPROFILE 'Downloads\HideTaskbar.exe')
}

# GlazeTiler
if (Test-Path (Join-Path $ConfigRoot 'glazetiler\glazetiler.exe')) {
    Restore-File -Name 'GlazeTiler' -Source (Join-Path $ConfigRoot 'glazetiler\glazetiler.exe') -Target (Join-Path $env:USERPROFILE '.cargo\bin\glazetiler.exe')
}

# Wallpaper Engine
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

Write-Host ''
Write-Host 'Install/restore summary' -ForegroundColor White
$Results | Group-Object Status | Sort-Object Name | ForEach-Object { Write-Host ("{0}: {1}" -f $_.Name, $_.Count) }
Write-Host 'Existing targets were moved to timestamped backups before overwrite.' -ForegroundColor Green
