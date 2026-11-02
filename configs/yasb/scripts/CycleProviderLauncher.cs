using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Web.Script.Serialization;

class CycleProviderLauncher {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    public const int SPI_SETDESKWALLPAPER = 0x0014;
    public const int SPIF_UPDATEINIFILE = 0x01;
    public const int SPIF_SENDCHANGE = 0x02;

    static void Main(string[] args) {
        string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        string configDir = Path.Combine(userProfile, @".config\6e5tz");
        string configFile = Path.Combine(configDir, "wallpaper-manager.json");
        string stateFile = Path.Combine(configDir, "wallpaper-state.json");
        string logFile = Path.Combine(configDir, "wallpaper.log");

        try {
            // 1. Identify installed / available providers
            List<string> availableProviders = new List<string>();
            availableProviders.Add("Static");

            string weExe = FindWallpaperEngineExe();
            if (!string.IsNullOrEmpty(weExe) && File.Exists(weExe)) {
                availableProviders.Add("WallpaperEngine");
            }

            string livelyExe = FindLivelyExe();
            if (!string.IsNullOrEmpty(livelyExe) && File.Exists(livelyExe)) {
                availableProviders.Add("Lively");
            }

            // 2. Read current active provider from state or config
            string currentProvider = "Static";
            JavaScriptSerializer js = new JavaScriptSerializer();
            Dictionary<string, object> state = null;
            if (File.Exists(stateFile)) {
                try {
                    string stateJson = File.ReadAllText(stateFile);
                    state = js.Deserialize<Dictionary<string, object>>(stateJson);
                    if (state != null && state.ContainsKey("activeProvider") && state["activeProvider"] != null) {
                        currentProvider = state["activeProvider"].ToString();
                    }
                } catch {}
            }
            if (state == null) state = new Dictionary<string, object>();

            // 3. Determine next available provider in cycle
            string[] cycleOrder = new string[] { "Static", "WallpaperEngine", "Lively" };
            int curIdx = -1;
            for (int i = 0; i < cycleOrder.Length; i++) {
                if (cycleOrder[i].Equals(currentProvider, StringComparison.OrdinalIgnoreCase)) {
                    curIdx = i;
                    break;
                }
            }
            if (curIdx < 0) curIdx = 0;

            string nextProvider = "Static";
            for (int i = 1; i <= cycleOrder.Length; i++) {
                int nextIdx = (curIdx + i) % cycleOrder.Length;
                string candidate = cycleOrder[nextIdx];
                if (availableProviders.Contains(candidate)) {
                    nextProvider = candidate;
                    break;
                }
            }

            // 4. Execute provider transition directly
            if (nextProvider.Equals("Static", StringComparison.OrdinalIgnoreCase)) {
                // Stop WE / Lively
                if (!string.IsNullOrEmpty(weExe) && File.Exists(weExe)) {
                    RunSilent(weExe, "-control stop");
                }
                if (!string.IsNullOrEmpty(livelyExe) && File.Exists(livelyExe)) {
                    RunSilent(livelyExe, "app --pause");
                }

                // Apply Static wallpaper (Never allow non-image files like project.json to turn desktop black!)
                string wpToApply = null;
                if (state.ContainsKey("staticWallpaper") && state["staticWallpaper"] != null) {
                    string cand = state["staticWallpaper"].ToString();
                    if (File.Exists(cand) && IsValidImage(cand)) {
                        wpToApply = cand;
                    }
                }
                if (string.IsNullOrEmpty(wpToApply) && state.ContainsKey("currentWallpaper") && state["currentWallpaper"] != null) {
                    string cand = state["currentWallpaper"].ToString();
                    if (File.Exists(cand) && IsValidImage(cand)) {
                        wpToApply = cand;
                    }
                }
                if (string.IsNullOrEmpty(wpToApply)) {
                    wpToApply = FindFallbackStaticWallpaper(userProfile);
                }

                if (!string.IsNullOrEmpty(wpToApply) && File.Exists(wpToApply)) {
                    SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, wpToApply, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
                    state["staticWallpaper"] = wpToApply;
                    state["currentWallpaper"] = wpToApply;
                }
                if (!string.IsNullOrEmpty(weExe) && File.Exists(weExe)) {
                    RunSilent(weExe, "-control stop");
                }
            } else if (nextProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
                if (!string.IsNullOrEmpty(weExe) && File.Exists(weExe)) {
                    RunSilent(weExe, "-control play");
                    if (state.ContainsKey("wallpaperEngineWallpaper") && state["wallpaperEngineWallpaper"] != null) {
                        string weWp = state["wallpaperEngineWallpaper"].ToString();
                        if (File.Exists(weWp)) {
                            state["currentWallpaper"] = weWp;
                        }
                    }
                }
            } else if (nextProvider.Equals("Lively", StringComparison.OrdinalIgnoreCase)) {
                if (!string.IsNullOrEmpty(livelyExe) && File.Exists(livelyExe)) {
                    RunSilent(livelyExe, "app --play");
                }
            }

            // 5. Update state and config
            state["activeProvider"] = nextProvider;
            state["lastSwitched"] = DateTime.UtcNow.ToString("o");
            try {
                File.WriteAllText(stateFile, js.Serialize(state));
            } catch {}

            try {
                if (File.Exists(configFile)) {
                    string cfgJson = File.ReadAllText(configFile);
                    var cfg = js.Deserialize<Dictionary<string, object>>(cfgJson);
                    if (cfg != null) {
                        cfg["provider"] = nextProvider;
                        File.WriteAllText(configFile, js.Serialize(cfg));
                    }
                }
            } catch {}

            // 6. Log diagnostic
            try {
                string ts = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                File.AppendAllText(logFile, string.Format("[{0}] [CYCLE_PROVIDER_FAST] Fast native cycle: {1} -> {2}{3}", ts, currentProvider, nextProvider, Environment.NewLine));
            } catch {}

            return; // Exits cleanly in ~15ms with NO panel opening
        } catch (Exception ex) {
            // Fail-safe: fallback to powershell execution if any exception occurs
            try {
                string ts = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                File.AppendAllText(logFile, string.Format("[{0}] [CYCLE_PROVIDER_FAST] Exception, falling back to pwsh: {1}{2}", ts, ex.Message, Environment.NewLine));
            } catch {}
            FallbackToPowerShell(userProfile, args);
        }
    }

