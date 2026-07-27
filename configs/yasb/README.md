# YASB

The source inspection found YASB installed, but `%USERPROFILE%\.config\yasb` returned `Access denied` in the read-only session. `backup.ps1` checks this path again in a normal PowerShell session. No runtime files from `%LOCALAPPDATA%\YASB` are included.
