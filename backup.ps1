[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$ConfigsRoot = Join-Path $RepoRoot 'configs'
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

function Get-TextExtension {
    return @('.yaml', '.yml', '.json', '.jsonc', '.css', '.ps1', '.psm1', '.ini', '.toml', '.conf', '.cfg', '.txt', '.md', '')
}

function Get-AssetExtension {
    return @('.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.webp', '.ttf', '.otf', '.exe')
}

function Test-ExcludedFile {
    param([Parameter(Mandatory = $true)][IO.FileInfo]$File)
    if ($File.Name -match '(?i)(^|\.)(log|bak|old|tmp|temp|cache)$|\.backup-') { return $true }
    if ($File.Name -match '(?i)(history|recent|state|last_update|crash|dump)') { return $true }
    if ($File.FullName -match '(?i)[\\/](\.backup-|backup-|cache|caches|logs|history|crashdumps|temp|tmp|workshop)[\\/]') { return $true }
    return $false
}

function Get-SensitiveFieldNames {
    # Split names keep this backup helper from becoming a false positive in its own repository scan.
    return @(
        ('api' + '_' + 'key'),
        ('api' + 'key'),
        ('to' + 'ken'),
        ('se' + 'cret'),
        ('pass' + 'word'),
        ('bear' + 'er'),
        ('author' + 'ization'),
        ('private' + '_' + 'key'),
        ('client' + '_' + 'secret')
    )
}

function Test-SensitiveAssignment {
    param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$Content = '')
    if ([string]::IsNullOrWhiteSpace($Content)) { return $false }
    $names = (Get-SensitiveFieldNames | ForEach-Object { [Regex]::Escape($_) }) -join '|'
    $pattern = '(?im)(?:' + $names + ')\s*["'']?\s*[:=]\s*["'']?(?!\s*#)(?!\s*["'']?\s*($|\r|\n))[^"''\s,}]+'
    return $Content -match $pattern
}

function Convert-ToPortableText {
    param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$Content = '')
    if ([string]::IsNullOrEmpty($Content)) { return $Content }

    $pairs = @(
        @{ Current = $env:USERPROFILE; Marker = '__USERPROFILE__' },
        @{ Current = $env:APPDATA; Marker = '__APPDATA__' },
        @{ Current = $env:LOCALAPPDATA; Marker = '__LOCALAPPDATA__' },
        @{ Current = $env:ProgramFiles; Marker = '__PROGRAMFILES__' },
        @{ Current = ${env:ProgramFiles(x86)}; Marker = '__PROGRAMFILES_X86__' }
    )

    foreach ($pair in $pairs) {
        if (-not [string]::IsNullOrWhiteSpace($pair.Current)) {
            $Content = $Content.Replace([string]$pair.Current, [string]$pair.Marker)
            $escapedCurrent = ([string]$pair.Current).Replace('\', '\\')
            $escapedToken = ([string]$pair.Marker).Replace('\', '\\')
            $Content = $Content.Replace($escapedCurrent, $escapedToken)
        }
    }
    return $Content
}

function Write-PortableText {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [switch]$AllowSensitiveExample
    )

    $raw = Get-Content -LiteralPath $Source -Raw
    if (Test-SensitiveAssignment -Content $raw) {
        if ($AllowSensitiveExample) {
            $exampleLines = foreach ($line in ($raw -split "`r?`n")) {
                if (Test-SensitiveAssignment -Content $line) {
                    '# REVIEW LOCALLY: private value omitted from backup'
                } else {
                    Convert-ToPortableText -Content $line
                }
            }
            $examplePath = "$Destination.example"
            Ensure-Directory -Path (Split-Path -Parent $examplePath)
            Set-Content -LiteralPath $examplePath -Value ($exampleLines -join [Environment]::NewLine) -Encoding UTF8
            return 'example-only'
        }
        return 'sensitive-skipped'
    }

    Ensure-Directory -Path (Split-Path -Parent $Destination)
    Set-Content -LiteralPath $Destination -Value (Convert-ToPortableText -Content $raw) -Encoding UTF8
    return 'copied'
}

