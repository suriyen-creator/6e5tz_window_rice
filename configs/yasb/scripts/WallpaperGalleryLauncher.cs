using System;
using System.Diagnostics;
using System.IO;

class WallpaperGalleryLauncher {
    static void Main(string[] args) {
        string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        string script = Path.Combine(userProfile, @".config\yasb\scripts\wallpaper-gallery.ps1");
        
        if (!File.Exists(script)) {
            string[] docCandidates = new string[] {
                Path.Combine(userProfile, @"Documents\window_rice\configs\yasb\scripts\wallpaper-gallery.ps1"),
                Path.Combine(userProfile, @".dotfiles\window_rice\configs\yasb\scripts\wallpaper-gallery.ps1")
            };
            foreach (string c in docCandidates) {
                if (File.Exists(c)) {
                    script = c;
                    break;
                }
            }
        }

        string exe = "powershell.exe";
        string[] pwshCandidates = new string[] {
            Path.Combine(userProfile, @"scoop\apps\pwsh\current\pwsh.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"PowerShell\7\pwsh.exe")
        };
        foreach (string p in pwshCandidates) {
            if (File.Exists(p)) {
                exe = p;
                break;
            }
        }

        string argStr = "-Sta -NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"";
        if (args.Length > 0) {
            argStr += " " + string.Join(" ", args);
        }

        ProcessStartInfo psi = new ProcessStartInfo {
            FileName = exe,
            Arguments = argStr,
            CreateNoWindow = true,
            UseShellExecute = false,
            WindowStyle = ProcessWindowStyle.Hidden
        };
        Process.Start(psi);
    }
}
