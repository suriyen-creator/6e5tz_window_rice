Set oShell = CreateObject("Wscript.Shell")
strUser = oShell.ExpandEnvironmentStrings("%USERPROFILE%")
strScript = strUser & "\.config\yasb\scripts\next-wallpaper.ps1"
oShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strScript & """", 0, False