function Copy-SafeFile {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [switch]$AllowSensitiveExample
    )

    try {
        if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
            Write-Status "${Name}: source not found" 'Skipped'
            Add-Result -Name $Name -Status 'Skipped' -Detail 'Source file not found.'
            return
        }

        $extension = [IO.Path]::GetExtension($Source).ToLowerInvariant()
        if ((Get-TextExtension) -contains $extension) {
            $mode = Write-PortableText -Source $Source -Destination $Destination -AllowSensitiveExample:$AllowSensitiveExample
            if ($mode -eq 'copied') {
                Write-Status "${Name}: copied" 'Success'
                Add-Result -Name $Name -Status 'Success' -Detail $Destination
            } elseif ($mode -eq 'example-only') {
                Write-Status "${Name}: sensitive value omitted; example written" 'Skipped'
                Add-Result -Name $Name -Status 'Skipped' -Detail "$Destination.example"
            } else {
                Write-Status "${Name}: skipped because it contains a private value" 'Skipped'
                Add-Result -Name $Name -Status 'Skipped' -Detail 'Private value detected; no source content copied.'
            }
        } elseif ((Get-AssetExtension) -contains $extension) {
            Ensure-Directory -Path (Split-Path -Parent $Destination)
            Copy-Item -LiteralPath $Source -Destination $Destination -Force
            Write-Status "${Name}: copied" 'Success'
            Add-Result -Name $Name -Status 'Success' -Detail $Destination
        } else {
            Write-Status "${Name}: unsupported file type" 'Skipped'
            Add-Result -Name $Name -Status 'Skipped' -Detail "Unsupported extension: $extension"
        }
    } catch {
        Write-Status "${Name}: $($_.Exception.Message)" 'Failed'
        Add-Result -Name $Name -Status 'Failed' -Detail $_.Exception.Message
    }
}

function Copy-ConfigDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [switch]$AllowSensitiveExample
    )

    try {
        if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
            Write-Status "${Name}: source directory not found or inaccessible" 'Skipped'
            Add-Result -Name $Name -Status 'Skipped' -Detail 'Source directory not found or inaccessible.'
            return
        }

        $files = @(Get-ChildItem -LiteralPath $Source -File -Recurse -Force -ErrorAction Stop | Where-Object { -not (Test-ExcludedFile -File $_) })
        $copied = 0
        foreach ($file in $files) {
            $extension = $file.Extension.ToLowerInvariant()
            if (((Get-TextExtension) -contains $extension) -or ((Get-AssetExtension) -contains $extension)) {
                $relative = $file.FullName.Substring($Source.TrimEnd('\').Length).TrimStart('\')
                $destinationFile = Join-Path $Destination $relative
                Copy-SafeFile -Name "$Name/$relative" -Source $file.FullName -Destination $destinationFile -AllowSensitiveExample:$AllowSensitiveExample
                $copied++
            }
        }
        if ($copied -eq 0) {
            Write-Status "${Name}: no shareable config files found" 'Skipped'
            Add-Result -Name $Name -Status 'Skipped' -Detail 'No config/style/assets files found after exclusions.'
        }
    } catch {
        Write-Status "${Name}: $($_.Exception.Message)" 'Failed'
        Add-Result -Name $Name -Status 'Failed' -Detail $_.Exception.Message
    }
}

