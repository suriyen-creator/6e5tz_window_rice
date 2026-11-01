@echo off
if exist "%USERPROFILE%\.config\yasb\scripts\next-wallpaper.exe" (
    start "" /B "%USERPROFILE%\.config\yasb\scripts\next-wallpaper.exe" %*
) else (
    wscript.exe //nologo "%USERPROFILE%\.config\yasb\scripts\next-wallpaper.vbs" %*
)
