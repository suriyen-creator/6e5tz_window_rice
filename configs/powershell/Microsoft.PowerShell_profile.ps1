# 1. โหลด Oh My Posh จาก Cache (ความเร็วหลักร้อย ms)
. "$HOME\.config\omp_cache.ps1"

# 2. ผูกคีย์ลัดสำหรับเรียก Fastfetch แมนนวล
Set-Alias -Name fastfetch -Value "$HOME\fastfetch\fastfetch.exe"

# 3. สร้างฟังก์ชันทางลัด พิมพ์ ff
function ff {
    fastfetch -c "$HOME\fastfetch\fastfetch.json"
}

# 4. สั่งให้รัน Fastfetch (น้องฟรีเรน) ขึ้นมาทันทีตอนเปิด Terminal
ff