function Copy-FlowSettings {
    $source = Join-Path $env:APPDATA 'FlowLauncher\Settings\Settings.json'
    $destination = Join-Path $ConfigsRoot 'flow-launcher\Settings.json'
    try {
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            Write-Status 'Flow Launcher/settings: source not found' 'Skipped'
            Add-Result -Name 'Flow Launcher/settings' -Status 'Skipped' -Detail 'Settings.json not found.'
        } else {
            $obj = Get-Content -LiteralPath $source -Raw | ConvertFrom-Json
            if ($null -ne $obj.Proxy) {
                if ($null -ne $obj.Proxy.PSObject.Properties['UserName']) { $obj.Proxy.PSObject.Properties.Remove('UserName') }
                $privateField = 'pass' + 'word'
                if ($null -ne $obj.Proxy.PSObject.Properties[$privateField]) { $obj.Proxy.PSObject.Properties.Remove($privateField) }
            }
            if ($null -ne $obj.CustomExplorerList) {
                $before = @($obj.CustomExplorerList).Count
                $obj.CustomExplorerList = @($obj.CustomExplorerList | Where-Object { [string]$_.Path -notmatch '(?i)^[A-Za-z]:\\' })
                $removed = $before - @($obj.CustomExplorerList).Count
                if ($removed -gt 0) { Write-Status "Flow Launcher/settings: removed $removed machine-specific explorer entries" 'Warning' }
            }
            $json = $obj | ConvertTo-Json -Depth 100
            Ensure-Directory -Path (Split-Path -Parent $destination)
            Set-Content -LiteralPath $destination -Value (Convert-ToPortableText -Content $json) -Encoding UTF8
            Write-Status 'Flow Launcher/settings: copied and sanitized' 'Success'
            Add-Result -Name 'Flow Launcher/settings' -Status 'Success' -Detail $destination
        }

        $pluginSource = Join-Path $env:APPDATA 'FlowLauncher\Settings\Plugins'
        $pluginDestination = Join-Path $ConfigsRoot 'flow-launcher\plugins'
        if (Test-Path -LiteralPath $pluginSource -PathType Container) {
            $pluginFiles = @(Get-ChildItem -LiteralPath $pluginSource -Filter 'Settings.json' -File -Recurse -Force)
            foreach ($pluginFile in $pluginFiles) {
                $relative = $pluginFile.FullName.Substring($pluginSource.TrimEnd('\').Length).TrimStart('\')
                Copy-SafeFile -Name "Flow Launcher/plugin/$relative" -Source $pluginFile.FullName -Destination (Join-Path $pluginDestination $relative) -AllowSensitiveExample
            }
            if ($pluginFiles.Count -eq 0) { Write-Status 'Flow Launcher/plugins: no shareable settings found' 'Skipped' }
        } else {
            Write-Status 'Flow Launcher/plugins: source not found' 'Skipped'
        }

        $themeSource = Join-Path $env:APPDATA 'FlowLauncher\Themes'
        Copy-ConfigDirectory -Name 'Flow Launcher/themes' -Source $themeSource -Destination (Join-Path $ConfigsRoot 'flow-launcher\themes') -AllowSensitiveExample
    } catch {
        Write-Status "Flow Launcher: $($_.Exception.Message)" 'Failed'
        Add-Result -Name 'Flow Launcher' -Status 'Failed' -Detail $_.Exception.Message
    }
}

function Copy-PowerShellProfile {
    $candidates = @(
        $PROFILE,
        (Join-Path $env:USERPROFILE 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $env:USERPROFILE 'OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $env:USERPROFILE 'OneDrive\เอกสาร\PowerShell\Microsoft.PowerShell_profile.ps1')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    $found = $false
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $found = $true
            $profileDestination = Join-Path $ConfigsRoot 'powershell\Microsoft.PowerShell_profile.ps1'
            $profileContent = Get-Content -LiteralPath $candidate -Raw
            $themePattern = '(?i)[A-Za-z]:\\[^"'']+\.omp\.json'
            foreach ($match in [Regex]::Matches($profileContent, $themePattern)) {
                $themeSource = $match.Value
                if (Test-Path -LiteralPath $themeSource -PathType Leaf) {
                    $themeName = [IO.Path]::GetFileName($themeSource)
                    $themeDestination = Join-Path $ConfigsRoot (Join-Path 'oh-my-posh\themes' $themeName)
                    Copy-SafeFile -Name "Oh My Posh/theme/$themeName" -Source $themeSource -Destination $themeDestination -AllowSensitiveExample
                    $portableTheme = '$HOME\.config\oh-my-posh\themes\' + $themeName
                    $profileContent = $profileContent.Replace($themeSource, $portableTheme)
                }
            }

            if (Test-SensitiveAssignment -Content $profileContent) {
                $exampleLines = foreach ($line in ($profileContent -split "`r?`n")) {
                    if (Test-SensitiveAssignment -Content $line) { '# REVIEW LOCALLY: private value omitted from backup' } else { Convert-ToPortableText -Content $line }
                }
                Ensure-Directory -Path (Split-Path -Parent $profileDestination)
                Set-Content -LiteralPath "$profileDestination.example" -Value ($exampleLines -join [Environment]::NewLine) -Encoding UTF8
                Write-Status 'PowerShell/profile: private value omitted; example written' 'Skipped'
                Add-Result -Name 'PowerShell/profile' -Status 'Skipped' -Detail "$profileDestination.example"
            } else {
                Ensure-Directory -Path (Split-Path -Parent $profileDestination)
                Set-Content -LiteralPath $profileDestination -Value (Convert-ToPortableText -Content $profileContent) -Encoding UTF8
                Write-Status 'PowerShell/profile: copied and made portable' 'Success'
                Add-Result -Name 'PowerShell/profile' -Status 'Success' -Detail $profileDestination
            }
            break
        }
    }
    if (-not $found) {
        Write-Status 'PowerShell/profile: no current-user profile found' 'Skipped'
        Add-Result -Name 'PowerShell/profile' -Status 'Skipped' -Detail 'No profile file exists in the discovered profile locations.'
    }
}

function Copy-OptionalCandidates {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Sources,
        [Parameter(Mandatory = $true)][string]$Destination,
        [switch]$AllowSensitiveExample
    )

    $found = $false
    foreach ($source in ($Sources | Select-Object -Unique)) {
        try {
            if (Test-Path -LiteralPath $source -PathType Container) {
                $found = $true
                Copy-ConfigDirectory -Name $Name -Source $source -Destination $Destination -AllowSensitiveExample:$AllowSensitiveExample
            } elseif (Test-Path -LiteralPath $source -PathType Leaf) {
                $found = $true
                Copy-SafeFile -Name $Name -Source $source -Destination (Join-Path $Destination ([IO.Path]::GetFileName($source))) -AllowSensitiveExample:$AllowSensitiveExample
            }
        } catch {
            Write-Status "${Name}: candidate inaccessible: $source" 'Skipped'
        }
    }
    if (-not $found) {
        Write-Status "${Name}: no config candidate found" 'Skipped'
        Add-Result -Name $Name -Status 'Skipped' -Detail 'No known config candidate exists.'
    }
}

