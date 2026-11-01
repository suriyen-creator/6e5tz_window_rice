# 🌸 6e5tz Windows Desktop Dotfiles (Rice)

[![Windows 10 / 11](https://img.shields.io/badge/Windows-10%20%7C%2011-blue?logo=windows)](https://github.com/suriyen-creator/6e5tz_window_rice)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

A clean, aesthetic pastel-themed Windows tiling desktop setup featuring **GlazeWM**, **YASB**, **Flow Launcher**, **Oh My Posh**, **CAVA**, **Fastfetch** (with Frieren ASCII art), **Btop**, **ExplorerBlurMica**, **Spicetify**, **ModernFlyouts**, and **Vencord**.

---

## ⚡ Quick Install (ลงง่ายใน 1 คำสั่ง)

เปิด **PowerShell** (Run as Administrator แนะนำ) แล้วคัดลอกคำสั่งด้านล่างนี้ไปวางแล้วกด `Enter`:

```powershell
irm https://raw.githubusercontent.com/suriyen-creator/6e5tz_window_rice/main/install.ps1 | iex
```

### สิ่งที่ตัวติดตั้งจะทำให้อัตโนมัติ:
1. **ดาวน์โหลดโปรเจกต์** ลงใน `$HOME\.dotfiles\window_rice`
2. **เมนูติดตั้งแบบ Interactive:**
   - `[1] Full Installation`: ติดตั้งโปรแกรมที่ต้องใช้ทั้งหมดผ่าน WinGet + ติดตั้ง MesloLGL Nerd Font + วางคอนฟิกทั้งหมด
   - `[2] Deploy Configs Only`: สำหรับคนที่มีโปรแกรมครบแล้ว ต้องการเฉพาะไฟล์คอนฟิก
   - `[3] Install Font Only`: ติดตั้งเฉพาะฟอนต์ MesloLGL Nerd Font
3. **Backup อัตโนมัติ:** คอนฟิกเดิมของคุณจะถูกสำรองไว้เป็น `.backup-<timestamp>` เสมอ ไม่มีไฟล์หายแน่นอน
4. **เปิดใช้งาน GlazeWM & YASB ทันที** เมื่อติดตั้งเสร็จ

---

## 🛠 Manual Installation (ลงแบบโคลนเอง)

หากต้องการโคลนและตรวจดูไฟล์ก่อนติดตั้ง:

```powershell
# 1. โคลน Repository
git clone https://github.com/suriyen-creator/6e5tz_window_rice.git
cd 6e5tz_window_rice

# 2. รันตัวติดตั้ง
.\install.ps1
```

### คำสั่งเพิ่มเติม (Flags):
```powershell
# ลงเฉพาะคอนฟิก (ข้ามการโหลดโปรแกรม WinGet)
.\install.ps1 -ConfigOnly

# ติดตั้งแบบไม่ถาม (Non-interactive)
.\install.ps1 -Full -NonInteractive
```

---

## ⌨️ Essential Hotkeys (คีย์ลัดสำคัญที่ต้องรู้)

| Hotkey | คำสั่ง / การทำงาน |
| --- | --- |
| `Alt + Space` | เปิด **Flow Launcher** (ค้นหาแอป/ไฟล์/คำสั่ง) |
| `Alt + 1` .. `Alt + 9` | สลับ Workspace 1 ถึง 9 ใน **GlazeWM** |
| `Alt + Shift + 1..9` | ย้ายหน้าต่างปัจจุบันไปยัง Workspace นั้นๆ |
| `Alt + H / J / K / L` | เลื่อนโฟกัสหน้าต่าง (ซ้าย / ล่าง / บน / ขวา) |
| `Alt + Shift + H/J/K/L` | ย้ายตำแหน่งหน้าต่าง (Tile Move) |
| `Alt + V` | สลับโหมดการแยกหน้าต่าง (Horizontal / Vertical Split) |
| `Alt + F` | สลับโหมดเต็มจอ (Toggle Fullscreen) |
| `Alt + Shift + Space` | สลับหน้าต่างเป็นโหมดลอย (Toggle Floating) |
| `Alt + R` | เข้าสู่โหมดปรับขนาดหน้าต่าง (Resize Mode) |
| `Alt + Shift + Q` | ปิดหน้าต่างปัจจุบัน (Close Window) |
| `Alt + Shift + E` | ออกจาก GlazeWM |
| พิมพ์ `ff` ใน PowerShell | แสดง **Fastfetch** พร้อมรูป Frieren ASCII Art และสเปกเครื่อง |
| พิมพ์ `btop` ใน PowerShell | เปิดดูการทำงานของ CPU / RAM / GPU / Process ด้วย **Btop** (Catppuccin Mocha) |

---

## 📦 Software & Components

| Software | รายละเอียด | คอนฟิกใน Repo |
| --- | --- | --- |
| **GlazeWM** | Tiling Window Manager สำหรับ Windows | `configs/glazewm/config.yaml` |
| **YASB** | Status Bar ด้านบนสไตล์ Polybar/Waybar | `configs/yasb/config.yaml`, `styles.css` |
| **Flow Launcher** | Spotlight-like App Launcher (`Alt+Space`) | `configs/flow-launcher/` |
| **Fastfetch** | System Fetch พร้อมรูป Frieren และไอคอน Windows | `configs/fastfetch/fastfetch.json`, `frieren.txt` |
| **Oh My Posh** | ตกแต่ง PowerShell Prompt สไตล์โมเดิร์น | `configs/oh-my-posh/jandedobbeleer.omp.json` |
| **CAVA** | Audio Visualizer คลื่นเสียงบน YASB | `configs/cava/config`, ธีมสี |
| **Windows Terminal** | ธีมและฟอนต์โปร่งแสง Acrylic | `configs/terminal/settings.json` |
| **PowerShell 7** | `$PROFILE` คำสั่งลัด `ff` และโหลด OMP อัตโนมัติ | `configs/powershell/` |
| **HideTaskbar** | ซ่อน Windows Taskbar ดั้งเดิม | `configs/hidetaskbar/HideTaskbar.exe` |
| **GlazeTiler** | ออโต้ไทล์เสริมสำหรับ GlazeWM | `configs/glazetiler/glazetiler.exe` |
| **Btop** | TUI Hardware & Process Monitor ธีม Catppuccin Mocha | `configs/btop/btop.conf`, themes |
| **ExplorerBlurMica** | เอฟเฟกต์ Acrylic Blur + Catppuccin Dark Tint บน Windows Explorer | `configs/explorer-blur-mica/` |
| **Spicetify** | ปรับแต่ง UI ของ Spotify Desktop ธีม Catppuccin Mocha | `configs/spicetify/` |
| **ModernFlyouts** | Modern Fluent OSD แถบเสียง/มีเดียแบบโปร่งแสง | ติดตั้งผ่าน WinGet |
| **Vencord** | Discord Client Mod พร้อมธีม Catppuccin Mocha | `configs/vencord/` |

---

## 🎨 Post-Installation Guide (การเปิดใช้งานโมดูลเสริม)

1. **ExplorerBlurMica (ทำให้ File Explorer โปร่งแสง):**
   - ไปที่ `~/.config/ExplorerBlurMica`
   - คลิกขวาที่ `register.cmd` แล้วเลือก **Run as administrator** เพื่อลงทะเบียน Shell Extension
   - หากต้องการยกเลิก ให้รัน `uninstall.cmd` แบบ Administrator

2. **Spicetify (ธีม Catppuccin Spotify):**
   - เมื่อมี Spotify Desktop ติดตั้งอยู่แล้ว ให้รันคำสั่งใน PowerShell:
     ```powershell
     spicetify backup apply
     ```
   - หากต้องการอัปเดตคอนฟิกในอนาคต รัน `spicetify apply`

3. **Vencord (ธีม Catppuccin Discord):**
   - สคริปต์ติดตั้งจะทำการแพตช์ Discord ให้อัตโนมัติและวางธีมไว้ที่ `%APPDATA%\Vencord\themes\catppuccin-mocha.theme.css`
   - เมื่อเปิด Discord สามารถไปที่ `Settings > Vencord > Themes` เพื่อตรวจสอบการเปิดใช้งาน

---

## 💾 How to Backup your changes (การเซฟการตั้งค่ากลับเข้า Repo)

หากคุณปรับแต่งตำแหน่งแท็บ สี หรือคีย์ลัดเพิ่มเติม และต้องการแบ็กอัปกลับมาที่โฟลเดอร์ repository:

```powershell
.\backup.ps1
```

สคริปต์จะแปลงพาธชื่อผู้ใช้ให้เป็นค่าพกพา (`__USERPROFILE__`, `__APPDATA__` ฯลฯ) และตัดรหัสผ่าน/โทเค็นส่วนตัวออกให้อัตโนมัติ ปลอดภัยต่อการ `git push`

---

## 💖 Credits & Acknowledgments

- **Base YASB + GlazeWM Configuration:** Based on [SleepyCatHey/Yasb-GlazeWM-Config](https://github.com/SleepyCatHey/Yasb-GlazeWM-Config) by [@SleepyCatHey](https://github.com/SleepyCatHey).
- **Catppuccin Theme Community:** [catppuccin/catppuccin](https://github.com/catppuccin) for the soothing pastel palette across Btop, Spicetify, Vencord, and ExplorerBlurMica.
- **Fastfetch Frieren ASCII Art:** Anime braille art community.
- **Tools & Projects:**
  - [GlazeWM](https://github.com/glzr-io/glazewm)
  - [YASB](https://github.com/amnweb/yasb)
  - [Flow Launcher](https://github.com/Flow-Launcher/Flow.Launcher)
  - [Oh My Posh](https://ohmyposh.dev/)
  - [Fastfetch](https://github.com/fastfetch-cli/fastfetch)
  - [CAVA](https://github.com/karlstav/cava)
  - [btop4win](https://github.com/aristocratos/btop4win)
  - [ExplorerBlurMica](https://github.com/Maplespe/ExplorerBlurMica)
  - [Spicetify](https://github.com/spicetify/cli)
  - [ModernFlyouts](https://github.com/ModernFlyouts-Community/ModernFlyouts)
  - [Vencord](https://github.com/Vendicated/Vencord)
