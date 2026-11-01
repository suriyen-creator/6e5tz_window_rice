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

# 6. สั่งให้รัน Fastfetch (น้องฟรีเรน) ขึ้นมาทันทีตอนเปิด Terminal
ff