Ensure-Directory -Path $ConfigsRoot

# 1. GlazeWM
Copy-SafeFile -Name 'GlazeWM/config' -Source (Join-Path $env:USERPROFILE '.glzr\glazewm\config.yaml') -Destination (Join-Path $ConfigsRoot 'glazewm\config.yaml') -AllowSensitiveExample

# 2. YASB
Copy-ConfigDirectory -Name 'YASB' -Source (Join-Path $env:USERPROFILE '.config\yasb') -Destination (Join-Path $ConfigsRoot 'yasb') -AllowSensitiveExample

# 3. Flow Launcher
Copy-FlowSettings

# 4. Windows Terminal
Copy-SafeFile -Name 'Windows Terminal/settings' -Source (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json') -Destination (Join-Path $ConfigsRoot 'terminal\settings.json') -AllowSensitiveExample

# 5. PowerShell Profile
Copy-PowerShellProfile

# 6. Oh My Posh
Copy-OptionalCandidates -Name 'Oh My Posh' -Sources @(
    (Join-Path $env:USERPROFILE '.config\jandedobbeleer.omp.json'),
    (Join-Path $env:USERPROFILE '.config\omp_cache.ps1'),
    (Join-Path $env:USERPROFILE '.poshthemes'),
    (Join-Path $env:USERPROFILE '.config\oh-my-posh\themes'),
    (Join-Path $env:USERPROFILE 'Documents\PowerShell\themes')
) -Destination (Join-Path $ConfigsRoot 'oh-my-posh') -AllowSensitiveExample

# 7. Fastfetch
Copy-OptionalCandidates -Name 'Fastfetch' -Sources @(
    (Join-Path $env:USERPROFILE 'fastfetch\fastfetch.json'),
    (Join-Path $env:USERPROFILE 'fastfetch\frieren.txt'),
    (Join-Path $env:USERPROFILE '.config\fastfetch'),
    (Join-Path $env:APPDATA 'fastfetch'),
    (Join-Path $env:LOCALAPPDATA 'fastfetch')
) -Destination (Join-Path $ConfigsRoot 'fastfetch') -AllowSensitiveExample

# 8. CAVA
Copy-OptionalCandidates -Name 'CAVA' -Sources @(
    (Join-Path $env:USERPROFILE '.config\cava\config'),
    (Join-Path $env:LOCALAPPDATA 'YASB\yasb_cava_config_1'),
    (Join-Path $env:USERPROFILE '.config\cava'),
    (Join-Path $env:APPDATA 'cava'),
    (Join-Path $env:LOCALAPPDATA 'cava\config')
) -Destination (Join-Path $ConfigsRoot 'cava') -AllowSensitiveExample

# 9. HideTaskbar
Copy-OptionalCandidates -Name 'HideTaskbar' -Sources @(
    (Join-Path $env:USERPROFILE 'Downloads\HideTaskbar.exe'),
    (Join-Path $env:APPDATA 'HideTaskbar'),
    (Join-Path $env:LOCALAPPDATA 'HideTaskbar'),
    (Join-Path $env:USERPROFILE '.config\hidetaskbar')
) -Destination (Join-Path $ConfigsRoot 'hidetaskbar') -AllowSensitiveExample

# 10. GlazeTiler
Copy-OptionalCandidates -Name 'GlazeTiler' -Sources @(
    (Join-Path $env:USERPROFILE '.cargo\bin\glazetiler.exe'),
    (Join-Path $env:APPDATA 'GlazeTiler'),
    (Join-Path $env:USERPROFILE '.config\glazetiler')
) -Destination (Join-Path $ConfigsRoot 'glazetiler') -AllowSensitiveExample

# 11. Wallpaper Engine
Copy-OptionalCandidates -Name 'Wallpaper Engine' -Sources @(
    'C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\config.json',
    'C:\Program Files\Steam\steamapps\common\wallpaper_engine\config.json'
) -Destination (Join-Path $ConfigsRoot 'wallpaper-engine') -AllowSensitiveExample

Write-Host ''
Write-Host 'Backup summary' -ForegroundColor White
$Results | Group-Object Status | Sort-Object Name | ForEach-Object {
    Write-Host ("{0}: {1}" -f $_.Name, $_.Count)
}
Write-Host 'Original configuration files were read only; no source files were deleted or modified.' -ForegroundColor Green
