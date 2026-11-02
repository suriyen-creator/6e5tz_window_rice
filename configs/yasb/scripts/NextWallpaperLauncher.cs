using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Web.Script.Serialization;

class NextWallpaperLauncher {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    public const int SPI_SETDESKWALLPAPER = 0x0014;
    public const int SPIF_UPDATEINIFILE = 0x01;
    public const int SPIF_SENDCHANGE = 0x02;

    static void Main(string[] args) {
        string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        string configDir = Path.Combine(userProfile, @".config\6e5tz");
        string stateFile = Path.Combine(configDir, "wallpaper-state.json");
        string logFile = Path.Combine(configDir, "wallpaper.log");

        try {
            JavaScriptSerializer js = new JavaScriptSerializer();
            Dictionary<string, object> state = null;
            string activeProvider = "Static";

            if (File.Exists(stateFile)) {
                try {
                    string json = File.ReadAllText(stateFile);
                    state = js.Deserialize<Dictionary<string, object>>(json);
                    if (state != null && state.ContainsKey("activeProvider") && state["activeProvider"] != null) {
                        activeProvider = state["activeProvider"].ToString();
                    }
                } catch {}
            }
            if (state == null) state = new Dictionary<string, object>();

            // If args specify a provider explicitly, override
            string procName = Process.GetCurrentProcess().ProcessName.ToLowerInvariant();
            bool isPauseRequest = procName.Contains("pause");

            if (args != null && args.Length > 0) {
                for (int i = 0; i < args.Length; i++) {
                    if (args[i].Equals("-Provider", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) {
                        activeProvider = args[i + 1];
                    }
                    if (args[i].Equals("-Pause", StringComparison.OrdinalIgnoreCase) ||
                        args[i].Equals("-TogglePause", StringComparison.OrdinalIgnoreCase) ||
                        args[i].Equals("pause", StringComparison.OrdinalIgnoreCase) ||
                        args[i].Equals("toggle", StringComparison.OrdinalIgnoreCase)) {
                        isPauseRequest = true;
                    }
                }
            }

            if (isPauseRequest) {
                if (activeProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
                    ToggleWallpaperEnginePause(userProfile, logFile);
                } else {
                    Log(logFile, "FAST-PAUSE", "Pause request ignored: active provider is " + activeProvider);
                }
                return;
            }

            if (activeProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
                CycleWallpaperEngine(userProfile, state, stateFile, logFile);
            } else {
                CycleStatic(userProfile, state, stateFile, logFile);
            }
        } catch (Exception ex) {
            Log(logFile, "FAST-NEXT", "Exception in fast C# next launcher: " + ex.Message + ". Falling back to PowerShell.");
            RunPowerShellFallback(userProfile, args);
        }
    }

    private static void ToggleWallpaperEnginePause(string userProfile, string logFile) {
        string weExe = FindWallpaperEngineExe();
        if (string.IsNullOrEmpty(weExe) || !File.Exists(weExe)) {
            Log(logFile, "FAST-PAUSE", "Wallpaper Engine executable not found.");
            return;
        }

        string tempState = Path.Combine(Path.GetTempPath(), "yasb_we_state.txt");
        string currentState = "playing";
        if (File.Exists(tempState)) {
            try {
                currentState = File.ReadAllText(tempState).Trim().ToLowerInvariant();
            } catch {}
        }

        if (currentState == "paused") {
            RunSilent(weExe, "-control play");
            try { File.WriteAllText(tempState, "playing"); } catch {}
            Log(logFile, "FAST-PAUSE", "Resumed Wallpaper Engine (-control play).");
        } else {
            RunSilent(weExe, "-control pause");
            try { File.WriteAllText(tempState, "paused"); } catch {}
            Log(logFile, "FAST-PAUSE", "Paused Wallpaper Engine (-control pause).");
        }
    }

    private static void CycleWallpaperEngine(string userProfile, Dictionary<string, object> state, string stateFile, string logFile) {
        string weExe = FindWallpaperEngineExe();
        if (string.IsNullOrEmpty(weExe) || !File.Exists(weExe)) {
            Log(logFile, "FAST-NEXT", "Wallpaper Engine executable not found.");
            return;
        }

        // 1. Gather all project.json items in Workshop and Default
        List<string> projects = new List<string>();
        string wsDir = Path.Combine(Path.GetDirectoryName(weExe), @"..\..\workshop\content\431960");
        try { wsDir = Path.GetFullPath(wsDir); } catch {}

        if (Directory.Exists(wsDir)) {
            try {
                foreach (string dir in Directory.GetDirectories(wsDir)) {
                    string pj = Path.Combine(dir, "project.json");
                    if (File.Exists(pj)) projects.Add(pj);
                }
            } catch {}
        }

        string defDir = Path.Combine(Path.GetDirectoryName(weExe), @"projects\defaultprojects");
        if (Directory.Exists(defDir)) {
            try {
                foreach (string dir in Directory.GetDirectories(defDir)) {
                    string pj = Path.Combine(dir, "project.json");
                    if (File.Exists(pj)) projects.Add(pj);
                }
            } catch {}
        }

        if (projects.Count == 0) {
            // Send default nextWallpaper control
            RunSilent(weExe, "-control nextWallpaper");
            Log(logFile, "FAST-NEXT", "Sent -control nextWallpaper (no explicit workshop items found).");
            return;
        }

        string current = "";
        if (state.ContainsKey("wallpaperEngineWallpaper") && state["wallpaperEngineWallpaper"] != null) {
            current = state["wallpaperEngineWallpaper"].ToString();
        } else if (state.ContainsKey("currentWallpaper") && state["currentWallpaper"] != null) {
            current = state["currentWallpaper"].ToString();
        }

        int curIdx = -1;
        for (int i = 0; i < projects.Count; i++) {
            if (projects[i].Equals(current, StringComparison.OrdinalIgnoreCase) ||
                Path.GetDirectoryName(projects[i]).Equals(current, StringComparison.OrdinalIgnoreCase)) {
                curIdx = i;
                break;
            }
        }

        int nextIdx = (curIdx + 1) % projects.Count;
        string nextProj = projects[nextIdx];

        RunSilent(weExe, string.Format("-control openWallpaper -file \"{0}\"", nextProj));

        state["activeProvider"] = "WallpaperEngine";
        state["currentWallpaper"] = nextProj;
        state["wallpaperEngineWallpaper"] = nextProj;
        state["lastSwitched"] = DateTime.UtcNow.ToString("o");

        try {
            JavaScriptSerializer js = new JavaScriptSerializer();
            File.WriteAllText(stateFile, js.Serialize(state));
        } catch {}

        Log(logFile, "FAST-NEXT", string.Format("Advanced Wallpaper Engine ({0}/{1}): {2}", nextIdx + 1, projects.Count, nextProj));
    }

    private static void CycleStatic(string userProfile, Dictionary<string, object> state, string stateFile, string logFile) {
        List<string> searchDirs = new List<string>();
        searchDirs.Add(Path.Combine(userProfile, @"Pictures\Wallpapers\Default"));
        searchDirs.Add(Path.Combine(userProfile, @"Pictures\Wallpapers"));
        searchDirs.Add(Path.Combine(userProfile, @"Documents\window_rice\wallpapers"));

        List<string> images = new List<string>();
        string[] exts = new string[] { ".jpg", ".png", ".jpeg", ".webp", ".bmp" };

        foreach (string d in searchDirs) {
            if (Directory.Exists(d)) {
                try {
                    foreach (string f in Directory.GetFiles(d)) {
                        string ext = Path.GetExtension(f).ToLowerInvariant();
                        if (Array.IndexOf(exts, ext) >= 0 && !images.Contains(f)) {
                            images.Add(f);
                        }
                    }
                } catch {}
            }
        }

        if (images.Count == 0) {
            Log(logFile, "FAST-NEXT", "No static wallpapers found.");
            return;
        }

        images.Sort(StringComparer.OrdinalIgnoreCase);

        string current = "";
        if (state.ContainsKey("staticWallpaper") && state["staticWallpaper"] != null) {
            current = state["staticWallpaper"].ToString();
        } else if (state.ContainsKey("currentWallpaper") && state["currentWallpaper"] != null) {
            current = state["currentWallpaper"].ToString();
        }

        int curIdx = -1;
        for (int i = 0; i < images.Count; i++) {
            if (images[i].Equals(current, StringComparison.OrdinalIgnoreCase)) {
                curIdx = i;
                break;
            }
        }

        int nextIdx = (curIdx + 1) % images.Count;
        string nextImg = images[nextIdx];

        SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, nextImg, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);

        state["activeProvider"] = "Static";
        state["currentWallpaper"] = nextImg;
        state["staticWallpaper"] = nextImg;
        state["lastSwitched"] = DateTime.UtcNow.ToString("o");

        try {
            JavaScriptSerializer js = new JavaScriptSerializer();
            File.WriteAllText(stateFile, js.Serialize(state));
        } catch {}

        Log(logFile, "FAST-NEXT", string.Format("Advanced Static wallpaper ({0}/{1}): {2}", nextIdx + 1, images.Count, nextImg));
    }

