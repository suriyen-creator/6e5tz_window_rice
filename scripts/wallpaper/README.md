# 6e5tz Universal Wallpaper Manager — Architecture & Module Guide

The **6e5tz Universal Wallpaper Manager** is a modular, event-driven desktop background management subsystem engineered specifically for Windows environments running tiling window managers such as GlazeWM and floating top bars like YASB.

## Directory Structure

```
scripts/wallpaper/
├── common.ps1                 # Shared logging, Named Mutex locking, debouncing, atomic JSON IO
├── config.ps1                 # Configuration loading, validation, default fallbacks, and persistence
├── state.ps1                  # Runtime state tracking (active provider, collection, workspace history)
├── detection.ps1              # Automatic detection of Wallpaper Engine, Lively, and Static engines
│
├── collections/
│   └── folders.ps1            # User-controlled folder collections, filtering, caching, and discovery
│
├── providers/
│   ├── static.ps1             # Native Windows desktop wallpaper provider via Win32 API
│   ├── wallpaper-engine.ps1   # Official Steam Wallpaper Engine CLI controller & playlist manager
│   └── lively.ps1             # Rocksdanister Lively Wallpaper CLI controller (livelycu.exe)
│
├── workspace/
│   └── watcher.ps1            # GlazeWM IPC WebSocket event listener (workspace_activated daemon)
│
├── ui/
│   └── gallery.ps1            # Dark Catppuccin Mocha WPF/XAML wallpaper gallery interface
│
└── manager.ps1                # Unified CLI entry point & orchestrator with concurrency guard
```

## Core Features & Interfaces

### 1. Unified Manager Actions (`manager.ps1`)
- `-Action next`: Advances to the next wallpaper in the active collection. Protected with a named `Mutex` and 350ms high-resolution timer debounce to prevent double-skipping on rapid `Alt + W` keypresses.
- `-Action prev`: Moves to the previous wallpaper in the collection.
- `-Action shuffle`: Selects a random wallpaper from the collection without immediate repeats.
- `-Action provider -Provider <Static|WallpaperEngine|Lively>`: Smoothly switches wallpaper engines without conflicting background processes.
- `-Action cycle-provider`: Cycles to the next available engine on the system (`Alt + Ctrl + W`).
- `-Action collection -Collection <Name>`: Switches active collection.
- `-Action workspace -Workspace <Id>`: Applies the specific provider & collection mapped to a GlazeWM workspace.
- `-Action status`: Displays rich formatted terminal status.
- `-Action gallery`: Launches the Catppuccin Mocha WPF Gallery (`Alt + Shift + G`).

### 2. Folder-Based Collections (`collections/folders.ps1`)
- **No unwanted machine scanning**: Only indexes user-designated folders under `collectionRoot` (defaults to `$HOME\Pictures\Wallpapers`).
- **Subfolder = Collection**: Creating a folder like `Wallpapers\Anime` automatically creates an `Anime` collection.
- **Strict Format Filtering**:
  - Static: `.jpg`, `.jpeg`, `.png`, `.webp`
  - Lively: `.mp4`, `.webm`, `.zip`
  - Wallpaper Engine: Official Steam playlists from `config.json`
- **Metadata Caching**: Avoids redundant directory scans on every keypress.

### 3. Linux-Like Workspace Wallpapers (`workspace/watcher.ps1`)
- Connects directly to GlazeWM's local IPC WebSocket server at `ws://127.0.0.1:6123`.
- Subscribes to `sub -e workspace_activated`.
- Automatically maps virtual workspaces to specific collections and providers.
- Preserves the current wallpaper if a workspace has no explicit mapping.
- Automatically reconnects if GlazeWM is reloaded or restarted.
