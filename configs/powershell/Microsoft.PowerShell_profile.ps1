# 1. โหลด Oh My Posh จาก Cache (ความเร็วหลักร้อย ms)
. "$HOME\.config\omp_cache.ps1"

# 2. ผูกคีย์ลัดสำหรับเรียก Fastfetch แมนนวล
Set-Alias -Name fastfetch -Value "$HOME\fastfetch\fastfetch.exe"

# 3. สร้างฟังก์ชันทางลัด พิมพ์ ff
function ff {
    fastfetch -c "$HOME\fastfetch\fastfetch.json"
}

# 4. ฟังก์ชันเรียกท่อพักหน้าจอ (Pipes Animation)
function pipes {
    if (Get-Command pipes-rs -ErrorAction SilentlyContinue) {
        pipes-rs
    } else {
        Write-Host "pipes-rs is not installed. Run: scoop install pipes-rs" -ForegroundColor Yellow
    }
}
Set-Alias -Name pipe -Value pipes

# 5. Hyprland CLI Shortcuts (TUI Arsenal)
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza --icons --group-directories-first $args }
    function ll { eza -l --icons --git --group-directories-first $args }
    function la { eza -la --icons --git --group-directories-first $args }
    function lt { eza --tree --level=2 --icons $args }
}

if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias -Name cat -Value bat
}

if (Get-Command lazygit -ErrorAction SilentlyContinue) {
    Set-Alias -Name lg -Value lazygit
}

if (Get-Command yazi -ErrorAction SilentlyContinue) {
    Set-Alias -Name y -Value yazi
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& zoxide init powershell | Out-String)
}

# 6. Local Tools PATH (~/.config/tools for sigye, unimatrix, etc.)
$toolsDir = "$HOME\.config\tools"
if ((Test-Path $toolsDir) -and ($env:PATH -notlike "*$toolsDir*")) {
    $env:PATH = "$toolsDir;" + $env:PATH
}

# 7. Terminal Clock (Aesthetic ASCII / TUI Clock)
function Show-AsciiClock {
    try {
        [Console]::CursorVisible = $false
        Clear-Host
        $digits = @{
            '0' = @('█████','█   █','█   █','█   █','█████')
            '1' = @('  ██ ',' ███ ','   █ ','   █ ',' █████')
            '2' = @('█████','    █','█████','█    ','█████')
            '3' = @('█████','    █','█████','    █','█████')
            '4' = @('█   █','█   █','█████','    █','    █')
            '5' = @('█████','█    ','█████','    █','█████')
            '6' = @('█████','█    ','█████','█   █','█████')
            '7' = @('█████','    █','   ██','  █  ',' █   ')
            '8' = @('█████','█   █','█████','█   █','█████')
            '9' = @('█████','█   █','█████','    █','█████')
            ':' = @('     ','  █  ','     ','  █  ','     ')
            ' ' = @('     ','     ','     ','     ','     ')
        }
        while (-not [Console]::KeyAvailable) {
            $timeStr = (Get-Date).ToString('HH:mm:ss')
            $dateStr = (Get-Date).ToString('dddd, MMMM dd, yyyy')
            [Console]::SetCursorPosition(0, 0)
            Write-Host "`n  Press any key to exit clock...`n" -ForegroundColor DarkGray
            for ($row = 0; $row -lt 5; $row++) {
                $line = "  "
                foreach ($char in $timeStr.ToCharArray()) {
                    $cStr = "$char"
                    $line += $digits[$cStr][$row] + "  "
                }
                Write-Host $line -ForegroundColor Cyan
            }
            Write-Host "`n  $dateStr`n" -ForegroundColor Magenta
            Start-Sleep -Milliseconds 500
        }
        [void][Console]::ReadKey($true)
    } finally {
        [Console]::CursorVisible = $true
        Clear-Host
    }
}

function clock {
    $sigye = "$HOME\.config\tools\sigye.exe"
    if (Test-Path $sigye) {
        & $sigye @args
    } elseif (Get-Command sigye -ErrorAction SilentlyContinue) {
        sigye @args
    } else {
        Show-AsciiClock
    }
}

# 8. Terminal Screensaver: Unimatrix (Digital Matrix Rain)
function unimatrix {
    $uniPy = "$HOME\.config\tools\unimatrix.py"
    if (Test-Path $uniPy) {
        python -X utf8 $uniPy @args
    } elseif (Get-Command unimatrix -ErrorAction SilentlyContinue) {
        unimatrix @args
    } else {
        Write-Host "Unimatrix requires Python and windows-curses. Run: pip install windows-curses" -ForegroundColor Yellow
    }
}
Set-Alias -Name matrix -Value unimatrix

# 9. 6e5tz Universal Wallpaper Manager CLI
function wp-mgr {
    $mgr = "$HOME\.config\6e5tz\scripts\wallpaper\manager.ps1"
    if (-not (Test-Path $mgr)) { $mgr = "$HOME\.config\yasb\scripts\next-wallpaper.ps1" }
    & $mgr @args
}
function wp-status { wp-mgr -Action status }
function wp-next { wp-mgr -Action next @args }
function wp-prev { wp-mgr -Action prev @args }
function wp-shuffle { wp-mgr -Action shuffle @args }
function wp-gallery { wp-mgr -Action gallery }
function wp-provider { param([string]$Name) if ($Name) { wp-mgr -Action provider -Provider $Name } else { wp-mgr -Action provider } }
Set-Alias -Name wp-engine -Value wp-provider
function wp-collection { param([string]$Name) if ($Name) { wp-mgr -Action collection -Collection $Name } else { wp-mgr -Action collection } }
function wp-refresh {
    $foldersScript = "$HOME\.config\6e5tz\scripts\wallpaper\collections\folders.ps1"
    if (Test-Path $foldersScript) { . $foldersScript; Clear-CollectionCache; wp-status } else { wp-status }
}

function next-wallpaper {
    wp-next @args
}

# 10. สั่งให้รัน Fastfetch (น้องฟรีเรน) ขึ้นมาทันทีตอนเปิด Terminal
ff
