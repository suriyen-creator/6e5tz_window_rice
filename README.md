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

# บังคับเลือกโหมด Wallpaper (Static หรือ WallpaperEngine)
.\install.ps1 -WallpaperMode Static
.\install.ps1 -WallpaperMode WallpaperEngine
```

---

## 🖼️ Wallpaper System (ระบบสลับวอลเปเปอร์ 2 โหมด: Wallpaper Engine / Static Gallery)

ระบบรองรับทั้งผู้ใช้งานที่มี **Wallpaper Engine** (Steam) และผู้ที่ไม่มี (ใช้ภาพ **Static Wallpapers** ปกติของ Windows):

### 1. โหมด Wallpaper Engine (ค่าเริ่มต้นเมื่อตรวจพบ Steam / Wallpaper Engine)
- **การควบคุมบนแถบ YASB (ไอคอน 󰸉):**
  - **คลิกซ้าย:** สลับไปวอลเปเปอร์ถัดไปทันที (`nextWallpaper`)
  - **คลิกขวา:** สลับหยุดชั่วคราว / เล่นต่อ (`Pause / Resume`) อนิเมชัน
  - **คลิกกลาง:** เปิดหน้าต่างตั้งค่า Wallpaper Engine
- คอนฟิกต้นฉบับอยู่ที่ [config.wallpaper-engine.yaml](file:///C:/Users/suriy/Documents/window_rice/configs/yasb/config.wallpaper-engine.yaml)

### 2. โหมด Static Wallpapers (สำหรับคนไม่มี Wallpaper Engine หรือชอบภาพนิ่ง)
- **การควบคุมบนแถบ YASB (ไอคอน 󰸉):**
  - **คลิกซ้าย:** เปิด **Popup Gallery** สวยงาม แสดงรูปตัวอย่างขนาดย่อ (Thumbnails) เลื่อนหน้าได้ และคลิกเพื่อเปลี่ยน Wallpaper หน้าจอ Windows ได้ทันที
  - ดึงรูปภาพอัตโนมัติจากโฟลเดอร์ `~/Pictures/Wallpapers/`
  - มีภาพตัวอย่าง Anime Wallpapers ความละเอียดสูง 10 รูปแถมมาให้ในตัวโปรเจกต์ (`wallpapers/`)
- คอนฟิกต้นฉบับอยู่ที่ [config.static.yaml](file:///C:/Users/suriy/Documents/window_rice/configs/yasb/config.static.yaml)

### 🔄 วิธีสลับโหมด Wallpaper ได้ทุกเมื่อ:
คุณสามารถรันสคริปต์สลับโหมดได้ทันที (ระบบจะสลับคอนฟิกและรีสตาร์ต YASB ให้แบบไร้รอยต่อ):

```powershell
# เปิดเมนูเลือกโหมด (Interactive Menu)
.\scripts\switch-wallpaper-mode.ps1

