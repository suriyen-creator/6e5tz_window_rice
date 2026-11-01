# 1. Load Oh My Posh (Cache with fallback)
if (Test-Path "$HOME\.config\omp_cache.ps1") {
    try {
        . "$HOME\.config\omp_cache.ps1"
    } catch {
        if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
            $ompTheme = if (Test-Path "$HOME\.config\jandedobbeleer.omp.json") { "$HOME\.config\jandedobbeleer.omp.json" } else { "jandedobbeleer" }
            oh-my-posh init pwsh --config $ompTheme | Invoke-Expression
        }
    }
} elseif (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $ompTheme = if (Test-Path "$HOME\.config\jandedobbeleer.omp.json") { "$HOME\.config\jandedobbeleer.omp.json" } else { "jandedobbeleer" }
    oh-my-posh init pwsh --config $ompTheme | Invoke-Expression
}

# 2. Fastfetch Alias
if (-not (Get-Command fastfetch -ErrorAction SilentlyContinue)) {
    if (Test-Path "$HOME\fastfetch\fastfetch.exe") {
        Set-Alias -Name fastfetch -Value "$HOME\fastfetch\fastfetch.exe"
    }
}

# 3. Shortcut ff for Fastfetch
function ff {
    $ffConfig = if (Test-Path "$HOME\fastfetch\fastfetch.json") {
        "$HOME\fastfetch\fastfetch.json"
    } elseif (Test-Path "$HOME\.config\fastfetch\fastfetch.json") {
        "$HOME\.config\fastfetch\fastfetch.json"
    } else {
        $null
    }
    if ($ffConfig) {
        fastfetch -c $ffConfig
    } else {
        fastfetch
    }
}

