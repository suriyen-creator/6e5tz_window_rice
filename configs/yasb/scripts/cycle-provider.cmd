@echo off
if exist "%USERPROFILE%\.config\yasb\scripts\cycle-provider.exe" (
    start "" /B "%USERPROFILE%\.config\yasb\scripts\cycle-provider.exe" %*
) else if exist "%USERPROFILE%\.config\yasb\scripts\cycle-provider.vbs" (
    wscript.exe //nologo "%USERPROFILE%\.config\yasb\scripts\cycle-provider.vbs" %*
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%USERPROFILE%\.config\yasb\scripts\cycle-provider.ps1" %*
)