    private static void RunSilent(string fileName, string args) {
        try {
            ProcessStartInfo psi = new ProcessStartInfo {
                FileName = fileName,
                Arguments = args,
                CreateNoWindow = true,
                UseShellExecute = false,
                WindowStyle = ProcessWindowStyle.Hidden
            };
            Process.Start(psi);
        } catch {}
    }

    private static string FindWallpaperEngineExe() {
        string[] candidates = new string[] {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Steam\steamapps\common\wallpaper_engine\wallpaper64.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Steam\steamapps\common\wallpaper_engine\wallpaper64.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Steam\steamapps\common\wallpaper_engine\wallpaper32.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Steam\steamapps\common\wallpaper_engine\wallpaper32.exe")
        };
        foreach (string p in candidates) {
            if (File.Exists(p)) return p;
        }

        // Check Steam library paths via registry if possible
        try {
            using (Microsoft.Win32.RegistryKey key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam")) {
                if (key != null) {
                    object steamPath = key.GetValue("SteamPath");
                    if (steamPath != null) {
                        string sp = steamPath.ToString().Replace('/', '\\');
                        string weCand = Path.Combine(sp, @"steamapps\common\wallpaper_engine\wallpaper64.exe");
                        if (File.Exists(weCand)) return weCand;
                    }
                }
            }
        } catch {}

        return "";
    }

    private static string FindLivelyExe() {
        string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string[] candidates = new string[] {
            Path.Combine(localAppData, @"Programs\Lively Wallpaper\Lively.exe"),
            Path.Combine(localAppData, @"Programs\Lively Wallpaper\livelycu.exe"),
            Path.Combine(localAppData, @"Microsoft\WindowsApps\Lively.exe")
        };
        foreach (string p in candidates) {
            if (File.Exists(p)) return p;
        }
        return "";
    }

    private static bool IsValidImage(string path) {
        if (string.IsNullOrEmpty(path)) return false;
        string ext = Path.GetExtension(path).ToLowerInvariant();
        return ext == ".jpg" || ext == ".png" || ext == ".jpeg" || ext == ".webp" || ext == ".bmp";
    }

    private static string FindFallbackStaticWallpaper(string userProfile) {
        string[] searchDirs = new string[] {
            Path.Combine(userProfile, @"Pictures\Wallpapers\Default"),
            Path.Combine(userProfile, @"Pictures\Wallpapers"),
            Path.Combine(userProfile, @"Documents\window_rice\wallpapers"),
            Path.Combine(userProfile, @".dotfiles\window_rice\wallpapers")
        };
        foreach (string dir in searchDirs) {
            if (Directory.Exists(dir)) {
                try {
                    string[] files = Directory.GetFiles(dir);
                    Array.Sort(files);
                    foreach (string f in files) {
                        if (IsValidImage(f)) return f;
                    }
                } catch {}
            }
        }
        return null;
    }

    private static void FallbackToPowerShell(string userProfile, string[] args) {
        string script = Path.Combine(userProfile, @".config\yasb\scripts\cycle-provider.ps1");
        if (!File.Exists(script)) {
            string[] docCandidates = new string[] {
                Path.Combine(userProfile, @"Documents\window_rice\configs\yasb\scripts\cycle-provider.ps1"),
                Path.Combine(userProfile, @".dotfiles\window_rice\configs\yasb\scripts\cycle-provider.ps1")
            };
            foreach (string c in docCandidates) {
                if (File.Exists(c)) { script = c; break; }
            }
        }

        string exe = "powershell.exe";
        string[] pwshCandidates = new string[] {
            Path.Combine(userProfile, @"scoop\apps\pwsh\current\pwsh.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"PowerShell\7\pwsh.exe")
        };
        foreach (string p in pwshCandidates) {
            if (File.Exists(p)) { exe = p; break; }
        }

        string argStr = "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"";
        if (args != null && args.Length > 0) {
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