    private static string FindWallpaperEngineExe() {
        string[] candidates = new string[] {
            @"C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe",
            @"C:\Program Files\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe",
            @"C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper32.exe",
            @"C:\Program Files\Steam\steamapps\common\wallpaper_engine\wallpaper32.exe"
        };
        foreach (string c in candidates) {
            if (File.Exists(c)) return c;
        }
        return null;
    }

    private static void RunSilent(string exe, string args) {
        try {
            ProcessStartInfo psi = new ProcessStartInfo {
                FileName = exe,
                Arguments = args,
                CreateNoWindow = true,
                UseShellExecute = false,
                WindowStyle = ProcessWindowStyle.Hidden
            };
            Process.Start(psi);
        } catch {}
    }

    private static void RunPowerShellFallback(string userProfile, string[] args) {
        try {
            string script = Path.Combine(userProfile, @".config\yasb\scripts\next-wallpaper.ps1");
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

            RunSilent(exe, argStr);
        } catch {}
    }

    private static void Log(string logFile, string category, string msg) {
        try {
            string line = string.Format("[{0:yyyy-MM-dd HH:mm:ss.fff}] [{1}] {2}{3}", DateTime.Now, category, msg, Environment.NewLine);
            File.AppendAllText(logFile, line);
        } catch {}
    }
}