# หรือสั่งสลับตรงๆ
.\scripts\switch-wallpaper-mode.ps1 -Mode Static
.\scripts\switch-wallpaper-mode.ps1 -Mode WallpaperEngine
```

---

## ⌨️ Keyboard Shortcuts & Controls (สารบัญคีย์ลัดฉบับสมบูรณ์ - Dual Mode: Alt / Super)

> [!TIP]
> **Hyprland Experience:** ระบบรองรับทั้งปุ่ม **`Super` (Windows Key)** และปุ่ม **`Alt`** สลับใช้งานได้ตามความถนัดแบบ 100%!

### 1. 🪟 GlazeWM - โฟกัสและการเคลื่อนย้าย (Navigation & Focus)
| Hyprland (Super) | Windows (Alt) | คำสั่ง / การทำงาน |
| --- | --- | --- |
| `Super + H` / `Left` | `Alt + H` / `Left` | เลื่อนโฟกัสไปหน้าต่างซ้าย |
| `Super + L` / `Right` | `Alt + L` / `Right` | เลื่อนโฟกัสไปหน้าต่างขวา |
| `Super + K` / `Up` | `Alt + K` / `Up` | เลื่อนโฟกัสไปหน้าต่างบน |
| `Super + J` / `Down` | `Alt + J` / `Down` | เลื่อนโฟกัสไปหน้าต่างล่าง |
| `Super + Space` | `Alt + Space` | สลับโฟกัสวน (Cycle Focus: Tiling -> Floating -> Fullscreen) |
| `Super + S` | `Alt + S` | โฟกัสไปยัง Workspace ถัดไปที่มีหน้าต่างเปิดอยู่ (Next Active Workspace) |
| `Super + A` | `Alt + A` | โฟกัสไปยัง Workspace ก่อนหน้าที่มีหน้าต่างเปิดอยู่ (Prev Active Workspace) |
| `Super + D` | `Alt + D` | สลับกลับไปยัง Workspace ล่าสุดที่เพิ่งใช้งาน (Recent Workspace) |

### 2. 🧩 GlazeWM - การจัดการเลย์เอาต์หน้าต่าง (Window Layout & Placement)
| Hyprland (Super) | Windows (Alt) | คำสั่ง / การทำงาน |
| --- | --- | --- |
| `Super + Shift + H` / `Left` | `Alt + Shift + H` / `Left` | ย้ายตำแหน่งหน้าต่างไปทางซ้าย |
| `Super + Shift + L` / `Right` | `Alt + Shift + L` / `Right` | ย้ายตำแหน่งหน้าต่างไปทางขวา |
| `Super + Shift + K` / `Up` | `Alt + Shift + K` / `Up` | ย้ายตำแหน่งหน้าต่างขึ้นบน |
| `Super + Shift + J` / `Down` | `Alt + Shift + J` / `Down` | ย้ายตำแหน่งหน้าต่างลงล่าง |
| `Super + V` | `Alt + Shift + Space` | ปลดหน้าต่างเป็นโหมด Floating (ลอยตรงกลางจอ) |
| `Super + T` | `Alt + T` | เปลี่ยนหน้าต่างปัจจุบันกลับเป็นโหมด Tiling (เรียงต่อกัน) |
| `Super + F` | `Alt + F` | เปิด / ปิดโหมดขยายเต็มหน้าจอ (Toggle Fullscreen) |
| `Super + M` | `Alt + M` | ย่อหน้าต่างลง Taskbar (Minimize Window) |
| `Super + Q` | `Alt + Shift + Q` | **ปิดหน้าต่างที่กำลังโฟกัส (Close Window)** |
| `Alt + V` | `Alt + V` | สลับทิศทางการแยกหน้าต่าง (Horizontal / Vertical Split) |

### 3. 📐 GlazeWM - ปรับขนาดหน้าต่าง (Window Resizing)
| Hotkey | คำสั่ง / การทำงาน |
| --- | --- |
| `Alt + U` / `Alt + P` | ลด / เพิ่มความกว้างของหน้าต่าง (-2% / +2%) |
| `Alt + I` / `Alt + O` | ลด / เพิ่มความสูงของหน้าต่าง (-2% / +2%) |
| `Alt + R` | **เข้าสู่โหมดปรับขนาด (Resize Mode)**: จากนั้นสามารถกด `H/J/K/L` หรือลูกศร `← ↑ ↓ →` เพื่อยืดหดได้อย่างอิสระ แล้วกด `Enter` หรือ `Esc` เพื่อออกจากโหมด |

### 4. 🚀 GlazeWM - Workspaces & Monitors (การสลับพื้นที่ทำงาน)
| Hyprland (Super) | Windows (Alt) | คำสั่ง / การทำงาน |
| --- | --- | --- |
| `Super + 1` .. `Super + 9` | `Alt + 1` .. `Alt + 9` | สลับไปยัง Workspace หมายเลข 1 ถึง 9 |
| `Super + Shift + 1` .. `9` | `Alt + Shift + 1` .. `9` | ย้ายหน้าต่างปัจจุบันไปยัง Workspace นั้นๆ พร้อมสลับหน้าจอตามไปทันที |
| `Super + Shift + A` | `Alt + Shift + A` | ย้าย Workspace ปัจจุบันไปยังจอด้านซ้าย (กรณีต่อหลายจอ) |
| `Super + Shift + F` | `Alt + Shift + F` | ย้าย Workspace ปัจจุบันไปยังจอด้านขวา |
| `Super + Shift + D` | `Alt + Shift + D` | ย้าย Workspace ปัจจุบันไปยังจอด้านบน |
| `Super + Shift + S` | `Alt + Shift + S` | ย้าย Workspace ปัจจุบันไปยังจอด้านล่าง |

### 5. ⚙️ GlazeWM - ควบคุมระบบและกระบวนการ (System Controls)
| Hyprland (Super) | Windows (Alt) | คำสั่ง / การทำงาน |
| --- | --- | --- |
| `Super + Enter` | `Alt + Enter` | **เปิดหน้าต่าง Windows Terminal ทันที** |
| `Super + Shift + C` | `Alt + Shift + R` | โหลดคอนฟิก GlazeWM ใหม่ทันทีโดยไม่ต้องปิดโปรแกรม (Reload Config) |
| `Alt + Shift + W` | `Alt + Shift + W` | วาดหน้าต่างทั้งหมดใหม่ แก้บั๊กจอกระพริบหรือภาพค้าง (Redraw Windows) |
| `Super + Shift + P` | `Alt + Shift + P` | หยุดการทำงาน GlazeWM ชั่วคราว (Pause WM / คืนการควบคุม) กดซ้ำเพื่อเปิดใหม่ |
| `Super + Shift + M` | `Alt + Shift + E` | ออกจาก GlazeWM อย่างปลอดภัย (Exit Process) |

### 6. 🔍 Flow Launcher - ค้นหาและเปิดแอปด่วน (Rofi / Wofi Style)
| Hotkey | คำสั่ง / การทำงาน |
| --- | --- |
| `Ctrl + Space` | **เปิดแถบค้นหา Flow Launcher** (ค้นหาโปรแกรม, ไฟล์, คำนวณเลข, ค้นเว็บ) |
| `F1` | เปิดดูตัวอย่างไฟล์ (Quick Preview) |
| `Ctrl + O` | เปิด Context Menu ของผลการค้นหา |
| `Ctrl + I` | เปิดหน้าต่าง Settings ของ Flow Launcher |
| `Ctrl + H` | ดูประวัติการค้นหาย้อนหลัง (History) |
| `Tab` / `Ctrl + Tab` | เลือกผลลัพธ์ถัดไป / เติมคำอัตโนมัติ (Auto-complete) |
| `Alt + Up` / `Down` | เลื่อนดูประวัติการพิมพ์ย้อนหลัง |

### 7. 💻 The Hyprland TUI Arsenal (ชุดอาวุธเทอร์มินัลระดับโปร)
| Command | คำสั่งย่อ | คำสั่ง / การทำงาน |
| --- | --- | --- |
| `yazi` | `y` | **Yazi Terminal File Manager**: จัดการไฟล์ด้วยความเร็วแสง + Vim keybindings |
| `eza` | `ls`, `ll`, `la`, `lt` | **Eza**: แสดงรายการไฟล์พร้อมไอคอน Nerd Font, สถานะ Git, และ Tree View |
| `bat` | `cat` | **Bat**: แสดงโค้ด/ไฟล์พร้อมสี Catppuccin, ไฮไลต์ไวยากรณ์, และเลขบรรทัด |
| `lazygit` | `lg` | **Lazygit**: Terminal UI สำหรับจัดการ Git แบบมือโปร |
| `zoxide` | `z <folder>` | **Zoxide**: กระโดดไปยังโฟลเดอร์ที่เคยเปิดด้วยความเร็วสูง |
| `fzf` | `fzf` | **FZF**: Interactive Fuzzy Finder ค้นหาไฟล์ฉับไว |
| `fastfetch` | `ff` | เรียก **Fastfetch** พร้อมรูป Frieren ASCII Art และสเปกเครื่องแบบครบถ้วน |
| `btop` | `btop` | เปิดมอนิเตอร์ฮาร์ดแวร์ CPU / GPU / RAM / Network สไตล์ Catppuccin Mocha |
| `pipes-rs` | `pipes`, `pipe` | เปิดอนิเมชันท่อพักหน้าจอแบบเรโทร (60fps สุดคมชัด กด `q` เพื่อออก) |

### 8. 📊 YASB Bar - วิดเจ็ตและการคลิกควบคุม (Top Bar Interactions)
| Widget | คลิกซ้าย / การทำงาน |
| --- | --- |
| **GlazeWM Workspaces (1-9)** | คลิกเพื่อสลับหน้าต่างไปยัง Workspace นั้นๆ |
| **Media Player** | เล่น/หยุดเพลง, คลิกชื่อเพลงเพื่อเปิดโปรแกรมเล่นเพลง |
| **Clock / Date** | เปิดแผงปฏิทินและเวลา |
| **Wallpaper Controller / Gallery (󰸉)** | **โหมด Wallpaper Engine:**<br>- คลิกซ้าย: สลับไปวอลเปเปอร์ถัดไปทันที (`nextWallpaper`)<br>- คลิกขวา: สลับหยุดชั่วคราว / เล่นต่อ (`Pause / Resume`)<br>- คลิกกลาง: เปิดหน้าต่างโปรแกรม Wallpaper Engine<br><br>**โหมด Static Wallpaper:**<br>- คลิกซ้าย: เปิด Gallery Popup เลือกรูปภาพจาก `~/Pictures/Wallpapers` พร้อม Thumbnail |
| **Network / Wi-Fi** | เปิดหน้าต่าง Popups รายละเอียดการเชื่อมต่อ Wi-Fi และ IP |
| **Bluetooth** | เปิด Popups จัดการอุปกรณ์ Bluetooth |
| **Volume Slider** | เลื่อนลูกกลิ้งเมาส์บนไอคอนเพื่อเพิ่ม/ลดเสียง, คลิกซ้ายเพื่อ Mute หรือเปิด Sound Popups |
| **Battery** | คลิกดูสถานะแบตเตอรี่, เวลาคงเหลือ และ Power Mode |
| **Language** | คลิกซ้ายเพื่อเปิดเมนูภาษาและคีย์บอร์ดเลย์เอาต์ |
| **Traffic** | คลิกเพื่อสลับโหมดดู Speed ละเอียด (`↓` Download `↑` Upload) หรือแบบย่อ (`⇅`) |

### 9. 🗂️ File Explorer & Visual Ricing Tips
| คำสั่ง / ทริค | คำสั่ง / การทำงาน |
| --- | --- |
| `Ctrl + F1` ใน File Explorer | ย่อ/ขยายแถบ Ribbon ด้านบน เพื่อให้หน้าต่างแสดงผลเป็น **Acrylic Blur เต็มบาน** สวยงามโปร่งใสที่สุด |
| `Ctrl + Right-Click` บน Desktop | เข้าเมนูตั้งค่าและรีโหลดของ **Nilesoft Shell** (หากติดตั้งไว้) |

---

## 📦 Software & Components

| Software | รายละเอียด | คอนฟิกใน Repo |
| --- | --- | --- |
| **GlazeWM** | Tiling Window Manager สำหรับ Windows | `configs/glazewm/config.yaml` |
| **YASB** | Status Bar ด้านบนสไตล์ Polybar/Waybar | `configs/yasb/config.yaml`, `styles.css` |
| **Flow Launcher** | Spotlight-like App Launcher (`Ctrl+Space`) | `configs/flow-launcher/` |
| **Fastfetch** | System Fetch พร้อมรูป Frieren และไอคอน Windows (`ff`) | `configs/fastfetch/fastfetch.json`, `frieren.txt` |
| **Oh My Posh** | ตกแต่ง PowerShell Prompt สไตล์โมเดิร์น | `configs/oh-my-posh/jandedobbeleer.omp.json` |
| **CAVA** | Audio Visualizer คลื่นเสียงบน YASB | `configs/cava/config`, ธีมสี |
| **pipes-rs** | Terminal Animated Pipes Screensaver 60fps (`pipes`) | ติดตั้งผ่าน Scoop |
| **yazi** | Blazing Fast Modern Terminal File Manager (`y`) | ติดตั้งผ่าน Scoop |
| **eza** | Modern replacement for `ls` with icons & git (`ls`, `ll`, `la`) | ติดตั้งผ่าน Scoop |
| **bat** | Cat clone with syntax highlighting & git (`cat`) | ติดตั้งผ่าน Scoop |
| **lazygit** | Terminal UI for Git (`lg`) | ติดตั้งผ่าน Scoop |
| **zoxide** | Smarter `cd` command for instant folder jump (`z`) | ติดตั้งผ่าน Scoop |
| **Windows Terminal** | ธีมและฟอนต์โปร่งแสง Acrylic | `configs/terminal/settings.json` |
| **PowerShell 7** | `$PROFILE` คำสั่งลัด `ff`, `pipes` และโหลด OMP อัตโนมัติ | `configs/powershell/` |
| **HideTaskbar** | ซ่อน Windows Taskbar ดั้งเดิม | `configs/hidetaskbar/HideTaskbar.exe` |
| **GlazeTiler** | ออโต้ไทล์เสริมสำหรับ GlazeWM | `configs/glazetiler/glazetiler.exe` |
| **Btop** | TUI Hardware & Process Monitor ธีม Catppuccin Mocha (`btop`) | `configs/btop/btop.conf`, themes |
| **ExplorerBlurMica** | เอฟเฟกต์ Acrylic Blur + Catppuccin Tint บน Windows Explorer | `configs/explorer-blur-mica/` |
| **Nilesoft Shell** | ปรับแต่งเมนูคลิกขวา Acrylic ธีม Catppuccin Mocha | `configs/nilesoft-shell/shell.nss` |
| **Spicetify** | ปรับแต่ง UI ของ Spotify Desktop ธีม Catppuccin Mocha + Marketplace (ร้านเลือกลงของเสริม) + Adblock (`adblock.js`) | `configs/spicetify/` |
| **ModernFlyouts** | Modern Fluent OSD แถบเสียง/มีเดียแบบโปร่งแสง | ติดตั้งผ่าน WinGet |
| **Vencord** | Discord Client Mod พร้อมธีม Catppuccin Mocha | `configs/vencord/` |

---

## 🎨 Post-Installation Guide (การเปิดใช้งานโมดูลเสริม)

1. **ExplorerBlurMica (ทำให้ File Explorer โปร่งแสง):**
   - ไปที่ `~/.config/ExplorerBlurMica`
   - คลิกขวาที่ `register.cmd` แล้วเลือก **Run as administrator** เพื่อลงทะเบียน Shell Extension
   - กด `Ctrl + F1` ใน File Explorer เพื่อย่อแถบ Ribbon ด้านบน ให้กระจก Acrylic Blur แสดงผลเต็มบานแบบไม่ทึบแสง
   - หากต้องการยกเลิก ให้รัน `uninstall.cmd` แบบ Administrator

2. **Nilesoft Shell (แต่งเมนูคลิกขวา Catppuccin):**
   - ติดตั้งผ่าน Scoop: `scoop install extras/nilesoft-shell`
   - คอนฟิก `shell.nss` จะถูกวางไว้ที่ `%USERPROFILE%\scoop\persist\nilesoft-shell\shell.nss` อัตโนมัติ
   - ลงทะเบียนเมนูคลิกขวาด้วยคำสั่ง:
     ```powershell
     shell -register
     ```
   - รีสตาร์ต Explorer เพื่อเปิดใช้เมนูคลิกขวา Acrylic Catppuccin Mocha ทันที (หรือกด `Ctrl + คลิกขวา` เพื่อเปิดเมนูจัดการของ Nilesoft Shell)

3. **pipes-rs (อนิเมชันท่อพักหน้าจอ):**
   - ติดตั้งผ่าน Scoop: `scoop install pipes-rs`
   - พิมพ์ `pipes` หรือ `pipe` ใน PowerShell เพื่อรันอนิเมชันท่อหลากสี 60fps (กด `q` เพื่อออก)

4. **Spicetify + Marketplace & Adblock (แต่ง Spotify พร้อมหน้าเลือกลงของเสริม & บล็อกโฆษณา):**
   - มี **Marketplace** ("หน้าร้านเลือกลงของเสริม") ติดตั้งมาให้แล้วในแถบด้านซ้ายของ Spotify สามารถคลิกเพื่อเลือกติดตั้ง Themes, Extensions, และ Custom Apps เพิ่มเติมได้ง่ายๆ
   - มี **Adblock** (`adblock.js` / Adblockify) เปิดใช้งานมาให้อัตโนมัติ บล็อกทั้งเสียงโฆษณาและแบนเนอร์
   - เมื่อมี Spotify Desktop ติดตั้งอยู่แล้ว ให้รันคำสั่งใน PowerShell:
     ```powershell
     spicetify backup apply
     ```
   - หากต้องการอัปเดตคอนฟิกหรือรีสตาร์ต Spotify:
     ```powershell
     spicetify apply
     # หรือ
     spicetify restart
     ```

5. **Vencord (ธีม Catppuccin Discord):**
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
