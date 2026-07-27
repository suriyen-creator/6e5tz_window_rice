# Windows Desktop Dotfiles

Portable backup and restore files for the Windows 10 desktop setup detected on the source machine.

> This repository was created from a read-only inspection of the source machine. It does not contain browser profiles, private history, Steam Workshop downloads, logs, caches, or credentials.

## Preview

No screenshot was present in the source workspace at creation time. Add personal, owned screenshots under [`screenshots/`](screenshots/) and link them here when ready.

## Software detected

| Software | Detected state | Config discovered |
| --- | --- | --- |
| YASB | `yasb.exe` at `C:\Program Files\YASB\yasb.exe` | `%USERPROFILE%\.config\yasb` was inaccessible to this read-only session; backup script checks it again |
| GlazeWM | `3.10.1` | `%USERPROFILE%\.glzr\glazewm\config.yaml` |
| Flow Launcher | `2.1.2` | `%APPDATA%\FlowLauncher\Settings`, selected plugin settings, and Themes |
| HideTaskbar | no executable/config found in accessible locations | not backed up |
| Wallpaper Engine | installed under Steam | Workshop content intentionally excluded |
| CAVA | `0.10.7` at `%LOCALAPPDATA%\cava\cava.exe` | no standalone config; YASB-generated runtime CAVA file excluded |
| Windows Terminal | Store package layout detected | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| Oh My Posh | `oh-my-posh.exe` on PATH | no profile or custom theme found |
| Fastfetch | `2.64.2` via Scoop shim | no config found in accessible locations |
| GlazeTiler | `glazetiler.exe` at `%USERPROFILE%\.cargo\bin\glazetiler.exe` | only `%APPDATA%\GlazeTiler\glazetiler.log.*` was present; logs excluded |
| PowerShell | PowerShell 7.6.2 (`pwsh.exe`) available | current-user profile file was not present |

## Features

- `backup.ps1` copies only detected/shareable config, style, theme, and asset files.
- Dynamic paths use environment variables; no username is hardcoded.
- Flow Launcher settings are reduced to shareable settings, with proxy credentials removed and machine-specific explorer entries omitted.
- Path values are stored using portable placeholders and expanded during restore.
- `install.ps1` can install packages through WinGet, back up existing targets, restore files, and optionally create junctions.
- If a link cannot be created because Developer Mode/admin permission is unavailable, restore falls back to copy.
- Re-running restore never silently overwrites an existing target: it creates a timestamped `.backup-YYYYMMDD-HHMMSS` first.

## Repository structure

```text
.
├── README.md
├── install.ps1
├── backup.ps1
├── packages.json
├── .gitignore
├── configs/
│   ├── yasb/
│   ├── glazewm/
│   ├── flow-launcher/
│   ├── terminal/
│   ├── powershell/
│   ├── oh-my-posh/
│   ├── fastfetch/
│   ├── cava/
│   ├── hidetaskbar/
│   └── glazetiler/
├── scripts/
├── assets/
├── wallpapers/
└── screenshots/
```

## Prerequisites

- Windows 10 with PowerShell 5.1 or PowerShell 7.
- Git, if cloning this repository.
- WinGet/App Installer for automatic package installation. The installer can still restore configs with `-SkipPackages` when WinGet is unavailable.
- Developer Mode or suitable permission is optional; it is only needed for link mode.
- Close applications before restoring their settings when possible, especially Flow Launcher and Windows Terminal.

## Installation and restore

Run from the repository root:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

For optional directory junctions where supported:

```powershell
.\install.ps1 -UseLinks
```

To restore config without package installation:

```powershell
.\install.ps1 -SkipPackages
```

The script creates a timestamped backup beside every existing target before restoring it. A failed link operation falls back to a normal copy.

## Backup usage

After closing apps whose files you want to capture:

```powershell
.\backup.ps1
```

The backup is safe to repeat. It skips missing locations, caches, logs, histories, runtime state, and files with a non-empty credential-like assignment. For a skipped sensitive file it may create a value-free `.example` for local review.

## GlazeWM shortcuts found in the current config

The following were read from `configs/glazewm/config.yaml` on the source machine:

