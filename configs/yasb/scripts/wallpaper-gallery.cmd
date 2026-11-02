@echo off
if exist "%USERPROFILE%\.config\yasb\scripts\wallpaper-gallery.exe" (
    start "" /B "%USERPROFILE%\.config\yasb\scripts\wallpaper-gallery.exe" %*
) else if exist "%USERPROFILE%\.config\yasb\scripts\wallpaper-gallery.vbs" (
    wscript.exe //nologo "%USERPROFILE%\.config\yasb\scripts\wallpaper-gallery.vbs" %*
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%USERPROFILE%\.config\yasb\scripts\wallpaper-gallery.ps1" %*
)
