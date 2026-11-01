# 🌸 6e5tz Windows Desktop Dotfiles (Rice)

[![Windows 10 / 11](https://img.shields.io/badge/Windows-10%20%7C%2011-blue?logo=windows)](https://github.com/suriyen-creator/6e5tz_window_rice)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

A clean, aesthetic pastel-themed Windows tiling desktop setup featuring **GlazeWM**, **YASB**, **Flow Launcher**, **Oh My Posh**, **CAVA**, **Fastfetch** (with Frieren ASCII art), **Btop**, **ExplorerBlurMica**, **Spicetify**, **ModernFlyouts**, and **Vencord**.

*(ชุดตกแต่งเดสก์ท็อป Windows สไตล์มินิมอลโมเดิร์น ธีมสีพาสเทล Catppuccin พร้อมระบบ Tiling Window Management)*

---

## ⚡ Quick Install / ติดตั้งด่วนใน 1 คำสั่ง

Open **PowerShell** (Run as Administrator recommended), paste the command below, and press `Enter`:

*(เปิด **PowerShell** ในฐานะ Administrator แล้วคัดลอกคำสั่งด้านล่างนี้ไปวางแล้วกด `Enter`:)*

```powershell
irm https://raw.githubusercontent.com/suriyen-creator/6e5tz_window_rice/main/install.ps1 | iex
```

### What the installer handles automatically / สิ่งที่ตัวติดตั้งทำให้โดยอัตโนมัติ:
1. **Repository Setup:** Clones dotfiles directly to `$HOME\.dotfiles\window_rice`.
2. **Interactive Menu / เมนูติดตั้ง:**
   - `[1] Full Installation`: Installs all required packages via WinGet + MesloLGL Nerd Font + deploys all configurations.
   - `[2] Deploy Configs Only`: Deploys configuration files only (for existing setups).
   - `[3] Install Font Only`: Downloads and registers MesloLGL Nerd Font only.
3. **Automatic Backup:** Existing configurations are automatically preserved with `.backup-<timestamp>` timestamps.
4. **Auto-Start:** Automatically launches GlazeWM and YASB once installation completes.

---

## 🛠 Manual Installation / ติดตั้งแบบโคลนเอง

If you prefer to inspect the source files before deploying:

*(หากต้องการโคลนและตรวจดูโค้ดก่อนติดตั้ง:)*

```powershell
# 1. Clone the repository / โคลนโปรเจกต์
git clone https://github.com/suriyen-creator/6e5tz_window_rice.git
cd 6e5tz_window_rice

# 2. Run the installer / รันตัวติดตั้ง
.\install.ps1
```

### Optional Installer Flags / ออปชันคำสั่งเพิ่มเติม:
```powershell
# Deploy configs only (skips WinGet package downloads)
.\install.ps1 -ConfigOnly

# Non-interactive / unattended installation
.\install.ps1 -Full -NonInteractive

# Force specific Wallpaper mode (Static or WallpaperEngine)
.\install.ps1 -WallpaperMode Static
.\install.ps1 -WallpaperMode WallpaperEngine
```

---

## 🖼️ Wallpaper System / ระบบจัดการภาพพื้นหลัง (Dual-Mode)

The rice supports both **Wallpaper Engine** (Steam) users and **Static Wallpaper** users with seamless switching:

*(ระบบรองรับทั้งคนที่มี Wallpaper Engine บน Steam และคนที่ชอบใช้ภาพนิ่งปกติของ Windows)*

### 1. Wallpaper Engine Mode (Auto-detected if installed)
- **YASB Bar Controls (󰸉 Icon):**
  - **Left Click:** Advance to next wallpaper in active playlist (`nextWallpaper`).
  - **Right Click:** Toggle pause / resume playback (`Pause / Resume`) to save system resources.
  - **Middle Click:** Open Wallpaper Engine main interface.
- Template file: [configs/yasb/config.wallpaper-engine.yaml](file:///C:/Users/suriy/Documents/window_rice/configs/yasb/config.wallpaper-engine.yaml)

### 2. Static Wallpapers Mode (For native Windows desktop)
- **YASB Bar Controls (󰸉 Icon):**
  - **Left Click:** Opens an interactive **Popup Gallery** with thumbnails, pagination, and instant 1-click wallpaper selection.
  - Automatically loads images from `~/Pictures/Wallpapers/`.
  - Comes bundled with 10 high-resolution anime wallpapers in `wallpapers/`.
- Template file: [configs/yasb/config.static.yaml](file:///C:/Users/suriy/Documents/window_rice/configs/yasb/config.static.yaml)

### 🔄 Switch Wallpaper Modes Anytime / วิธีสลับโหมดได้ทุกเมื่อ:
```powershell
# Open interactive mode switcher / เปิดเมนูเลือกโหมด
.\scripts\switch-wallpaper-mode.ps1

# Direct switch / สลับโหมดโดยตรง
.\scripts\switch-wallpaper-mode.ps1 -Mode Static
.\scripts\switch-wallpaper-mode.ps1 -Mode WallpaperEngine
```

---

## ⌨️ Keyboard Shortcuts & Controls / สารบัญคีย์ลัด

> [!NOTE]
> All GlazeWM hotkeys use the **`Alt`** modifier key. This ensures **zero interference** with native Windows key combinations, specifically **`Win + Space`** for language switching (Thai / English) and the Windows key for the Start Menu and Flow Launcher.
>
> *(คีย์ลัด GlazeWM ทั้งหมดใช้ปุ่ม `Alt` เป็นหลัก เพื่อไม่ให้แย่งปุ่ม `Win + Space` สลับภาษาไทย-อังกฤษ และปุ่ม Windows ของระบบ)*

### 1. 🪟 GlazeWM - Focus & Navigation / การเลื่อนโฟกัสหน้าต่าง
| Hotkey | Action (English) | คำสั่ง / การทำงาน (ไทย) |
| --- | --- | --- |
| `Alt + H` / `Left` | Focus left window | เลื่อนโฟกัสไปหน้าต่างซ้าย |
| `Alt + L` / `Right` | Focus right window | เลื่อนโฟกัสไปหน้าต่างขวา |
| `Alt + K` / `Up` | Focus window above | เลื่อนโฟกัสไปหน้าต่างบน |
| `Alt + J` / `Down` | Focus window below | เลื่อนโฟกัสไปหน้าต่างล่าง |
| `Alt + Space` | Cycle focus (Tiling -> Floating -> Fullscreen) | สลับโฟกัสวนข้ามสถานะหน้าต่าง |
| `Alt + S` | Focus next active workspace | โฟกัสไปยัง Workspace ถัดไปที่มีหน้าต่างเปิดอยู่ |
| `Alt + A` | Focus previous active workspace | โฟกัสไปยัง Workspace ก่อนหน้าที่มีหน้าต่างเปิดอยู่ |
| `Alt + D` | Switch to recent workspace | สลับกลับไปยัง Workspace ล่าสุดที่เพิ่งใช้งาน |

### 2. 🧩 GlazeWM - Window Layout & Placement / การจัดการเลย์เอาต์หน้าต่าง
| Hotkey | Action (English) | คำสั่ง / การทำงาน (ไทย) |
| --- | --- | --- |
| `Alt + Shift + H` / `Left` | Move window left | ย้ายหน้าต่างไปทางซ้าย |
| `Alt + Shift + L` / `Right` | Move window right | ย้ายหน้าต่างไปทางขวา |
| `Alt + Shift + K` / `Up` | Move window up | ย้ายหน้าต่างขึ้นบน |
| `Alt + Shift + J` / `Down` | Move window down | ย้ายหน้าต่างลงล่าง |
| `Alt + Shift + Space` | Toggle floating (centered) | ปลดหน้าต่างเป็นโหมดลอยอิสระ (Floating) |
| `Alt + T` | Return window to tiling | เปลี่ยนหน้าต่างกลับเป็นโหมดเรียงชิด (Tiling) |
| `Alt + F` | Toggle fullscreen | เปิด / ปิดโหมดขยายเต็มหน้าจอ |
| `Alt + M` | Minimize window | ย่อหน้าต่างลง Taskbar |
| `Alt + Shift + Q` | **Close focused window** | **ปิดหน้าต่างที่กำลังโฟกัส** |
| `Alt + V` | Toggle tiling direction (H / V split) | สลับทิศทางการแยกหน้าต่าง (แนวนอน / แนวตั้ง) |

### 3. 📐 GlazeWM - Window Resizing / การปรับขนาดหน้าต่าง
| Hotkey | Action (English) | คำสั่ง / การทำงาน (ไทย) |
| --- | --- | --- |
| `Alt + U` / `Alt + P` | Decrease / Increase window width (-2% / +2%) | ลด / เพิ่มความกว้างของหน้าต่าง |
| `Alt + I` / `Alt + O` | Decrease / Increase window height (-2% / +2%) | ลด / เพิ่มความสูงของหน้าต่าง |
| `Alt + R` | **Enter Resize Mode** (Use `H/J/K/L` or arrows `← ↑ ↓ →`, press `Enter` or `Esc` to exit) | **เข้าสู่โหมดปรับขนาดอิสระ** (กดลูกศรเพื่อปรับ, กด Enter เพื่อเสร็จสิ้น) |

### 4. 🚀 GlazeWM - Workspaces & Monitors / การสลับพื้นที่ทำงานและหน้าจอ
| Hotkey | Action (English) | คำสั่ง / การทำงาน (ไทย) |
| --- | --- | --- |
| `Alt + 1` .. `Alt + 9` | Switch to Workspace 1 through 9 | สลับไปยัง Workspace หมายเลข 1 ถึง 9 |
| `Alt + Shift + 1` .. `9` | Move window to Workspace and follow focus | ย้ายหน้าต่างไปยัง Workspace นั้นๆ พร้อมตามไปทันที |
| `Alt + Shift + A` | Move workspace to left monitor | ย้าย Workspace ปัจจุบันไปยังจอด้านซ้าย |
| `Alt + Shift + F` | Move workspace to right monitor | ย้าย Workspace ปัจจุบันไปยังจอด้านขวา |
| `Alt + Shift + D` | Move workspace to upper monitor | ย้าย Workspace ปัจจุบันไปยังจอด้านบน |
| `Alt + Shift + S` | Move workspace to lower monitor | ย้าย Workspace ปัจจุบันไปยังจอด้านล่าง |

### 5. ⚙️ GlazeWM - Process & System Controls / การควบคุมระบบ GlazeWM
| Hotkey | Action (English) | คำสั่ง / การทำงาน (ไทย) |
| --- | --- | --- |
| `Alt + Enter` | **Launch Windows Terminal** | **เปิดหน้าต่าง Windows Terminal ทันที** |
| `Alt + Shift + R` | Reload GlazeWM configuration | โหลดคอนฟิก GlazeWM ใหม่ทันทีโดยไม่ต้องรีสตาร์ต |
| `Alt + Shift + W` | Redraw all windows | วาดหน้าต่างใหม่ แก้ปัญหากระพริบหรือภาพค้าง |
| `Alt + Shift + P` | Toggle pause window management | หยุด/คืนค่าการจัดหน้าต่างอัตโนมัติชั่วคราว |
| `Alt + Shift + E` | Exit GlazeWM process | ออกจากโปรแกรม GlazeWM อย่างปลอดภัย |

### 6. 🔍 Flow Launcher - App Search & Productivity / ค้นหาและเปิดแอปด่วน
| Hotkey | Action (English) | คำสั่ง / การทำงาน (ไทย) |
| --- | --- | --- |
| `Ctrl + Space` | **Toggle Flow Launcher search bar** | **เปิดแถบค้นหา Flow Launcher** |
| `F1` | Quick preview file / item | เปิดหน้าต่างดูตัวอย่างไฟล์ |
| `Ctrl + O` | Open context menu for selected result | เปิดเมนู Context ของรายการที่เลือก |
| `Ctrl + I` | Open Flow Launcher settings | เปิดหน้าต่างการตั้งค่า Flow Launcher |
| `Ctrl + H` | View query history | ดูประวัติการค้นหาย้อนหลัง |
| `Tab` / `Ctrl + Tab` | Select next result / Auto-complete | เลือกผลลัพธ์ถัดไป / เติมคำค้นหาอัตโนมัติ |
| `Alt + Up` / `Down` | Browse input history | เลื่อนดูคำค้นหาที่เคยพิมพ์ |

### 7. 💻 The Terminal & TUI Arsenal / ชุดคำสั่งเทอร์มินัลระดับโปร
| Command | Alias | Description (English) | คำอธิบาย (ไทย) |
| --- | --- | --- | --- |
| `yazi` | `y` | Fast modern terminal file manager | จัดการไฟล์ผ่านเทอร์มินัลความเร็วสูง |
| `eza` | `ls`, `ll`, `la`, `lt` | Modern `ls` with Nerd Font icons & Git status | แสดงรายการไฟล์พร้อมไอคอนและสถานะ Git |
| `bat` | `cat` | Cat clone with syntax highlighting & Git diffs | แสดงโค้ดพร้อมไฮไลต์ไวยากรณ์และเลขบรรทัด |
| `lazygit` | `lg` | Terminal UI for Git operations | TUI จัดการ Git แบบมืออาชีพ |
| `zoxide` | `z <dir>` | Smart directory jumper | กระโดดไปยังโฟลเดอร์ที่เคยเปิดอย่างรวดเร็ว |
| `fzf` | `fzf` | Interactive command-line fuzzy finder | ค้นหาไฟล์ฉับไวแบบ Fuzzy Search |
| `fastfetch` | `ff` | System fetch with Frieren ASCII art | แสดงสเปกเครื่องพร้อมรูปน้องฟรีเรน |
| `btop` | `btop` | Resource monitor (Catppuccin Mocha theme) | ดูการทำงานของ CPU, GPU, RAM, Network |
| `pipes-rs` | `pipes`, `pipe` | 60fps retro screensaver pipes animation (`q` to quit) | อนิเมชันท่อพักหน้าจอแบบเรโทร 60fps |

### 8. 📊 YASB Top Bar Interactions / การคลิกควบคุมบนแถบ YASB
| Widget | Click Actions (English) | การทำงาน (ไทย) |
| --- | --- | --- |
| **GlazeWM Workspaces (1-9)** | Click to navigate directly to workspace | คลิกเพื่อสลับหน้าต่างไปยัง Workspace นั้นๆ |
| **Media Player** | Play / Pause media, click track name to focus player | เล่น/หยุดเพลง, คลิกชื่อเพลงเพื่อเปิดโปรแกรมเล่นเพลง |
| **Clock / Date** | Open calendar and time panel | เปิดแผงปฏิทินและเวลา |
| **Wallpaper Controller (󰸉)** | **Wallpaper Engine:** Left click next, Right click pause/play, Middle click open UI<br>**Static Mode:** Left click opens thumbnail gallery | **โหมด Wallpaper Engine:** คลิกซ้ายเปลี่ยนภาพ, คลิกขวาหยุด/เล่นต่อ, คลิกกลางเปิด UI<br>**โหมด Static:** คลิกซ้ายเปิด Gallery Popup |
| **Network / Wi-Fi** | Open connection details and IP menu | เปิดป๊อปอัปดูรายละเอียดการเชื่อมต่อและ IP |
| **Bluetooth** | Open Bluetooth devices menu | เปิดเมนูจัดการอุปกรณ์ Bluetooth |
| **Volume Slider** | Scroll to adjust volume, Left click to mute / open sound menu | เลื่อนลูกกลิ้งเมาส์เพื่อปรับเสียง, คลิกซ้ายเพื่อ Mute |
| **Battery** | View percentage, remaining time, and power mode | ดูสถานะแบตเตอรี่, เวลาคงเหลือ และโหมดพลังงาน |
| **Language** | Left click to toggle input menu | คลิกซ้ายเพื่อดูเมนูภาษา |
| **Traffic** | Left click toggles detailed rate (`↓`/`↑`) or compact (`⇅`) | คลิกเพื่อสลับดูเน็ตแบบละเอียดหรือแบบย่อ |

### 9. 🗂️ File Explorer & Visual Ricing Tips / เคล็ดลับการตกแต่ง
| Action / Shortcut | Description (English) | รายละเอียด (ไทย) |
| --- | --- | --- |
| `Ctrl + F1` in File Explorer | Collapse / expand the top Ribbon bar to reveal full **edge-to-edge Acrylic blur** | ย่อแถบ Ribbon ด้านบนเพื่อให้กระจก Acrylic Blur แสดงผลเต็มบานแบบไม่ทึบแสง |
| `Ctrl + Right-Click` on Desktop | Open **Nilesoft Shell** settings and reload menu | เข้าเมนูตั้งค่าและรีโหลดของ Nilesoft Shell |

---

## 📦 Software & Components / รายการโปรแกรมที่ใช้งาน

| Software | Description (English) | คำอธิบาย (ไทย) | Config Path |
| --- | --- | --- | --- |
| **GlazeWM** | Tiling window manager for Windows | ตัวจัดเรียงหน้าต่างอัตโนมัติ | `configs/glazewm/config.yaml` |
| **YASB** | Configurable top status bar (Waybar/Polybar style) | แถบสถานะด้านบนสไตล์ Waybar | `configs/yasb/` |
| **Flow Launcher** | Quick app and file launcher (`Ctrl+Space`) | เมนูค้นหาโปรแกรมและไฟล์แบบรวดเร็ว | `configs/flow-launcher/` |
| **Fastfetch** | System information fetch with Frieren ASCII | แสดงสเปกเครื่องพร้อมรูปภาพ Frieren | `configs/fastfetch/` |
| **Oh My Posh** | Modern shell prompt engine | ธีมตกแต่ง Command Prompt และ PowerShell | `configs/oh-my-posh/` |
| **CAVA** | Audio spectrum visualizer integrated into YASB | แถบคลื่นเสียงอนิเมชันตามจังหวะเพลง | `configs/cava/` |
| **pipes-rs** | 60fps Rust-native terminal pipes animation | อนิเมชันท่อพักหน้าจอแบบเรโทร 60fps | Scoop Package |
| **yazi** | Blazing-fast terminal file manager | โปรแกรมจัดการไฟล์ใน Terminal | Scoop Package |
| **eza** | Modern `ls` with Nerd Font glyphs | คำสั่งลิสต์ไฟล์พร้อมไอคอน | Scoop Package |
| **bat** | Cat clone with syntax highlighting | โปรแกรมเปิดดูไฟล์โค้ดพร้อมไฮไลต์ | Scoop Package |
| **lazygit** | Fast terminal UI for Git | หน้าต่างจัดการ Git บน Terminal | Scoop Package |
| **zoxide** | Intelligent directory navigation (`cd`) | คำสั่งกระโดดไปยังโฟลเดอร์อัตโนมัติ | Scoop Package |
| **Windows Terminal** | Translucent Acrylic themed terminal | เทอร์มินัลโปร่งใสพร้อมฟอนต์และสี Catppuccin | `configs/terminal/settings.json` |
| **PowerShell 7** | Modern PowerShell profile with aliases | คอนฟิก `$PROFILE` พร้อมคีย์ลัดด่วน | `configs/powershell/` |
| **HideTaskbar** | Utility to auto-hide native Windows taskbar | โปรแกรมซ่อน Taskbar เดิมของ Windows | `configs/hidetaskbar/` |
| **GlazeTiler** | Auto-tiling assistant for GlazeWM | ตัวช่วยไทล์เสริมสำหรับ GlazeWM | `configs/glazetiler/` |
| **Btop** | Hardware resource monitor (Catppuccin Mocha) | มอนิเตอร์สเปกเครื่อง CPU/RAM/GPU | `configs/btop/` |
| **ExplorerBlurMica** | Acrylic blur & Catppuccin tint for File Explorer | เอฟเฟกต์เบลอกระจก Acrylic สำหรับ File Explorer | `configs/explorer-blur-mica/` |
| **Nilesoft Shell** | Modern Acrylic context menu with Catppuccin theme | ปรับแต่งเมนูคลิกขวาเป็นกระจก Acrylic | `configs/nilesoft-shell/shell.nss` |
| **Spicetify** | Spotify desktop mod with Marketplace & Adblock | แต่ง Spotify ธีม Catppuccin + Marketplace + บล็อกโฆษณา | `configs/spicetify/` |
| **ModernFlyouts** | Fluent translucent on-screen display (OSD) | แถบแสดงระดับเสียงและมีเดียแบบโปร่งแสง | WinGet Package |
| **Vencord** | Discord client mod with Catppuccin Mocha theme | ตัวแต่ง Discord พร้อมธีม Catppuccin | `configs/vencord/` |

---

## 🎨 Post-Installation Guide / คู่มือหลังการติดตั้ง

### 1. ExplorerBlurMica (Transparent Acrylic File Explorer)
- Navigate to `~/.config/ExplorerBlurMica`.
- Right-click `register.cmd` and select **Run as administrator** to register the shell extension.
- Press `Ctrl + F1` inside File Explorer to collapse the ribbon and experience full edge-to-edge Acrylic blur.
- *(หากต้องการยกเลิก ให้รัน `uninstall.cmd` ในฐานะ Administrator)*

### 2. Nilesoft Shell (Catppuccin Context Menu)
- Installed via Scoop: `scoop install extras/nilesoft-shell`.
- Register the context menu extension:
  ```powershell
  shell -register
  ```
- Restart Windows Explorer (`Stop-Process -Name explorer`) to enjoy the themed context menu.
- Access Nilesoft Shell preferences anytime by pressing `Ctrl + Right-Click` on the desktop.

### 3. Spicetify + Marketplace & Adblock
- Pre-configured with the **Marketplace** (extension store on Spotify's left sidebar) and **Adblock** (`adblock.js` / Adblockify).
- Once Spotify Desktop is installed, run:
  ```powershell
  spicetify backup apply
  ```
- To update configs or restart Spotify:
  ```powershell
  spicetify apply
  # or
  spicetify restart
  ```

### 4. Vencord (Catppuccin Discord Theme)
- The installer automatically patches Discord and places the theme at `%APPDATA%\Vencord\themes\catppuccin-mocha.theme.css`.
- Open Discord and verify theme activation under `Settings > Vencord > Themes`.

---

## 💾 How to Backup Your Changes / วิธีสำรองข้อมูลกลับเข้า Repo

If you customize layouts, colors, or keybindings and wish to commit them back to your repository:

*(หากคุณปรับแต่งตำแหน่งหรือสีเพิ่มเติม และต้องการบันทึกกลับเข้าโฟลเดอร์โปรเจกต์:)*

```powershell
.\backup.ps1
```

The script automatically converts local paths to portable tokens (`__USERPROFILE__`, `__APPDATA__`, etc.) and strips sensitive API tokens and credentials, keeping commits clean and secure.

---

## 💖 Credits & Acknowledgments

- **Base YASB + GlazeWM Configuration:** Based on [SleepyCatHey/Yasb-GlazeWM-Config](https://github.com/SleepyCatHey/Yasb-GlazeWM-Config) by [@SleepyCatHey](https://github.com/SleepyCatHey).
- **Catppuccin Theme Community:** [catppuccin/catppuccin](https://github.com/catppuccin) for the soothing pastel palette across Btop, Spicetify, Vencord, and ExplorerBlurMica.
- **Fastfetch Frieren ASCII Art:** Anime braille art community.
- **Upstream Projects:** [GlazeWM](https://github.com/glzr-io/glazewm), [YASB](https://github.com/amnweb/yasb), [Flow Launcher](https://github.com/Flow-Launcher/Flow.Launcher), [Oh My Posh](https://ohmyposh.dev/), [Fastfetch](https://github.com/fastfetch-cli/fastfetch), [CAVA](https://github.com/karlstav/cava), [btop4win](https://github.com/aristocratos/btop4win), [ExplorerBlurMica](https://github.com/Maplespe/ExplorerBlurMica), [Spicetify](https://github.com/spicetify/cli), [ModernFlyouts](https://github.com/ModernFlyouts-Community/ModernFlyouts), [Vencord](https://github.com/Vendicated/Vencord).