- Focus: `Alt+H/J/K/L` or arrow-key equivalents.
- Move: `Alt+Shift+H/J/K/L` or arrow-key equivalents.
- Focus workspaces `1`–`9`: `Alt+1` through `Alt+9`.
- Move and focus workspaces `1`–`9`: `Alt+Shift+1` through `Alt+Shift+9`.
- Previous/next/recent workspace: `Alt+A`, `Alt+S`, `Alt+D`.
- Resize mode: `Alt+R`; resize mode uses `H/J/K/L` or arrow keys and exits with `Escape` or `Enter`.
- Other detected bindings include `Alt+Space`, `Alt+T`, `Alt+F`, `Alt+M`, `Alt+V`, `Alt+Shift+P`, and `Alt+Shift+Q/E/R/W`.

The config starts YASB and stops YASB/GlazeTiler during GlazeWM lifecycle events. It defines workspaces `1` through `9` and uses 10px inner gaps with 6px outer gaps. The source config also contains Windows 11-only visual-effect options; Windows 10 may ignore those options.

## YASB modules

The YASB config directory could not be read by the source inspection session (`Access denied`), so no module list is claimed here. Run `backup.ps1` in a normal user PowerShell session and review the resulting YASB files before commit.

## Flow Launcher details

The detected settings use `Ctrl + Space` as the launcher hotkey and the `Win11Light` theme. The settings reference the built-in Browser Bookmarks, Calculator, Explorer, Plugin Indicator, Plugins Manager, Process Killer, Program, Shell, System Commands, URL, Web Searches, and Windows Settings plugins. Only their shareable `Settings.json` files were selected; cache, logs, history, and plugin runtime data were not.

## Terminal stack

The detected Windows Terminal settings use PowerShell Core (`pwsh.exe`) as the default profile, `MesloLGL Nerd Font`, and acrylic/opacity settings on the PowerShell profile. No PowerShell profile file was found, so Oh My Posh and Fastfetch auto-run behavior was not invented or added.

## Wallpaper Engine

No Workshop wallpaper files are copied. Record owned or desired wallpapers in [`wallpapers/README.md`](wallpapers/README.md) using their name, Workshop ID/link, and installation notes. Only wallpapers that you own and have permission to redistribute should be placed under `wallpapers/local/` or `assets/`.

## WinGet packages

`packages.json` contains only packages connected to this setup: Windows Terminal, PowerShell, Flow Launcher, Oh My Posh, Fastfetch, GlazeWM, YASB, CAVA, and Steam as the Wallpaper Engine host. GlazeTiler, HideTaskbar, and Wallpaper Engine itself are documented as manual items because no verified package was used for them here.

Manual items:

- GlazeTiler: install from its official release/source. The source executable was `%USERPROFILE%\.cargo\bin\glazetiler.exe`; no package-manager installation method was asserted.
- HideTaskbar: install from the source you trust and review its local settings before adding them. No installed executable/config was discoverable in this session.
- Wallpaper Engine: install through Steam, then reinstall Workshop items from their links/IDs in [`wallpapers/README.md`](wallpapers/README.md). Workshop files are not redistributed here.

On the source session, `Get-Command winget` found the WindowsApps alias, but launching it failed with an OS process-access error. The package list was therefore not claimed as a successful live `winget list`; run `winget list` on the normal Windows desktop to verify installed versions.

Useful official installation references: [Windows Terminal](https://github.com/microsoft/terminal), [Flow Launcher](https://github.com/Flow-Launcher/Flow.Launcher), [Oh My Posh](https://ohmyposh.dev/), [Fastfetch](https://github.com/fastfetch-cli/fastfetch), [GlazeWM](https://github.com/glzr-io/glazewm), [YASB](https://github.com/amnweb/yasb), and [CAVA](https://github.com/karlstav/cava).

## Troubleshooting

- `winget` is missing or cannot start: install/update Microsoft App Installer, or run `.\install.ps1 -SkipPackages` and install packages manually.
- YASB is skipped: confirm `%USERPROFILE%\.config\yasb` is readable, then rerun `backup.ps1`. Do not disable permissions broadly just for this repository.
- A config is not restored: check whether its source file exists under `configs/` and whether the target application was closed.
- A link is not created: use normal copy mode, or enable Developer Mode/run the link operation with the permission appropriate for that machine.
- Windows Terminal settings appear unchanged: close all Terminal windows and run restore again.

## Security and privacy

Before committing, inspect the complete diff and run a scan for credential-like assignments, private paths, absolute `C:\Users\...` values, and runtime data. This repository deliberately excludes `.env`, local/secret files, histories, caches, logs, generated backups, browser data, and Steam Workshop content. If a file is ambiguous, keep it out of Git and add a safe example instead.

No GitHub remote is configured by this setup, and the scripts do not push anything.
