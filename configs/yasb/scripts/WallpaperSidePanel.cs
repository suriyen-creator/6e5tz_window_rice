using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using ShapePath = System.Windows.Shapes.Path;
using System.Windows.Threading;

// =============================================================================
// 6e5tz Universal Wallpaper Manager - Display Mode Core
// Floating Acrylic Side Panel (Grid) + Real Fullscreen Acrylic 3D Cover Flow
// Single-Press Shortcut Architecture + Catppuccin Mocha + Zero-Console Execution
// =============================================================================

public class WallpaperItem {
    public string Title { get; set; }
    public string Type { get; set; } // Scene, Video, Web, Application, Image
    public string PreviewPath { get; set; }
    public string ItemPath { get; set; }
    public string Provider { get; set; }
    public string Collection { get; set; }
    public bool IsActive { get; set; }
}

public static class WallpaperManagerCore {
    // -------------------------------------------------------------------------
    // Win32 Interop
    // -------------------------------------------------------------------------
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    public const int SPI_SETDESKWALLPAPER = 0x0014;
    public const int SPIF_UPDATEINIFILE = 0x01;
    public const int SPIF_SENDCHANGE = 0x02;

    [StructLayout(LayoutKind.Sequential)]
    public struct AccentPolicy {
        public int AccentState;
        public int AccentFlags;
        public int GradientColor;
        public int AnimationId;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct WindowCompositionAttributeData {
        public int Attribute;
        public IntPtr Data;
        public int SizeOfData;
    }

    [DllImport("user32.dll")]
    public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    public const uint WM_CLOSE = 0x0010;

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public const uint SWP_SHOWWINDOW = 0x0040;

    public static void EnableAcrylic(Window win, int gradientColor = unchecked((int)0xCC181825)) {
        try {
            IntPtr hwnd = new WindowInteropHelper(win).Handle;
            AccentPolicy policy = new AccentPolicy {
                AccentState = 4, // ACCENT_ENABLE_ACRYLICBLURBEHIND
                AccentFlags = 2,
                GradientColor = gradientColor,
                AnimationId = 0
            };
            int policySize = Marshal.SizeOf(policy);
            IntPtr policyPtr = Marshal.AllocHGlobal(policySize);
            Marshal.StructureToPtr(policy, policyPtr, false);

            WindowCompositionAttributeData data = new WindowCompositionAttributeData {
                Attribute = 19, // WCA_ACCENT_POLICY
                Data = policyPtr,
                SizeOfData = policySize
            };
            SetWindowCompositionAttribute(hwnd, ref data);
            Marshal.FreeHGlobal(policyPtr);
        } catch {}
    }

    // -------------------------------------------------------------------------
    // Active Monitor WorkArea and Full Bounds Resolution (Win32)
    // -------------------------------------------------------------------------
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public class MONITORINFO {
        public int cbSize = Marshal.SizeOf(typeof(MONITORINFO));
        public RECT rcMonitor = new RECT();
        public RECT rcWork = new RECT();
        public int dwFlags = 0;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern IntPtr MonitorFromPoint(POINT pt, uint dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool GetMonitorInfo(IntPtr hMonitor, [In, Out] MONITORINFO lpmi);

    public const uint MONITOR_DEFAULTTONEAREST = 2;

    public static Rect GetActiveMonitorWorkArea() {
        try {
            POINT pt;
            if (GetCursorPos(out pt)) {
                IntPtr hMon = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
                if (hMon != IntPtr.Zero) {
                    MONITORINFO mi = new MONITORINFO();
                    if (GetMonitorInfo(hMon, mi)) {
                        return new Rect(mi.rcWork.Left, mi.rcWork.Top, mi.rcWork.Right - mi.rcWork.Left, mi.rcWork.Bottom - mi.rcWork.Top);
                    }
                }
            }
        } catch {}
        return SystemParameters.WorkArea;
    }

    public static Rect GetActiveMonitorBounds() {
        try {
            POINT pt;
            if (GetCursorPos(out pt)) {
                IntPtr hMon = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
                if (hMon != IntPtr.Zero) {
                    MONITORINFO mi = new MONITORINFO();
                    if (GetMonitorInfo(hMon, mi)) {
                        return new Rect(mi.rcMonitor.Left, mi.rcMonitor.Top, mi.rcMonitor.Right - mi.rcMonitor.Left, mi.rcMonitor.Bottom - mi.rcMonitor.Top);
                    }
                }
            }
        } catch {}
        return new Rect(0, 0, SystemParameters.PrimaryScreenWidth, SystemParameters.PrimaryScreenHeight);
    }

    // -------------------------------------------------------------------------
    // Catppuccin Mocha Color Palette & Typography
    // -------------------------------------------------------------------------
    public static readonly Color ColorBase = (Color)ColorConverter.ConvertFromString("#1e1e2e");
    public static readonly Color ColorMantle = (Color)ColorConverter.ConvertFromString("#181825");
    public static readonly Color ColorCrust = (Color)ColorConverter.ConvertFromString("#11111b");
    public static readonly Color ColorSurface0 = (Color)ColorConverter.ConvertFromString("#313244");
    public static readonly Color ColorSurface1 = (Color)ColorConverter.ConvertFromString("#45475a");
    public static readonly Color ColorSurface2 = (Color)ColorConverter.ConvertFromString("#585b70");
    public static readonly Color ColorText = (Color)ColorConverter.ConvertFromString("#cdd6f4");
    public static readonly Color ColorSubtext = (Color)ColorConverter.ConvertFromString("#a6adc8");
    public static readonly Color ColorOverlay = (Color)ColorConverter.ConvertFromString("#6c7086");
    public static readonly Color ColorBlue = (Color)ColorConverter.ConvertFromString("#89b4fa");
    public static readonly Color ColorMauve = (Color)ColorConverter.ConvertFromString("#cba6f7");
    public static readonly Color ColorGreen = (Color)ColorConverter.ConvertFromString("#a6e3a1");
    public static readonly Color ColorRed = (Color)ColorConverter.ConvertFromString("#f38ba8");
    public static readonly Color ColorPeach = (Color)ColorConverter.ConvertFromString("#fab387");

    public static readonly FontFamily AppFont = new FontFamily("Segoe UI Variable Text, Segoe UI, sans-serif");
    public static readonly FontFamily AppHeadingFont = new FontFamily("Segoe UI Variable Display, Segoe UI Semibold, Segoe UI, sans-serif");

    public static SolidColorBrush BrushOf(Color c, double opacity = 1.0) {
        SolidColorBrush b = new SolidColorBrush(c);
        b.Opacity = opacity;
        b.Freeze();
        return b;
    }

    // -------------------------------------------------------------------------
    // Resolution-Independent Vector Icon Helper
    // -------------------------------------------------------------------------
    public static ShapePath CreateVectorIcon(string pathData, Color strokeOrFill, double size = 14, bool isFill = false) {
        ShapePath p = new ShapePath {
            Width = size,
            Height = size,
            Stretch = Stretch.Uniform,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Data = Geometry.Parse(pathData)
        };
        if (isFill) {
            p.Fill = BrushOf(strokeOrFill);
        } else {
            p.Stroke = BrushOf(strokeOrFill);
            p.StrokeThickness = 1.6;
            p.StrokeStartLineCap = PenLineCap.Round;
            p.StrokeEndLineCap = PenLineCap.Round;
            p.StrokeLineJoin = PenLineJoin.Round;
        }
        return p;
    }

    // Common vector icon geometries
    public const string IconPrevPath = "M 9 3 L 3 9 L 9 15";
    public const string IconNextPath = "M 3 3 L 9 9 L 3 15";
    public const string IconShufflePath = "M 2 5 L 6 5 L 10 11 L 14 11 M 11 9 L 14 11 L 11 13 M 2 11 L 6 11 L 8 9 M 10 7 L 14 7 M 11 5 L 14 7 L 11 9";
    public const string IconFolderPath = "M 2 4 C 2 3 3 2 4 2 L 7 2 L 9 4 L 14 4 C 15 4 16 5 16 6 L 16 13 C 16 14 15 15 14 15 L 4 15 C 3 15 2 14 2 13 Z";
    public const string IconGridPath = "M 2 2 L 6 2 L 6 6 L 2 6 Z M 8 2 L 12 2 L 12 6 L 8 6 Z M 2 8 L 6 8 L 6 12 L 2 12 Z M 8 8 L 12 8 L 12 12 L 8 12 Z";
    public const string IconCoverFlowPath = "M 2 4 L 4 4 L 4 12 L 2 12 Z M 5 2 L 9 2 L 9 14 L 5 14 Z M 10 4 L 12 4 L 12 12 L 10 12 Z";
    public const string IconStarPath = "M 7 1 L 9 5 L 13 6 L 10 9 L 11 13 L 7 11 L 3 13 L 4 9 L 1 6 L 5 5 Z";
    public const string IconCheckPath = "M 2 7 L 5 10 L 12 3";
    public const string IconClosePath = "M 3 3 L 11 11 M 11 3 L 3 11";
    public const string IconRotatePath = "M 12 7 A 5 5 0 1 1 7 2 M 7 2 L 10 2 M 7 2 L 7 5";

    // -------------------------------------------------------------------------
    // Diagnostic Logging
    // -------------------------------------------------------------------------
    public static void LogDiagnostic(string category, string message, string errorDetails = "") {
        try {
            if (!Directory.Exists(ConfigDir)) Directory.CreateDirectory(ConfigDir);
            string logFile = Path.Combine(ConfigDir, "wallpaper.log");
            if (File.Exists(logFile)) {
                FileInfo fi = new FileInfo(logFile);
                if (fi.Length > 524288) {
                    string old = logFile + ".old";
                    try { File.Delete(old); } catch {}
                    try { File.Move(logFile, old); } catch {}
                }
            }
            string ts = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
            string line = string.Format("[{0}] [{1}] {2}", ts, category, message);
            if (!string.IsNullOrEmpty(errorDetails)) line += " | ERROR: " + errorDetails;
            File.AppendAllText(logFile, line + Environment.NewLine);
        } catch {}
    }

    // -------------------------------------------------------------------------
    // Shared Paths & Global Settings
    // -------------------------------------------------------------------------
    public static string UserProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    public static string ConfigDir = Path.Combine(UserProfile, @".config\6e5tz");
    public static string ConfigFile = Path.Combine(ConfigDir, "wallpaper-manager.json");
    public static string StateFile = Path.Combine(ConfigDir, "wallpaper-state.json");
    public static string WallpaperEngineExe = FindWallpaperEngineExe();
    public static string SteamWorkshopDir = FindSteamWorkshopDir();
    public static string DefaultProjectsDir = FindDefaultProjectsDir();

    public static string LaunchMode = "grid";
    public static bool CoverFlowFullscreen = true;
    public static bool CoverFlowBackgroundBlur = true;
    public static double CoverFlowDarkOverlayOpacity = 0.55;

    public static void LoadGlobalConfig() {
        try {
            if (File.Exists(ConfigFile)) {
                string json = File.ReadAllText(ConfigFile);
                JavaScriptSerializer js = new JavaScriptSerializer();
                var cfg = js.Deserialize<Dictionary<string, object>>(json);
                if (cfg != null && cfg.ContainsKey("ui") && cfg["ui"] is Dictionary<string, object>) {
                    var ui = (Dictionary<string, object>)cfg["ui"];
                    if (ui.ContainsKey("launchMode") && ui["launchMode"] != null) {
                        string lm = ui["launchMode"].ToString().Trim();
                        if (lm.Equals("coverflow", StringComparison.OrdinalIgnoreCase)) {
                            LaunchMode = "coverFlow";
                        } else {
                            LaunchMode = "grid";
                        }
                    }
                    if (ui.ContainsKey("coverFlow") && ui["coverFlow"] is Dictionary<string, object>) {
                        var cf = (Dictionary<string, object>)ui["coverFlow"];
                        if (cf.ContainsKey("fullscreen") && cf["fullscreen"] != null) {
                            bool.TryParse(cf["fullscreen"].ToString(), out CoverFlowFullscreen);
                        }
                        if (cf.ContainsKey("backgroundBlur") && cf["backgroundBlur"] != null) {
                            bool.TryParse(cf["backgroundBlur"].ToString(), out CoverFlowBackgroundBlur);
                        }
                        if (cf.ContainsKey("darkOverlayOpacity") && cf["darkOverlayOpacity"] != null) {
                            double.TryParse(cf["darkOverlayOpacity"].ToString(), out CoverFlowDarkOverlayOpacity);
                        }
                    }
                }
            }
        } catch {}
    }

    public static void SaveLaunchMode(string mode) {
        LaunchMode = mode.Equals("coverflow", StringComparison.OrdinalIgnoreCase) ? "coverFlow" : "grid";
        try {
            if (File.Exists(ConfigFile)) {
                JavaScriptSerializer js = new JavaScriptSerializer();
                string json = File.ReadAllText(ConfigFile);
                var cfg = js.Deserialize<Dictionary<string, object>>(json);
                if (cfg != null) {
                    if (!cfg.ContainsKey("ui") || !(cfg["ui"] is Dictionary<string, object>)) {
                        cfg["ui"] = new Dictionary<string, object>();
                    }
                    var ui = (Dictionary<string, object>)cfg["ui"];
                    ui["launchMode"] = LaunchMode;
                    File.WriteAllText(ConfigFile, js.Serialize(cfg));
                    LogDiagnostic("CONFIG", "Saved launchMode to: " + LaunchMode);
                }
            }
        } catch {}
    }

    // High performance in-memory caches
    private static readonly Dictionary<string, List<WallpaperItem>> _libraryCache = new Dictionary<string, List<WallpaperItem>>(StringComparer.OrdinalIgnoreCase);
    private static readonly Dictionary<string, BitmapSource> _thumbnailCache = new Dictionary<string, BitmapSource>(StringComparer.OrdinalIgnoreCase);
    private static readonly object _cacheLock = new object();

    private static string FindWallpaperEngineExe() {
        string[] candidates = new string[] {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Steam\steamapps\common\wallpaper_engine\wallpaper64.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Steam\steamapps\common\wallpaper_engine\wallpaper64.exe")
        };
        foreach (string w in candidates) {
            if (File.Exists(w)) return w;
        }
        return "";
    }

    private static string FindDefaultProjectsDir() {
        if (!string.IsNullOrEmpty(WallpaperEngineExe)) {
            string dir = Path.Combine(Path.GetDirectoryName(WallpaperEngineExe), @"projects\defaultprojects");
            if (Directory.Exists(dir)) return dir;
        }
        return "";
    }

    private static string FindSteamWorkshopDir() {
        if (!string.IsNullOrEmpty(WallpaperEngineExe)) {
            string weDir = Path.GetDirectoryName(WallpaperEngineExe);
            string steamApps = Path.GetFullPath(Path.Combine(weDir, @"..\.."));
            string ws = Path.Combine(steamApps, @"workshop\content\431960");
            if (Directory.Exists(ws)) return ws;
        }
        return "";
    }

    // -------------------------------------------------------------------------
    // High-Performance In-Memory Library Discovery & Caching
    // -------------------------------------------------------------------------
    public static List<WallpaperItem> GetWallpapers(string provider, string collection, bool forceRefresh = false) {
        string cacheKey = provider + ":" + collection;
        lock (_cacheLock) {
            if (!forceRefresh && _libraryCache.ContainsKey(cacheKey)) {
                return _libraryCache[cacheKey];
            }
        }

        List<WallpaperItem> items = new List<WallpaperItem>();
        if (provider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            items = LoadWallpaperEngineWallpapers(collection);
        } else {
            items = LoadStaticWallpapers(collection);
        }

        lock (_cacheLock) {
            _libraryCache[cacheKey] = items;
        }
        return items;
    }

    private static List<WallpaperItem> LoadStaticWallpapers(string collection) {
        List<WallpaperItem> list = new List<WallpaperItem>();
        string root = Path.Combine(UserProfile, @"Pictures\Wallpapers");
        try {
            if (File.Exists(ConfigFile)) {
                string json = File.ReadAllText(ConfigFile);
                JavaScriptSerializer js = new JavaScriptSerializer();
                var cfg = js.Deserialize<Dictionary<string, object>>(json);
                if (cfg != null && cfg.ContainsKey("collectionRoot") && cfg["collectionRoot"] != null) {
                    root = cfg["collectionRoot"].ToString().Replace("__USERPROFILE__", UserProfile);
                }
            }
        } catch {}

        string targetDir = root;
        if (!string.IsNullOrEmpty(collection) && !collection.Equals("Default", StringComparison.OrdinalIgnoreCase)) {
            string sub = Path.Combine(root, collection);
            if (Directory.Exists(sub)) targetDir = sub;
        }

        if (Directory.Exists(targetDir)) {
            try {
                string[] files = Directory.GetFiles(targetDir);
                foreach (string f in files) {
                    string ext = Path.GetExtension(f).ToLowerInvariant();
                    if (ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".webp" || ext == ".bmp") {
                        list.Add(new WallpaperItem {
                            Title = Path.GetFileNameWithoutExtension(f),
                            Type = "Image",
                            PreviewPath = f,
                            ItemPath = f,
                            Provider = "Static",
                            Collection = collection
                        });
                    }
                }
            } catch {}
        }
        return list;
    }

    private static List<WallpaperItem> LoadWallpaperEngineWallpapers(string collection) {
        List<WallpaperItem> list = new List<WallpaperItem>();
        JavaScriptSerializer serializer = new JavaScriptSerializer();
        HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        Action<string, string> parseProjectJson = (projPath, colName) => {
            if (!File.Exists(projPath)) return;
            string fullPath = Path.GetFullPath(projPath);
            if (seen.Contains(fullPath)) return;
            seen.Add(fullPath);

            string dir = Path.GetDirectoryName(fullPath);
            string title = Path.GetFileName(dir);
            string type = "Scene";
            string preview = "";

            try {
                string raw = File.ReadAllText(fullPath);
                var meta = serializer.Deserialize<Dictionary<string, object>>(raw);
                if (meta != null) {
                    if (meta.ContainsKey("title") && meta["title"] != null && !string.IsNullOrWhiteSpace(meta["title"].ToString())) {
                        title = meta["title"].ToString();
                    }
                    if (meta.ContainsKey("type") && meta["type"] != null && !string.IsNullOrWhiteSpace(meta["type"].ToString())) {
                        type = meta["type"].ToString();
                    }
                    if (meta.ContainsKey("preview") && meta["preview"] != null) {
                        string cand = Path.Combine(dir, meta["preview"].ToString());
                        if (File.Exists(cand)) preview = cand;
                    }
                }
            } catch {}

            if (string.IsNullOrEmpty(preview)) {
                foreach (string cName in new string[] { "preview.jpg", "preview.png", "preview.gif", "preview.jpeg" }) {
                    string cPath = Path.Combine(dir, cName);
                    if (File.Exists(cPath)) { preview = cPath; break; }
                }
            }

            list.Add(new WallpaperItem {
                Title = title,
                Type = type,
                PreviewPath = preview,
                ItemPath = fullPath,
                Provider = "WallpaperEngine",
                Collection = colName
            });
        };

        // If collection is a Playlist
        if (!collection.Equals("Default Projects", StringComparison.OrdinalIgnoreCase) &&
            !collection.Equals("Workshop Subscriptions", StringComparison.OrdinalIgnoreCase) &&
            !string.IsNullOrEmpty(WallpaperEngineExe)) {

            string weConfig = Path.Combine(Path.GetDirectoryName(WallpaperEngineExe), "config.json");
            if (File.Exists(weConfig)) {
                try {
                    string raw = File.ReadAllText(weConfig);
                    var dict = serializer.Deserialize<Dictionary<string, object>>(raw);
                    foreach (var kvp in dict) {
                        if (kvp.Value is Dictionary<string, object>) {
                            var v = (Dictionary<string, object>)kvp.Value;
                            if (v.ContainsKey("general") && v["general"] is Dictionary<string, object>) {
                                var g = (Dictionary<string, object>)v["general"];
                                if (g.ContainsKey("playlists") && g["playlists"] is object[]) {
                                    foreach (var pl in (object[])g["playlists"]) {
                                        if (pl is Dictionary<string, object>) {
                                            var pld = (Dictionary<string, object>)pl;
                                            if (pld.ContainsKey("name") && pld["name"].ToString().Equals(collection, StringComparison.OrdinalIgnoreCase)) {
                                                if (pld.ContainsKey("items") && pld["items"] is object[]) {
                                                    foreach (var item in (object[])pld["items"]) {
                                                        string itemPath = item.ToString().Replace('/', '\\');
                                                        string projCandidate = itemPath;
                                                        if (!projCandidate.EndsWith("project.json", StringComparison.OrdinalIgnoreCase)) {
                                                            string parent = Path.GetDirectoryName(itemPath);
                                                            string subProj = Path.Combine(parent, "project.json");
                                                            if (File.Exists(subProj)) projCandidate = subProj;
                                                        }
                                                        if (File.Exists(projCandidate)) {
                                                            parseProjectJson(projCandidate, collection);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch {}
            }
        }

        // If collection is Default Projects
        if (collection.Equals("Default Projects", StringComparison.OrdinalIgnoreCase) &&
            !string.IsNullOrEmpty(DefaultProjectsDir) && Directory.Exists(DefaultProjectsDir)) {
            try {
                foreach (string dir in Directory.GetDirectories(DefaultProjectsDir)) {
                    string proj = Path.Combine(dir, "project.json");
                    if (File.Exists(proj)) parseProjectJson(proj, "Default Projects");
                }
            } catch {}
        }

        // If collection is Workshop Subscriptions
        if (collection.Equals("Workshop Subscriptions", StringComparison.OrdinalIgnoreCase) &&
            !string.IsNullOrEmpty(SteamWorkshopDir) && Directory.Exists(SteamWorkshopDir)) {
            try {
                foreach (string dir in Directory.GetDirectories(SteamWorkshopDir)) {
                    string proj = Path.Combine(dir, "project.json");
                    if (File.Exists(proj)) parseProjectJson(proj, "Workshop Subscriptions");
                }
            } catch {}
        }

        return list;
    }

    // -------------------------------------------------------------------------
    // Asynchronous Frozen Thumbnail Loader (Zero UI Dispatcher Overhead)
    // -------------------------------------------------------------------------
    public static void LoadThumbnailAsync(string filePath, Image targetImg, int decodeWidth, Action onLoaded = null) {
        if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath)) {
            targetImg.Source = null;
            return;
        }

        string cacheKey = filePath + "@" + decodeWidth;
        lock (_cacheLock) {
            if (_thumbnailCache.ContainsKey(cacheKey)) {
                targetImg.Source = _thumbnailCache[cacheKey];
                if (onLoaded != null) onLoaded();
                return;
            }
        }

        ThreadPool.QueueUserWorkItem(_ => {
            try {
                BitmapImage bi = new BitmapImage();
                bi.BeginInit();
                bi.UriSource = new Uri(filePath, UriKind.Absolute);
                bi.DecodePixelWidth = decodeWidth;
                bi.CacheOption = BitmapCacheOption.OnLoad;
                bi.EndInit();
                bi.Freeze(); // Crucial: Freeze makes BitmapSource thread-safe across threads!

                lock (_cacheLock) {
                    if (!_thumbnailCache.ContainsKey(cacheKey)) {
                        _thumbnailCache[cacheKey] = bi;
                    }
                }

                targetImg.Dispatcher.BeginInvoke(new Action(() => {
                    targetImg.Source = bi;
                    if (onLoaded != null) onLoaded();
                }), DispatcherPriority.Normal);
            } catch {
                targetImg.Dispatcher.BeginInvoke(new Action(() => {
                    targetImg.Source = null;
                }), DispatcherPriority.Normal);
            }
        });
    }

    // -------------------------------------------------------------------------
    // Blazing-Fast Native Wallpaper Actuators (0-15ms)
    // -------------------------------------------------------------------------
    public static void ApplyWallpaperDirect(string provider, string itemPath) {
        if (string.IsNullOrEmpty(itemPath)) return;

        if (provider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            if (!string.IsNullOrEmpty(WallpaperEngineExe) && File.Exists(WallpaperEngineExe)) {
                try {
                    ProcessStartInfo psi = new ProcessStartInfo {
                        FileName = WallpaperEngineExe,
                        Arguments = string.Format("-control openWallpaper -file \"{0}\"", itemPath),
                        CreateNoWindow = true,
                        UseShellExecute = false,
                        WindowStyle = ProcessWindowStyle.Hidden
                    };
                    Process.Start(psi);
                } catch {}
            }
        } else {
            // Static Wallpaper via Win32 API
            StopWallpaperEngine();
            if (File.Exists(itemPath)) {
                try {
                    SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, itemPath, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
                } catch {}
            }
            StopWallpaperEngine();
        }

        // Asynchronous state persistence (never block UI thread!)
        ThreadPool.QueueUserWorkItem(_ => {
            SaveStateDirect(provider, itemPath);
        });
    }

    public static void StopWallpaperEngine() {
        if (!string.IsNullOrEmpty(WallpaperEngineExe) && File.Exists(WallpaperEngineExe)) {
            try {
                ProcessStartInfo psi = new ProcessStartInfo {
                    FileName = WallpaperEngineExe,
                    Arguments = "-control stop",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                Process.Start(psi);
            } catch {}
        }
    }

    public static void StartWallpaperEngine() {
        if (!string.IsNullOrEmpty(WallpaperEngineExe) && File.Exists(WallpaperEngineExe)) {
            try {
                ProcessStartInfo psi = new ProcessStartInfo {
                    FileName = WallpaperEngineExe,
                    Arguments = "-control play",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                Process.Start(psi);
            } catch {}
        }
    }

    public static void SaveStateDirect(string provider, string currentWp) {
        try {
            JavaScriptSerializer js = new JavaScriptSerializer();
            Dictionary<string, object> state = new Dictionary<string, object>();
            if (File.Exists(StateFile)) {
                try {
                    string json = File.ReadAllText(StateFile);
                    state = js.Deserialize<Dictionary<string, object>>(json) ?? new Dictionary<string, object>();
                } catch {}
            }

            state["activeProvider"] = provider;
            state["currentWallpaper"] = currentWp;
            if (provider.Equals("Static", StringComparison.OrdinalIgnoreCase)) {
                state["staticWallpaper"] = currentWp;
            } else if (provider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
                state["wallpaperEngineWallpaper"] = currentWp;
            }
            state["lastSwitched"] = DateTime.UtcNow.ToString("o");

            if (!state.ContainsKey("rotation") || !(state["rotation"] is Dictionary<string, object>)) {
                state["rotation"] = new Dictionary<string, object>();
            }
            var rot = (Dictionary<string, object>)state["rotation"];
            rot["lastRotated"] = DateTime.UtcNow.ToString("o");

            File.WriteAllText(StateFile, js.Serialize(state));
        } catch {}

        try {
            if (File.Exists(ConfigFile)) {
                JavaScriptSerializer js = new JavaScriptSerializer();
                string json = File.ReadAllText(ConfigFile);
                var config = js.Deserialize<Dictionary<string, object>>(json);
                if (config != null) {
                    config["provider"] = provider;
                    File.WriteAllText(ConfigFile, js.Serialize(config));
                }
            }
        } catch {}
    }
}

// =============================================================================
// WINDOW 1: Fullscreen Borderless Acrylic 3D Cover Flow Window
// =============================================================================
public class WallpaperCoverFlowWindow : Window {
    private string _activeProvider = "Static";
    private string _activeCollection = "Default";
    private string _currentWallpaper = "";
    private List<WallpaperItem> _items = new List<WallpaperItem>();
    private int _selectedIndex = 0;

    // Fullscreen Root Overlay & Ambient 3x Blur
    private Image _bgBlurredImage;
    private Border _rootOverlay;

    // Cover Flow Cards & Stage
    private Grid _stage;
    private Border _cardLeft;
    private Border _cardCenter;
    private Border _cardRight;
    private Image _imgLeft;
    private Image _imgCenter;
    private Image _imgRight;

    // HUD Text & Badges
    private TextBlock _txtTitle;
    private TextBlock _badgeProvider;
    private TextBlock _badgeType;
    private TextBlock _badgeIndex;
    private Border _badgeActive;
    private Border _toastBorder;
    private TextBlock _toastText;
    private StackPanel _providerPillsPanel;
    private StackPanel _colPillsPanel;

    // Display Mode Controls
    private Button _btnModeGrid;
    private Button _btnModeCoverFlow;

    private bool _isClosing = false;

    public WallpaperCoverFlowWindow(string provider = null, string collection = null, string initialWp = null) {
        LoadConfigAndState(provider, collection, initialWp);
        SetupWindow();
        BuildUI();
        LoadCollectionItems();
    }

    private void LoadConfigAndState(string provider, string collection, string initialWp) {
        JavaScriptSerializer js = new JavaScriptSerializer();
        string cfgProvider = "Static";
        string stateProvider = "";
        string stateWp = "";

        if (File.Exists(WallpaperManagerCore.ConfigFile)) {
            try {
                string json = File.ReadAllText(WallpaperManagerCore.ConfigFile);
                var cfg = js.Deserialize<Dictionary<string, object>>(json);
                if (cfg != null && cfg.ContainsKey("provider") && cfg["provider"] != null) {
                    cfgProvider = cfg["provider"].ToString();
                }
            } catch {}
        }

        if (File.Exists(WallpaperManagerCore.StateFile)) {
            try {
                string json = File.ReadAllText(WallpaperManagerCore.StateFile);
                var state = js.Deserialize<Dictionary<string, object>>(json);
                if (state != null) {
                    if (state.ContainsKey("activeProvider") && state["activeProvider"] != null) {
                        stateProvider = state["activeProvider"].ToString();
                    }
                    if (state.ContainsKey("currentWallpaper") && state["currentWallpaper"] != null) {
                        stateWp = state["currentWallpaper"].ToString();
                    }
                }
            } catch {}
        }

        bool hasWE = !string.IsNullOrEmpty(WallpaperManagerCore.WallpaperEngineExe) && File.Exists(WallpaperManagerCore.WallpaperEngineExe);
        if (!string.IsNullOrEmpty(provider)) {
            _activeProvider = provider;
        } else if (!string.IsNullOrEmpty(stateProvider)) {
            _activeProvider = stateProvider;
        } else if (hasWE) {
            _activeProvider = "WallpaperEngine";
        } else {
            _activeProvider = cfgProvider;
        }

        if (!string.IsNullOrEmpty(initialWp)) {
            _currentWallpaper = initialWp;
        } else {
            _currentWallpaper = stateWp;
        }

        if (!string.IsNullOrEmpty(collection)) {
            _activeCollection = collection;
        } else if (_activeProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            if (!string.IsNullOrEmpty(WallpaperManagerCore.SteamWorkshopDir) && Directory.Exists(WallpaperManagerCore.SteamWorkshopDir)) {
                _activeCollection = "Workshop Subscriptions";
            } else {
                _activeCollection = "Default Projects";
            }
        } else {
            _activeCollection = "Default";
        }
    }

    private void SetupWindow() {
        this.Title = "6e5tz Wallpaper Cover Flow";
        this.WindowStyle = WindowStyle.None;
        this.AllowsTransparency = true;
        this.Background = Brushes.Transparent;
        this.Topmost = true;
        this.ShowInTaskbar = false;
        this.FontFamily = WallpaperManagerCore.AppFont;

        Rect monBounds = WallpaperManagerCore.GetActiveMonitorBounds();
        this.Left = monBounds.Left;
        this.Top = monBounds.Top;
        this.Width = monBounds.Width;
        this.Height = monBounds.Height;
        this.Opacity = 0.0;

        this.Loaded += (s, e) => {
            IntPtr hwnd = new WindowInteropHelper(this).Handle;
            Rect activeMon = WallpaperManagerCore.GetActiveMonitorBounds();
            WallpaperManagerCore.SetWindowPos(hwnd, WallpaperManagerCore.HWND_TOPMOST, (int)activeMon.Left, (int)activeMon.Top, (int)activeMon.Width, (int)activeMon.Height, WallpaperManagerCore.SWP_SHOWWINDOW);

            if (WallpaperManagerCore.CoverFlowBackgroundBlur) {
                WallpaperManagerCore.EnableAcrylic(this, unchecked((int)0xD811111B));
            }

            DoubleAnimation fadeIn = new DoubleAnimation {
                From = 0.0,
                To = 1.0,
                Duration = TimeSpan.FromMilliseconds(180),
                DecelerationRatio = 0.9
            };
            this.BeginAnimation(Window.OpacityProperty, fadeIn);
            this.Activate();
            this.Focus();
        };

        this.KeyDown += (s, e) => {
            if (e.Key == Key.Escape) {
                CloseCleanly();
            } else if (e.Key == Key.Left || e.Key == Key.A || e.Key == Key.H) {
                Navigate(-1);
            } else if (e.Key == Key.Right || e.Key == Key.D || e.Key == Key.L) {
                Navigate(1);
            } else if (e.Key == Key.Enter || e.Key == Key.Space) {
                ApplyCurrent();
            } else if (e.Key == Key.F) {
                ToggleFavorite();
            }
        };
    }

    private void CloseCleanly(Action onClosed = null) {
        if (_isClosing) return;
        _isClosing = true;

        DoubleAnimation fadeOut = new DoubleAnimation {
            To = 0.0,
            Duration = TimeSpan.FromMilliseconds(140),
            AccelerationRatio = 0.9
        };
        fadeOut.Completed += (s, e) => {
            try { this.Close(); } catch {}
            if (onClosed != null) onClosed();
            WallpaperAppEntryPoint.CheckAndShutdown(this);
        };
        this.BeginAnimation(Window.OpacityProperty, fadeOut);
    }

    private void SwitchToGridPanel() {
        if (_isClosing) return;
        _isClosing = true;

        WallpaperSidePanel sideWin = new WallpaperSidePanel("", _activeProvider);
        if (Application.Current != null) {
            Application.Current.MainWindow = sideWin;
        }
        sideWin.Closed += (s, e) => {
            WallpaperAppEntryPoint.CheckAndShutdown(sideWin);
        };
        sideWin.Show();

        DoubleAnimation fadeOut = new DoubleAnimation {
            To = 0.0,
            Duration = TimeSpan.FromMilliseconds(140),
            AccelerationRatio = 0.9
        };
        fadeOut.Completed += (s, e) => {
            try { this.Close(); } catch {}
        };
        this.BeginAnimation(Window.OpacityProperty, fadeOut);
    }

    private void BuildUI() {
        Grid rootContainer = new Grid {
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch,
            ClipToBounds = true
        };

        // ---------------------------------------------------------------------
        // Deep Ambient Blurred Backdrop (3x Stronger Gaussian Blur on Desktop)
        // ---------------------------------------------------------------------
        _bgBlurredImage = new Image {
            Stretch = Stretch.UniformToFill,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Opacity = 0.45,
            IsHitTestVisible = false,
            RenderTransform = new ScaleTransform(1.15, 1.15),
            RenderTransformOrigin = new Point(0.5, 0.5),
            Effect = new BlurEffect {
                Radius = 90, // 3x deeper blur (90px Gaussian blur)
                KernelType = KernelType.Gaussian,
                RenderingBias = RenderingBias.Quality
            }
        };
        rootContainer.Children.Add(_bgBlurredImage);

        // ---------------------------------------------------------------------
        // Translucent Scrim Overlay with Top Clearance for Desktop Status Bar
        // ---------------------------------------------------------------------
        double scrimOpacity = WallpaperManagerCore.CoverFlowDarkOverlayOpacity;
        byte scrimAlpha = (byte)(255 * scrimOpacity);
        LinearGradientBrush scrimBrush = new LinearGradientBrush();
        scrimBrush.StartPoint = new Point(0.5, 0);
        scrimBrush.EndPoint = new Point(0.5, 1);
        scrimBrush.GradientStops.Add(new GradientStop(Color.FromArgb((byte)(255 * scrimOpacity), 0x11, 0x11, 0x1b), 0.0));
        scrimBrush.GradientStops.Add(new GradientStop(Color.FromArgb((byte)Math.Min(255, scrimAlpha + 20), 0x11, 0x11, 0x1b), 0.5));
        scrimBrush.GradientStops.Add(new GradientStop(Color.FromArgb((byte)Math.Min(255, scrimAlpha + 40), 0x0c, 0x0c, 0x14), 1.0));

        _rootOverlay = new Border {
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch,
            Background = scrimBrush,
            Padding = new Thickness(48, 62, 48, 28) // 62px top clearance pushes UI cleanly below YASB bar!
        };
        rootContainer.Children.Add(_rootOverlay);

        Grid grid = new Grid();
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 0: Top Header & Pills
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 1: Toast Banner
        grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // 2: 3D Cover Flow Stage
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 3: HUD Title & Badges
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 4: Action Toolbar
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 5: Keyboard Hints Footer

        // ---------------------------------------------------------------------
        // Row 0: Top Header Bar (Title, Provider/Collection Pills, Mode Switcher, Close)
        // ---------------------------------------------------------------------
        Grid topBar = new Grid { Margin = new Thickness(0, 4, 0, 22) };
        topBar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        topBar.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        topBar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        // Left: Branding
        StackPanel brandPanel = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        Border brandDot = new Border {
            Width = 11,
            Height = 11,
            CornerRadius = new CornerRadius(5.5),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 12, 0)
        };
        TextBlock brandTitle = new TextBlock {
            Text = "6e5tz Cover Flow",
            FontFamily = WallpaperManagerCore.AppHeadingFont,
            FontSize = 17,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
            VerticalAlignment = VerticalAlignment.Center
        };
        brandPanel.Children.Add(brandDot);
        brandPanel.Children.Add(brandTitle);
        Grid.SetColumn(brandPanel, 0);
        topBar.Children.Add(brandPanel);

        // Center: Provider & Collection Pills
        StackPanel centerPills = new StackPanel {
            Orientation = Orientation.Vertical,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        _providerPillsPanel = new StackPanel {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 8)
        };
        _colPillsPanel = new StackPanel {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center
        };
        centerPills.Children.Add(_providerPillsPanel);
        centerPills.Children.Add(_colPillsPanel);
        Grid.SetColumn(centerPills, 1);
        topBar.Children.Add(centerPills);

        // Right: Display Mode Segmented Control + Side Panel Button + Close Button
        StackPanel rightStack = new StackPanel {
            Orientation = Orientation.Horizontal,
            VerticalAlignment = VerticalAlignment.Center
        };

        // Display Mode Segmented Control
        Border modeBox = new Border {
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.6),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(3),
            Margin = new Thickness(0, 0, 14, 0)
        };
        StackPanel modePills = new StackPanel { Orientation = Orientation.Horizontal };
        _btnModeGrid = CreateSegmentButton("Grid Mode", isSelected: WallpaperManagerCore.LaunchMode.Equals("grid", StringComparison.OrdinalIgnoreCase));
        _btnModeCoverFlow = CreateSegmentButton("Cover Flow", isSelected: WallpaperManagerCore.LaunchMode.Equals("coverFlow", StringComparison.OrdinalIgnoreCase));

        _btnModeGrid.Click += (s, e) => {
            WallpaperManagerCore.SaveLaunchMode("grid");
            UpdateModeSegmentButtons();
            SwitchToGridPanel();
        };
        _btnModeCoverFlow.Click += (s, e) => {
            WallpaperManagerCore.SaveLaunchMode("coverFlow");
            UpdateModeSegmentButtons();
            ShowToast("Opening mode set to: Cover Flow");
        };

        modePills.Children.Add(_btnModeGrid);
        modePills.Children.Add(_btnModeCoverFlow);
        modeBox.Child = modePills;
        rightStack.Children.Add(modeBox);

        // Close Button
        Button btnClose = new Button {
            Width = 28,
            Height = 28,
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.7),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand,
            ToolTip = "Close Cover Flow (Esc)"
        };
        btnClose.Content = WallpaperManagerCore.CreateVectorIcon(WallpaperManagerCore.IconClosePath, WallpaperManagerCore.ColorSubtext, 12);
        btnClose.Template = CreatePillTemplate(10);
        btnClose.Click += (s, e) => CloseCleanly();
        rightStack.Children.Add(btnClose);

        Grid.SetColumn(rightStack, 2);
        topBar.Children.Add(rightStack);
        Grid.SetRow(topBar, 0);
        grid.Children.Add(topBar);

        // ---------------------------------------------------------------------
        // Row 1: Toast Banner
        // ---------------------------------------------------------------------
        _toastBorder = new Border {
            CornerRadius = new CornerRadius(8),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.85),
            BorderBrush = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(16, 6, 16, 6),
            Margin = new Thickness(0, 0, 0, 10),
            HorizontalAlignment = HorizontalAlignment.Center,
            Visibility = Visibility.Collapsed
        };
        _toastText = new TextBlock {
            Text = "",
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen)
        };
        _toastBorder.Child = _toastText;
        Grid.SetRow(_toastBorder, 1);
        grid.Children.Add(_toastBorder);

        // ---------------------------------------------------------------------
        // Row 2: Responsive 3D Cover Flow Stage
        // ---------------------------------------------------------------------
        Rect mon = WallpaperManagerCore.GetActiveMonitorBounds();
        double stageHeight = Math.Min(480, Math.Max(320, mon.Height * 0.44));
        double centerW = Math.Min(640, Math.Max(420, mon.Width * 0.36));
        double centerH = Math.Min(380, Math.Max(250, centerW * 0.58));
        double sideW = Math.Min(500, Math.Max(340, centerW * 0.80));
        double sideH = Math.Min(300, Math.Max(200, sideW * 0.58));
        double sideTranslate = Math.Min(340, Math.Max(220, centerW * 0.56));

        _stage = new Grid {
            Height = stageHeight,
            Margin = new Thickness(0, 12, 0, 18),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            ClipToBounds = false
        };

        // Left Card
        _cardLeft = CreateStageCard(out _imgLeft, sideW, sideH, isCenter: false);
        _cardLeft.Cursor = Cursors.Hand;
        _cardLeft.MouseLeftButtonUp += (s, e) => Navigate(-1);
        TransformGroup leftTg = new TransformGroup();
        leftTg.Children.Add(new ScaleTransform(0.82, 0.82, sideW / 2, sideH / 2));
        leftTg.Children.Add(new SkewTransform(0, 10, sideW / 2, sideH / 2));
        leftTg.Children.Add(new TranslateTransform(-sideTranslate, 0));
        _cardLeft.RenderTransform = leftTg;
        _cardLeft.Opacity = 0.55;
        Panel.SetZIndex(_cardLeft, 10);

        // Right Card
        _cardRight = CreateStageCard(out _imgRight, sideW, sideH, isCenter: false);
        _cardRight.Cursor = Cursors.Hand;
        _cardRight.MouseLeftButtonUp += (s, e) => Navigate(1);
        TransformGroup rightTg = new TransformGroup();
        rightTg.Children.Add(new ScaleTransform(0.82, 0.82, sideW / 2, sideH / 2));
        rightTg.Children.Add(new SkewTransform(0, -10, sideW / 2, sideH / 2));
        rightTg.Children.Add(new TranslateTransform(sideTranslate, 0));
        _cardRight.RenderTransform = rightTg;
        _cardRight.Opacity = 0.55;
        Panel.SetZIndex(_cardRight, 10);

        // Center Card (Primary Focal Point)
        _cardCenter = CreateStageCard(out _imgCenter, centerW, centerH, isCenter: true);
        _cardCenter.Cursor = Cursors.Hand;
        _cardCenter.MouseLeftButtonUp += (s, e) => ApplyCurrent();
        Panel.SetZIndex(_cardCenter, 30);

        _stage.Children.Add(_cardLeft);
        _stage.Children.Add(_cardRight);
        _stage.Children.Add(_cardCenter);

        _stage.MouseWheel += (s, e) => {
            if (e.Delta < 0) Navigate(1);
            else if (e.Delta > 0) Navigate(-1);
        };

        Grid.SetRow(_stage, 2);
        grid.Children.Add(_stage);

        // ---------------------------------------------------------------------
        // Row 3: HUD Title & Badges
        // ---------------------------------------------------------------------
        StackPanel hud = new StackPanel {
            Orientation = Orientation.Vertical,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 12, 0, 14)
        };

        _txtTitle = new TextBlock {
            Text = "Loading wallpapers...",
            FontFamily = WallpaperManagerCore.AppHeadingFont,
            FontSize = 24,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
            HorizontalAlignment = HorizontalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
            MaxWidth = 800,
            Margin = new Thickness(0, 0, 0, 12)
        };
        hud.Children.Add(_txtTitle);

        StackPanel badges = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 0, 0, 6) };
        badges.Children.Add(CreateBadgePill("Static", out _badgeProvider, WallpaperManagerCore.ColorBlue));
        badges.Children.Add(CreateBadgePill("Scene", out _badgeType, WallpaperManagerCore.ColorPeach));
        badges.Children.Add(CreateBadgePill("1 / 1", out _badgeIndex, WallpaperManagerCore.ColorSubtext));

        _badgeActive = new Border {
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen),
            CornerRadius = new CornerRadius(14),
            Padding = new Thickness(14, 4, 14, 4),
            Margin = new Thickness(6, 0, 6, 0),
            Visibility = Visibility.Collapsed
        };
        StackPanel actStack = new StackPanel { Orientation = Orientation.Horizontal };
        actStack.Children.Add(WallpaperManagerCore.CreateVectorIcon(WallpaperManagerCore.IconCheckPath, WallpaperManagerCore.ColorCrust, 11));
        TextBlock actTxt = new TextBlock {
            Text = " Current Wallpaper",
            FontSize = 11.5,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust),
            VerticalAlignment = VerticalAlignment.Center
        };
        actStack.Children.Add(actTxt);
        _badgeActive.Child = actStack;
        badges.Children.Add(_badgeActive);

        hud.Children.Add(badges);
        Grid.SetRow(hud, 3);
        grid.Children.Add(hud);

        // ---------------------------------------------------------------------
        // Row 4: Action Toolbar
        // ---------------------------------------------------------------------
        StackPanel actionRow = new StackPanel {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 6, 0, 20)
        };

        Button btnPrev = CreateActionBtn("◀  Previous", (s, e) => Navigate(-1), 130);
        Button btnApply = CreateActionBtn("✓  Apply Wallpaper", (s, e) => ApplyCurrent(), 220, isAccent: true);
        Button btnNext = CreateActionBtn("Next  ▶", (s, e) => Navigate(1), 130);
        Button btnFav = CreateActionBtn("★  Favorite", (s, e) => ToggleFavorite(), 130);

        actionRow.Children.Add(btnPrev);
        actionRow.Children.Add(btnApply);
        actionRow.Children.Add(btnNext);
        actionRow.Children.Add(btnFav);

        Grid.SetRow(actionRow, 4);
        grid.Children.Add(actionRow);

        // ---------------------------------------------------------------------
        // Row 5: Keyboard Hints Footer (Spaced Out & Relaxed)
        // ---------------------------------------------------------------------
        TextBlock footer = new TextBlock {
            Text = "◀ / ▶ or Scroll to browse    •    Enter to apply    •    F for Favorite    •    Esc to close",
            FontSize = 11.5,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext, 0.75),
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 2, 0, 8)
        };
        Grid.SetRow(footer, 5);
        grid.Children.Add(footer);

        _rootOverlay.Child = grid;
        this.Content = rootContainer;
    }

    private Button CreateSegmentButton(string text, bool isSelected) {
        Button btn = new Button {
            Content = text,
            Height = 32,
            Padding = new Thickness(27, 0, 27, 0),
            FontSize = 11.5,
            FontWeight = isSelected ? FontWeights.Bold : FontWeights.SemiBold,
            Foreground = isSelected ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
            Background = isSelected ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : Brushes.Transparent,
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        btn.Template = CreatePillTemplate(10);
        return btn;
    }

    private void UpdateModeSegmentButtons() {
        bool isCover = WallpaperManagerCore.LaunchMode.Equals("coverFlow", StringComparison.OrdinalIgnoreCase);
        _btnModeCoverFlow.Background = isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : Brushes.Transparent;
        _btnModeCoverFlow.Foreground = isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext);
        _btnModeCoverFlow.FontWeight = isCover ? FontWeights.Bold : FontWeights.Normal;

        _btnModeGrid.Background = !isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : Brushes.Transparent;
        _btnModeGrid.Foreground = !isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext);
        _btnModeGrid.FontWeight = !isCover ? FontWeights.Bold : FontWeights.Normal;
    }

    private ControlTemplate CreatePillTemplate(double cornerRadius) {
        ControlTemplate t = new ControlTemplate(typeof(Button));
        FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
        b.SetValue(Border.CornerRadiusProperty, new CornerRadius(cornerRadius));
        b.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
        b.SetValue(Border.BorderBrushProperty, new TemplateBindingExtension(Button.BorderBrushProperty));
        b.SetValue(Border.BorderThicknessProperty, new TemplateBindingExtension(Button.BorderThicknessProperty));
        b.SetValue(Border.PaddingProperty, new TemplateBindingExtension(Button.PaddingProperty));
        FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
        cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        b.AppendChild(cp);
        t.VisualTree = b;
        return t;
    }

    private Border CreateStageCard(out Image img, double width, double height, bool isCenter) {
        Border card = new Border {
            Width = width,
            Height = height,
            CornerRadius = new CornerRadius(14),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust),
            BorderBrush = isCenter ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface1),
            BorderThickness = new Thickness(isCenter ? 2.5 : 1),
            ClipToBounds = true,
            Effect = isCenter ? new DropShadowEffect {
                BlurRadius = 36,
                ShadowDepth = 6,
                Color = WallpaperManagerCore.ColorMauve,
                Opacity = 0.40
            } : null
        };

        Grid g = new Grid();
        img = new Image {
            Stretch = Stretch.UniformToFill,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        g.Children.Add(img);
        card.Child = g;
        return card;
    }

    private Border CreateBadgePill(string text, out TextBlock tb, Color fgColor) {
        Border b = new Border {
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
            CornerRadius = new CornerRadius(14),
            Padding = new Thickness(14, 4, 14, 4),
            Margin = new Thickness(6, 0, 6, 0)
        };
        tb = new TextBlock {
            Text = text,
            FontSize = 11.5,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(fgColor)
        };
        b.Child = tb;
        return b;
    }

    private Button CreateActionBtn(string text, RoutedEventHandler handler, double width, bool isAccent = false) {
        Button btn = new Button {
            Content = text,
            Width = width,
            Height = 38,
            Margin = new Thickness(6, 0, 6, 0),
            FontSize = 12.5,
            FontWeight = isAccent ? FontWeights.Bold : FontWeights.SemiBold,
            Foreground = isAccent ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
            Background = isAccent ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        btn.Template = CreatePillTemplate(10);
        btn.Click += handler;
        return btn;
    }

    private void LoadCollectionItems() {
        RenderProviderPills();
        RenderCollectionPills();
        _items = WallpaperManagerCore.GetWallpapers(_activeProvider, _activeCollection);

        _selectedIndex = 0;
        if (!string.IsNullOrEmpty(_currentWallpaper) && _items.Count > 0) {
            for (int i = 0; i < _items.Count; i++) {
                if (_items[i].ItemPath.Equals(_currentWallpaper, StringComparison.OrdinalIgnoreCase)) {
                    _selectedIndex = i;
                    break;
                }
            }
        }

        UpdateStage();
    }

    private void RenderProviderPills() {
        _providerPillsPanel.Children.Clear();
        string[] providers = new string[] { "Static", "WallpaperEngine", "Lively" };
        string[] labels = new string[] { "Static", "Wallpaper Engine", "Lively" };

        bool hasWE = !string.IsNullOrEmpty(WallpaperManagerCore.WallpaperEngineExe) && File.Exists(WallpaperManagerCore.WallpaperEngineExe);
        bool hasLively = false;

        for (int i = 0; i < providers.Length; i++) {
            string p = providers[i];
            string lbl = labels[i];
            bool isAvailable = (p == "Static") || (p == "WallpaperEngine" && hasWE) || (p == "Lively" && hasLively);
            bool isActive = _activeProvider.Equals(p, StringComparison.OrdinalIgnoreCase);

            Button btn = new Button {
                Content = lbl,
                Height = 28,
                Margin = new Thickness(0, 0, 8, 0),
                Padding = new Thickness(27, 0, 27, 0),
                FontSize = 11,
                FontWeight = isActive ? FontWeights.Bold : FontWeights.Normal,
                Foreground = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : (isAvailable ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay)),
                Background = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorBlue) : (isAvailable ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMantle, 0.4)),
                BorderThickness = new Thickness(0),
                IsEnabled = isAvailable,
                Cursor = isAvailable ? Cursors.Hand : Cursors.No
            };
            btn.Template = CreatePillTemplate(10);

            if (isAvailable) {
                string targetP = p;
                btn.Click += (s, e) => {
                    if (_activeProvider.Equals(targetP, StringComparison.OrdinalIgnoreCase)) return;
                    _activeProvider = targetP;
                    _activeCollection = (targetP == "WallpaperEngine") ? "Default Projects" : "Default";
                    LoadCollectionItems();
                    ShowToast("Switched to " + lbl);
                };
            }
            _providerPillsPanel.Children.Add(btn);
        }
    }

    private void RenderCollectionPills() {
        _colPillsPanel.Children.Clear();
        List<string> collections = new List<string>();

        if (_activeProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            collections.Add("Default Projects");
            if (!string.IsNullOrEmpty(WallpaperManagerCore.SteamWorkshopDir) && Directory.Exists(WallpaperManagerCore.SteamWorkshopDir)) {
                collections.Add("Workshop Subscriptions");
            }
        } else {
            collections.Add("Default");
            string root = Path.Combine(WallpaperManagerCore.UserProfile, @"Pictures\Wallpapers");
            if (Directory.Exists(root)) {
                try {
                    foreach (string dir in Directory.GetDirectories(root)) {
                        string name = Path.GetFileName(dir);
                        if (!name.StartsWith(".") && !collections.Contains(name)) collections.Add(name);
                    }
                } catch {}
            }
        }

        if (!collections.Contains(_activeCollection)) _activeCollection = collections[0];

        foreach (string col in collections) {
            bool isActive = _activeCollection.Equals(col, StringComparison.OrdinalIgnoreCase);
            Button btn = new Button {
                Content = col,
                Height = 32,
                Margin = new Thickness(0, 0, 8, 0),
                Padding = new Thickness(27, 0, 27, 0),
                FontSize = 11.5,
                FontWeight = isActive ? FontWeights.Bold : FontWeights.SemiBold,
                Foreground = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
                Background = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
                BorderThickness = new Thickness(0),
                Cursor = Cursors.Hand
            };
            btn.Template = CreatePillTemplate(10);

            string colTarget = col;
            btn.Click += (s, e) => {
                _activeCollection = colTarget;
                LoadCollectionItems();
            };
            _colPillsPanel.Children.Add(btn);
        }
    }

    private void Navigate(int direction) {
        if (_items.Count == 0) return;
        _selectedIndex = (_selectedIndex + direction + _items.Count) % _items.Count;
        UpdateStage();
    }

    private void UpdateStage() {
        if (_items.Count == 0) {
            _txtTitle.Text = "No wallpapers found in this collection";
            _imgCenter.Source = null;
            _imgLeft.Source = null;
            _imgRight.Source = null;
            if (_bgBlurredImage != null) _bgBlurredImage.Source = null;
            _badgeIndex.Text = "0 / 0";
            _badgeActive.Visibility = Visibility.Collapsed;
            return;
        }

        WallpaperItem cur = _items[_selectedIndex];
        _txtTitle.Text = cur.Title;
        _txtTitle.ToolTip = cur.Title;
        _badgeProvider.Text = cur.Provider;
        _badgeType.Text = cur.Type;
        _badgeIndex.Text = string.Format("{0} / {1}", _selectedIndex + 1, _items.Count);

        bool isCurrent = !string.IsNullOrEmpty(_currentWallpaper) &&
            (_currentWallpaper.Equals(cur.ItemPath, StringComparison.OrdinalIgnoreCase) ||
             _currentWallpaper.Equals(Path.GetDirectoryName(cur.ItemPath), StringComparison.OrdinalIgnoreCase));
        _badgeActive.Visibility = isCurrent ? Visibility.Visible : Visibility.Collapsed;

        // Load Center Image
        WallpaperManagerCore.LoadThumbnailAsync(cur.PreviewPath, _imgCenter, 720);

        // Load Background Ambient Blurred Image (3x stronger Gaussian blur behind cards)
        if (_bgBlurredImage != null) {
            WallpaperManagerCore.LoadThumbnailAsync(cur.PreviewPath, _bgBlurredImage, 640);
        }

        // Load Left Image
        if (_items.Count > 1) {
            int leftIdx = (_selectedIndex - 1 + _items.Count) % _items.Count;
            WallpaperManagerCore.LoadThumbnailAsync(_items[leftIdx].PreviewPath, _imgLeft, 360);
            _cardLeft.Visibility = Visibility.Visible;
        } else {
            _imgLeft.Source = null;
            _cardLeft.Visibility = Visibility.Hidden;
        }

        // Load Right Image
        if (_items.Count > 1) {
            int rightIdx = (_selectedIndex + 1) % _items.Count;
            WallpaperManagerCore.LoadThumbnailAsync(_items[rightIdx].PreviewPath, _imgRight, 360);
            _cardRight.Visibility = Visibility.Visible;
        } else {
            _imgRight.Source = null;
            _cardRight.Visibility = Visibility.Hidden;
        }
    }

    private void ApplyCurrent() {
        if (_items.Count == 0 || _selectedIndex < 0 || _selectedIndex >= _items.Count) return;
        WallpaperItem cur = _items[_selectedIndex];

        WallpaperManagerCore.ApplyWallpaperDirect(cur.Provider, cur.ItemPath);
        _currentWallpaper = cur.ItemPath;

        ShowToast("Applied: " + cur.Title);
        UpdateStage();
    }

    private void ToggleFavorite() {
        if (_items.Count == 0 || _selectedIndex < 0 || _selectedIndex >= _items.Count) return;
        WallpaperItem cur = _items[_selectedIndex];
        ShowToast("Favorited: " + cur.Title);
    }

    private void ShowToast(string message) {
        _toastText.Text = "✓ " + message;
        _toastBorder.Visibility = Visibility.Visible;
    }
}

// =============================================================================
// WINDOW 2: Floating Acrylic Edge Slide-In Side Panel Window
// =============================================================================
public class WallpaperSidePanel : Window {
    private string _activeProvider = "WallpaperEngine";
    private string _activeCollection = "Workshop Subscriptions";
    private string _currentWallpaper = "";
    private string _initialNotice = "";
    private double _panelWidth = 440;
    private string _uiPosition = "right";

    // UI Controls
    private Border _rootBorder;
    private StackPanel _providersPanel;
    private StackPanel _collectionsPanel;
    private ScrollViewer _gridScroll;
    private UniformGrid _gridUniformPanel;
    private TextBlock _gridHeader;
    private List<Border> _thumbnailCards = new List<Border>();
    private List<WallpaperItem> _currentItems = new List<WallpaperItem>();
    private Border _toastBorder;
    private TextBlock _toastText;

    // Display Mode Controls
    private Button _btnModeGrid;
    private Button _btnModeCoverFlow;
    private TextBlock _txtModeDesc;

    private bool _isClosing = false;
    private DateTime _loadTime = DateTime.Now;
    private double _targetLeft = 0;
    private double _offscreenLeft = 0;

    public WallpaperSidePanel(string notice, string preferredProvider) {
        _initialNotice = notice;
        LoadConfigAndState();
        if (!string.IsNullOrEmpty(preferredProvider)) {
            _activeProvider = preferredProvider;
        }

        if (_activeProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            if (!string.IsNullOrEmpty(WallpaperManagerCore.SteamWorkshopDir) && Directory.Exists(WallpaperManagerCore.SteamWorkshopDir)) {
                _activeCollection = "Workshop Subscriptions";
            } else {
                _activeCollection = "Default Projects";
            }
        } else {
            _activeCollection = "Default";
        }

        SetupWindow();
        BuildUI();

        if (!string.IsNullOrEmpty(_initialNotice)) {
            ShowToast(_initialNotice);
        }
    }

    private void LoadConfigAndState() {
        JavaScriptSerializer js = new JavaScriptSerializer();
        if (File.Exists(WallpaperManagerCore.ConfigFile)) {
            try {
                string json = File.ReadAllText(WallpaperManagerCore.ConfigFile);
                var cfg = js.Deserialize<Dictionary<string, object>>(json);
                if (cfg != null) {
                    if (cfg.ContainsKey("provider") && cfg["provider"] != null) _activeProvider = cfg["provider"].ToString();
                    if (cfg.ContainsKey("ui") && cfg["ui"] is Dictionary<string, object>) {
                        var ui = (Dictionary<string, object>)cfg["ui"];
                        if (ui.ContainsKey("position") && ui["position"] != null) _uiPosition = ui["position"].ToString();
                        if (ui.ContainsKey("width") && ui["width"] != null) double.TryParse(ui["width"].ToString(), out _panelWidth);
                    }
                }
            } catch {}
        }

        if (File.Exists(WallpaperManagerCore.StateFile)) {
            try {
                string json = File.ReadAllText(WallpaperManagerCore.StateFile);
                var state = js.Deserialize<Dictionary<string, object>>(json);
                if (state != null) {
                    if (state.ContainsKey("activeProvider") && state["activeProvider"] != null) _activeProvider = state["activeProvider"].ToString();
                    if (state.ContainsKey("currentWallpaper") && state["currentWallpaper"] != null) _currentWallpaper = state["currentWallpaper"].ToString();
                }
            } catch {}
        }
    }

    private void SetupWindow() {
        this.Title = "6e5tz Wallpaper Side Panel";
        this.WindowStyle = WindowStyle.None;
        this.AllowsTransparency = true;
        this.Background = Brushes.Transparent;
        this.Topmost = true;
        this.ShowInTaskbar = false;
        this.FontFamily = WallpaperManagerCore.AppFont;

        Rect workArea = SystemParameters.WorkArea;
        double panelHeight = Math.Max(540, workArea.Height - 32);
        double topPos = workArea.Top + 16;

        if (_panelWidth < 440) _panelWidth = 440;
        this.Width = _panelWidth;
        this.Height = panelHeight;
        this.Top = topPos;

        if (_uiPosition.Equals("left", StringComparison.OrdinalIgnoreCase)) {
            _targetLeft = workArea.Left + 16;
            _offscreenLeft = workArea.Left - _panelWidth - 30;
        } else {
            _targetLeft = workArea.Right - _panelWidth - 16;
            _offscreenLeft = workArea.Right + 30;
        }

        this.Left = _offscreenLeft;
        this.Opacity = 0.0;

        this.Loaded += (s, e) => {
            _loadTime = DateTime.Now;
            WallpaperManagerCore.EnableAcrylic(this);

            DoubleAnimation slideAnim = new DoubleAnimation {
                From = _offscreenLeft,
                To = _targetLeft,
                Duration = TimeSpan.FromMilliseconds(220),
                DecelerationRatio = 0.85
            };
            DoubleAnimation fadeAnim = new DoubleAnimation {
                From = 0.0,
                To = 1.0,
                Duration = TimeSpan.FromMilliseconds(200)
            };
            this.BeginAnimation(Window.LeftProperty, slideAnim);
            this.BeginAnimation(Window.OpacityProperty, fadeAnim);
            this.Activate();
            this.Focus();
        };

        this.Deactivated += (s, e) => {
            if (_isClosing) return;
            if ((DateTime.Now - _loadTime).TotalMilliseconds > 300) {
                SlideOutAndClose();
            }
        };

        this.KeyDown += (s, e) => {
            if (e.Key == Key.Escape) {
                SlideOutAndClose();
            }
        };
    }

    private void SlideOutAndClose(Action onClosed = null) {
        if (_isClosing) return;
        _isClosing = true;

        DoubleAnimation slideOut = new DoubleAnimation {
            To = _offscreenLeft,
            Duration = TimeSpan.FromMilliseconds(160),
            AccelerationRatio = 0.85
        };
        DoubleAnimation fadeOut = new DoubleAnimation {
            To = 0.0,
            Duration = TimeSpan.FromMilliseconds(150)
        };
        slideOut.Completed += (s, e) => {
            try { this.Close(); } catch {}
            if (onClosed != null) onClosed();
            WallpaperAppEntryPoint.CheckAndShutdown(this);
        };

        this.BeginAnimation(Window.LeftProperty, slideOut);
        this.BeginAnimation(Window.OpacityProperty, fadeOut);
    }

    private void BuildUI() {
        _rootBorder = new Border {
            CornerRadius = new CornerRadius(18),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMantle, 0.94),
            BorderBrush = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
            BorderThickness = new Thickness(1.2),
            Effect = new DropShadowEffect {
                BlurRadius = 36,
                ShadowDepth = 6,
                Opacity = 0.5,
                Color = Colors.Black,
                Direction = 270
            },
            Padding = new Thickness(20, 18, 20, 18)
        };

        Grid mainGrid = new Grid();
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 0: Header
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 1: Toast
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 2: Provider Selector Card
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 3: Collections Selector Card
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 4: Display Mode Settings Card
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // 5: Wallpapers Area
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 6: Bottom Toolbar

        // ---------------------------------------------------------------------
        // Row 0: Header (More breathing room)
        // ---------------------------------------------------------------------
        Grid headerGrid = new Grid { Margin = new Thickness(0, 0, 0, 16) };
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        StackPanel titleStack = new StackPanel { Orientation = Orientation.Vertical };
        StackPanel titleRow = new StackPanel { Orientation = Orientation.Horizontal };
        Border dot = new Border {
            Width = 10,
            Height = 10,
            CornerRadius = new CornerRadius(5),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 10, 0)
        };
        TextBlock titleText = new TextBlock {
            Text = "6e5tz Wallpaper Manager",
            FontFamily = WallpaperManagerCore.AppHeadingFont,
            FontSize = 16,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText)
        };
        titleRow.Children.Add(dot);
        titleRow.Children.Add(titleText);

        TextBlock subtitleText = new TextBlock {
            Text = "Universal Rice • Adaptive Grid & Fullscreen Cover Flow",
            FontSize = 11,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
            Margin = new Thickness(20, 4, 0, 0)
        };
        titleStack.Children.Add(titleRow);
        titleStack.Children.Add(subtitleText);

        Button closeBtn = new Button {
            Width = 28,
            Height = 28,
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.6),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand,
            ToolTip = "Close (Esc)"
        };
        closeBtn.Content = WallpaperManagerCore.CreateVectorIcon(WallpaperManagerCore.IconClosePath, WallpaperManagerCore.ColorSubtext, 11);
        closeBtn.Template = CreatePillTemplate(10);
        closeBtn.Click += (s, e) => SlideOutAndClose();

        Grid.SetColumn(titleStack, 0);
        Grid.SetColumn(closeBtn, 1);
        headerGrid.Children.Add(titleStack);
        headerGrid.Children.Add(closeBtn);
        Grid.SetRow(headerGrid, 0);
        mainGrid.Children.Add(headerGrid);

        // ---------------------------------------------------------------------
        // Row 1: Toast
        // ---------------------------------------------------------------------
        _toastBorder = new Border {
            CornerRadius = new CornerRadius(8),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.75),
            BorderBrush = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(14, 6, 14, 6),
            Margin = new Thickness(0, 0, 0, 12),
            Visibility = Visibility.Collapsed
        };
        _toastText = new TextBlock {
            Text = "",
            FontSize = 11.5,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen),
            VerticalAlignment = VerticalAlignment.Center
        };
        _toastBorder.Child = _toastText;
        Grid.SetRow(_toastBorder, 1);
        mainGrid.Children.Add(_toastBorder);

        // ---------------------------------------------------------------------
        // Row 2: Provider Selector Card (Cohesive Card Design)
        // ---------------------------------------------------------------------
        Border providerCard = BuildProviderCard();
        Grid.SetRow(providerCard, 2);
        mainGrid.Children.Add(providerCard);

        // ---------------------------------------------------------------------
        // Row 3: Collections Selector Card (Cohesive Card Design)
        // ---------------------------------------------------------------------
        Border collectionCard = BuildCollectionCard();
        Grid.SetRow(collectionCard, 3);
        mainGrid.Children.Add(collectionCard);

        // ---------------------------------------------------------------------
        // Row 4: DISPLAY MODE Settings Card
        // ---------------------------------------------------------------------
        Border displayModeCard = BuildDisplayModeCard();
        Grid.SetRow(displayModeCard, 4);
        mainGrid.Children.Add(displayModeCard);

        // ---------------------------------------------------------------------
        // Row 5: Adaptive 2-Column Grid (UniformGrid Symmetrical Layout)
        // ---------------------------------------------------------------------
        Grid gridHeaderRow = new Grid { Margin = new Thickness(2, 4, 2, 8) };
        gridHeaderRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        gridHeaderRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        _gridHeader = new TextBlock {
            Text = "WALLPAPERS",
            FontSize = 10,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay),
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(_gridHeader, 0);
        gridHeaderRow.Children.Add(_gridHeader);

        _gridScroll = new ScrollViewer {
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
            Margin = new Thickness(0, 0, 0, 14),
            Focusable = false
        };
        ScrollViewer.SetCanContentScroll(_gridScroll, false);
        _gridScroll.PreviewMouseWheel += (s, e) => {
            _gridScroll.ScrollToVerticalOffset(_gridScroll.VerticalOffset - (e.Delta * 0.75));
            e.Handled = true;
        };

        _gridUniformPanel = new UniformGrid {
            Columns = 2,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Top
        };
        _gridScroll.Content = _gridUniformPanel;

        _gridScroll.SizeChanged += (s, e) => {
            UpdateGridCardWidths();
        };

        Grid gridContainer = new Grid();
        gridContainer.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        gridContainer.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        Grid.SetRow(gridHeaderRow, 0);
        Grid.SetRow(_gridScroll, 1);
        gridContainer.Children.Add(gridHeaderRow);
        gridContainer.Children.Add(_gridScroll);

        Grid.SetRow(gridContainer, 5);
        mainGrid.Children.Add(gridContainer);

        // ---------------------------------------------------------------------
        // Row 6: Bottom Toolbar
        // ---------------------------------------------------------------------
        Border footerBorder = new Border {
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust, 0.65),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(6),
            Margin = new Thickness(0, 8, 0, 0)
        };
        UniformGrid footerGrid = new UniformGrid { Columns = 4 };
        footerGrid.Children.Add(CreateVectorFooterButton("Previous", WallpaperManagerCore.IconPrevPath, (s, e) => FastPrevWallpaper()));
        footerGrid.Children.Add(CreateVectorFooterButton("Next", WallpaperManagerCore.IconNextPath, (s, e) => FastNextWallpaper()));
        footerGrid.Children.Add(CreateVectorFooterButton("Shuffle", WallpaperManagerCore.IconShufflePath, (s, e) => FastShuffleWallpaper()));
        footerGrid.Children.Add(CreateVectorFooterButton("Folder", WallpaperManagerCore.IconFolderPath, (s, e) => OpenCollectionFolder()));
        footerBorder.Child = footerGrid;
        Grid.SetRow(footerBorder, 6);
        mainGrid.Children.Add(footerBorder);

        _rootBorder.Child = mainGrid;
        this.Content = _rootBorder;

        // Initial Data Load
        RenderProviders();
        RenderCollections();
        LoadGridWallpapers();
    }

    private Border BuildProviderCard() {
        Border card = new Border {
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.40),
            BorderBrush = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface1, 0.45),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(14, 12, 14, 12),
            Margin = new Thickness(0, 0, 0, 10)
        };

        StackPanel sp = new StackPanel();
        TextBlock label = new TextBlock {
            Text = "WALLPAPER PROVIDER",
            FontSize = 10,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay),
            Margin = new Thickness(2, 0, 0, 8)
        };
        _providersPanel = new StackPanel { Orientation = Orientation.Horizontal };
        sp.Children.Add(label);
        sp.Children.Add(_providersPanel);
        card.Child = sp;
        return card;
    }

    private Border BuildCollectionCard() {
        Border card = new Border {
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.40),
            BorderBrush = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface1, 0.45),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(14, 12, 14, 12),
            Margin = new Thickness(0, 0, 0, 10)
        };

        StackPanel sp = new StackPanel();
        TextBlock label = new TextBlock {
            Text = "COLLECTIONS / PLAYLISTS",
            FontSize = 10,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay),
            Margin = new Thickness(2, 0, 0, 8)
        };
        ScrollViewer colScroll = new ScrollViewer {
            HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled
        };
        _collectionsPanel = new StackPanel { Orientation = Orientation.Horizontal };
        colScroll.Content = _collectionsPanel;
        sp.Children.Add(label);
        sp.Children.Add(colScroll);
        card.Child = sp;
        return card;
    }

    private Border BuildDisplayModeCard() {
        Border card = new Border {
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.40),
            BorderBrush = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface1, 0.45),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(14, 12, 14, 12),
            Margin = new Thickness(0, 0, 0, 12)
        };

        Grid g = new Grid();
        g.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        g.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        g.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        // Row 0: Section Title (No extra single button!)
        TextBlock title = new TextBlock {
            Text = "DISPLAY MODE",
            FontSize = 10,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay),
            Margin = new Thickness(2, 0, 0, 8)
        };
        Grid.SetRow(title, 0);
        g.Children.Add(title);

        // Row 1: Segmented Control
        Border segBox = new Border {
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.6),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(3),
            Margin = new Thickness(0, 0, 0, 8)
        };
        UniformGrid segGrid = new UniformGrid { Columns = 2 };

        bool isCover = WallpaperManagerCore.LaunchMode.Equals("coverFlow", StringComparison.OrdinalIgnoreCase);

        _btnModeGrid = new Button {
            Content = "Grid Mode",
            Height = 28,
            FontSize = 11,
            FontWeight = !isCover ? FontWeights.Bold : FontWeights.Normal,
            Foreground = !isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
            Background = !isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorBlue) : Brushes.Transparent,
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        _btnModeGrid.Template = CreatePillTemplate(10);
        _btnModeGrid.Click += (s, e) => {
            WallpaperManagerCore.SaveLaunchMode("grid");
            UpdateSidePanelModeButtons();
        };

        _btnModeCoverFlow = new Button {
            Content = "Cover Flow",
            Height = 28,
            FontSize = 11,
            FontWeight = isCover ? FontWeights.Bold : FontWeights.Normal,
            Foreground = isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
            Background = isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : Brushes.Transparent,
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        _btnModeCoverFlow.Template = CreatePillTemplate(10);
        _btnModeCoverFlow.Click += (s, e) => {
            WallpaperManagerCore.SaveLaunchMode("coverFlow");
            UpdateSidePanelModeButtons();
            LaunchStandaloneCoverFlow();
        };

        segGrid.Children.Add(_btnModeGrid);
        segGrid.Children.Add(_btnModeCoverFlow);
        segBox.Child = segGrid;
        Grid.SetRow(segBox, 1);
        g.Children.Add(segBox);

        // Row 2: Description Text
        _txtModeDesc = new TextBlock {
            Text = isCover ? "Cover Flow: Open the fullscreen 3D wallpaper experience on Alt+Shift+G." : "Grid Mode: Open the floating wallpaper gallery on Alt+Shift+G.",
            FontSize = 10.5,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(2, 4, 2, 2)
        };
        Grid.SetRow(_txtModeDesc, 2);
        g.Children.Add(_txtModeDesc);

        card.Child = g;
        return card;
    }

    private void UpdateSidePanelModeButtons() {
        bool isCover = WallpaperManagerCore.LaunchMode.Equals("coverFlow", StringComparison.OrdinalIgnoreCase);

        _btnModeGrid.Background = !isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorBlue) : Brushes.Transparent;
        _btnModeGrid.Foreground = !isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext);
        _btnModeGrid.FontWeight = !isCover ? FontWeights.Bold : FontWeights.Normal;

        _btnModeCoverFlow.Background = isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : Brushes.Transparent;
        _btnModeCoverFlow.Foreground = isCover ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext);
        _btnModeCoverFlow.FontWeight = isCover ? FontWeights.Bold : FontWeights.Normal;

        _txtModeDesc.Text = isCover ? "Cover Flow: Open the fullscreen 3D wallpaper experience on Alt+Shift+G." : "Grid Mode: Open the floating wallpaper gallery on Alt+Shift+G.";
    }

    private void LaunchStandaloneCoverFlow() {
        if (_isClosing) return;
        _isClosing = true;

        // If closing for standalone Cover Flow

        WallpaperCoverFlowWindow cfWin = new WallpaperCoverFlowWindow(_activeProvider, _activeCollection, _currentWallpaper);
        if (Application.Current != null) {
            Application.Current.MainWindow = cfWin;
        }
        cfWin.Closed += (s, e) => {
            WallpaperAppEntryPoint.CheckAndShutdown(cfWin);
        };
        cfWin.Show();

        DoubleAnimation slideOut = new DoubleAnimation {
            To = _offscreenLeft,
            Duration = TimeSpan.FromMilliseconds(160),
            AccelerationRatio = 0.85
        };
        DoubleAnimation fadeOut = new DoubleAnimation {
            To = 0.0,
            Duration = TimeSpan.FromMilliseconds(150)
        };
        slideOut.Completed += (s, e) => {
            try { this.Close(); } catch {}
        };

        this.BeginAnimation(Window.LeftProperty, slideOut);
        this.BeginAnimation(Window.OpacityProperty, fadeOut);
    }

    private void LoadGridWallpapers() {
        _currentItems = WallpaperManagerCore.GetWallpapers(_activeProvider, _activeCollection);
        _gridHeader.Text = string.Format("WALLPAPERS ({0})", _currentItems.Count);

        _gridUniformPanel.Children.Clear();
        _thumbnailCards.Clear();

        double availWidth = _gridScroll.ViewportWidth;
        if (availWidth <= 0) availWidth = _gridScroll.ActualWidth - 20;
        if (availWidth <= 0) availWidth = _panelWidth - 32;

        int cols = (availWidth >= 520) ? 3 : 2;
        _gridUniformPanel.Columns = cols;

        double spacing = 8.0;
        double colWidth = (availWidth - (cols * spacing)) / cols;
        double cardHeight = Math.Max(96, Math.Floor(colWidth * 0.62));

        foreach (WallpaperItem item in _currentItems) {
            WallpaperItem curItem = item;
            bool isCurrent = !string.IsNullOrEmpty(_currentWallpaper) &&
                (_currentWallpaper.Equals(curItem.ItemPath, StringComparison.OrdinalIgnoreCase) ||
                 _currentWallpaper.Equals(Path.GetDirectoryName(curItem.ItemPath), StringComparison.OrdinalIgnoreCase));

            Border card = new Border {
                HorizontalAlignment = HorizontalAlignment.Stretch,
                Height = cardHeight,
                Margin = new Thickness(4),
                CornerRadius = new CornerRadius(10),
                Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust),
                BorderBrush = isCurrent ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorBlue) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
                BorderThickness = new Thickness(isCurrent ? 2.5 : 1),
                ClipToBounds = true,
                Cursor = Cursors.Hand,
                ToolTip = string.Format("{0} ({1})", curItem.Title, curItem.Type),
                Tag = curItem
            };

            Grid cardGrid = new Grid();

            Image img = new Image {
                Stretch = Stretch.UniformToFill,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            cardGrid.Children.Add(img);

            // Overlay label
            Border labelOverlay = new Border {
                VerticalAlignment = VerticalAlignment.Bottom,
                Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust, 0.78),
                Padding = new Thickness(8, 6, 8, 6)
            };
            TextBlock lbl = new TextBlock {
                Text = curItem.Title,
                FontSize = 10.5,
                FontWeight = FontWeights.SemiBold,
                Foreground = isCurrent ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorBlue) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            labelOverlay.Child = lbl;
            cardGrid.Children.Add(labelOverlay);

            // Active Badge
            if (isCurrent) {
                Border badge = new Border {
                    HorizontalAlignment = HorizontalAlignment.Right,
                    VerticalAlignment = VerticalAlignment.Top,
                    Margin = new Thickness(0, 6, 6, 0),
                    Width = 20,
                    Height = 20,
                    CornerRadius = new CornerRadius(10),
                    Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorBlue)
                };
                badge.Child = WallpaperManagerCore.CreateVectorIcon(WallpaperManagerCore.IconCheckPath, WallpaperManagerCore.ColorCrust, 11);
                cardGrid.Children.Add(badge);
            }

            card.Child = cardGrid;
            card.MouseLeftButtonUp += (s, e) => ApplyGridWallpaper(curItem);

            _thumbnailCards.Add(card);
            _gridUniformPanel.Children.Add(card);

            WallpaperManagerCore.LoadThumbnailAsync(curItem.PreviewPath, img, 240);
        }
    }

    private void UpdateGridCardWidths() {
        double availWidth = _gridScroll.ViewportWidth;
        if (availWidth <= 0) availWidth = _gridScroll.ActualWidth - 20;
        if (availWidth <= 0) return;

        int cols = (availWidth >= 520) ? 3 : 2;
        _gridUniformPanel.Columns = cols;

        double spacing = 8.0;
        double colWidth = (availWidth - (cols * spacing)) / cols;
        double cardHeight = Math.Max(96, Math.Floor(colWidth * 0.62));

        foreach (Border card in _thumbnailCards) {
            card.Height = cardHeight;
        }
    }

    private void ApplyGridWallpaper(WallpaperItem item) {
        WallpaperManagerCore.ApplyWallpaperDirect(item.Provider, item.ItemPath);
        _currentWallpaper = item.ItemPath;

        ShowToast("Applied: " + item.Title);
        LoadGridWallpapers();
    }

    private void FastNextWallpaper() {
        if (_currentItems.Count == 0) return;
        int idx = 0;
        for (int i = 0; i < _currentItems.Count; i++) {
            if (_currentItems[i].ItemPath.Equals(_currentWallpaper, StringComparison.OrdinalIgnoreCase)) {
                idx = (i + 1) % _currentItems.Count;
                break;
            }
        }
        ApplyGridWallpaper(_currentItems[idx]);
    }

    private void FastPrevWallpaper() {
        if (_currentItems.Count == 0) return;
        int idx = 0;
        for (int i = 0; i < _currentItems.Count; i++) {
            if (_currentItems[i].ItemPath.Equals(_currentWallpaper, StringComparison.OrdinalIgnoreCase)) {
                idx = (i - 1 + _currentItems.Count) % _currentItems.Count;
                break;
            }
        }
        ApplyGridWallpaper(_currentItems[idx]);
    }

    private void FastShuffleWallpaper() {
        if (_currentItems.Count <= 1) return;
        Random rng = new Random();
        int nextIdx = rng.Next(_currentItems.Count);
        ApplyGridWallpaper(_currentItems[nextIdx]);
    }

    private void RenderProviders() {
        _providersPanel.Children.Clear();
        string[] providers = new string[] { "Static", "WallpaperEngine", "Lively" };
        string[] labels = new string[] { "Static", "Wallpaper Engine", "Lively" };

        bool hasWE = !string.IsNullOrEmpty(WallpaperManagerCore.WallpaperEngineExe) && File.Exists(WallpaperManagerCore.WallpaperEngineExe);
        bool hasLively = false;

        for (int i = 0; i < providers.Length; i++) {
            string p = providers[i];
            string lbl = labels[i];
            bool isAvailable = (p == "Static") || (p == "WallpaperEngine" && hasWE) || (p == "Lively" && hasLively);
            bool isActive = _activeProvider.Equals(p, StringComparison.OrdinalIgnoreCase);

            Button btn = new Button {
                Content = lbl,
                Height = 36,
                Margin = new Thickness(0, 0, 10, 0),
                Padding = new Thickness(27, 0, 27, 0),
                FontSize = 12.5,
                FontWeight = isActive ? FontWeights.Bold : FontWeights.SemiBold,
                Foreground = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : (isAvailable ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay)),
                Background = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorBlue) : (isAvailable ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMantle, 0.4)),
                BorderThickness = new Thickness(isActive ? 0 : 1),
                BorderBrush = isActive ? null : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface1),
                IsEnabled = isAvailable,
                Cursor = isAvailable ? Cursors.Hand : Cursors.No
            };
            btn.Template = CreatePillTemplate(10);

            if (isAvailable) {
                string targetP = p;
                btn.Click += (s, e) => SwitchProvider(targetP);
            }

            _providersPanel.Children.Add(btn);
        }
    }

    private void SwitchProvider(string newProvider) {
        if (_activeProvider.Equals(newProvider, StringComparison.OrdinalIgnoreCase)) return;

        if (newProvider.Equals("Static", StringComparison.OrdinalIgnoreCase)) {
            WallpaperManagerCore.StopWallpaperEngine();
            _activeProvider = "Static";
            _activeCollection = "Default";
            WallpaperManagerCore.ApplyWallpaperDirect("Static", _currentWallpaper);
            ShowToast("Switched to Static Wallpaper");
        } else if (newProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            WallpaperManagerCore.StartWallpaperEngine();
            _activeProvider = "WallpaperEngine";
            _activeCollection = "Default Projects";
            ShowToast("Switched to Wallpaper Engine");
        }

        RenderProviders();
        RenderCollections();
        LoadGridWallpapers();
    }

    private void RenderCollections() {
        _collectionsPanel.Children.Clear();
        List<string> collections = new List<string>();

        if (_activeProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            collections.Add("Default Projects");
            if (!string.IsNullOrEmpty(WallpaperManagerCore.SteamWorkshopDir) && Directory.Exists(WallpaperManagerCore.SteamWorkshopDir)) {
                collections.Add("Workshop Subscriptions");
            }
        } else {
            collections.Add("Default");
            string root = Path.Combine(WallpaperManagerCore.UserProfile, @"Pictures\Wallpapers");
            if (Directory.Exists(root)) {
                try {
                    foreach (string dir in Directory.GetDirectories(root)) {
                        string name = Path.GetFileName(dir);
                        if (!name.StartsWith(".") && !collections.Contains(name)) collections.Add(name);
                    }
                } catch {}
            }
        }

        if (!collections.Contains(_activeCollection)) _activeCollection = collections[0];

        foreach (string col in collections) {
            bool isActive = _activeCollection.Equals(col, StringComparison.OrdinalIgnoreCase);
            Button btn = new Button {
                Content = col,
                Height = 32,
                Margin = new Thickness(0, 0, 8, 0),
                Padding = new Thickness(27, 0, 27, 0),
                FontSize = 11.5,
                FontWeight = isActive ? FontWeights.Bold : FontWeights.SemiBold,
                Foreground = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
                Background = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
                BorderThickness = new Thickness(0),
                Cursor = Cursors.Hand
            };
            btn.Template = CreatePillTemplate(10);

            string colTarget = col;
            btn.Click += (s, e) => {
                _activeCollection = colTarget;
                RenderCollections();
                LoadGridWallpapers();
            };
            _collectionsPanel.Children.Add(btn);
        }
    }

    private void OpenCollectionFolder() {
        string target = "";
        if (_activeProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            if (_activeCollection.Equals("Workshop Subscriptions", StringComparison.OrdinalIgnoreCase) && Directory.Exists(WallpaperManagerCore.SteamWorkshopDir)) {
                target = WallpaperManagerCore.SteamWorkshopDir;
            } else if (!string.IsNullOrEmpty(WallpaperManagerCore.DefaultProjectsDir) && Directory.Exists(WallpaperManagerCore.DefaultProjectsDir)) {
                target = WallpaperManagerCore.DefaultProjectsDir;
            }
        } else {
            string root = Path.Combine(WallpaperManagerCore.UserProfile, @"Pictures\Wallpapers");
            target = root;
            if (!_activeCollection.Equals("Default", StringComparison.OrdinalIgnoreCase)) {
                string sub = Path.Combine(root, _activeCollection);
                if (Directory.Exists(sub)) target = sub;
            }
        }

        if (!string.IsNullOrEmpty(target) && Directory.Exists(target)) {
            try { Process.Start("explorer.exe", target); } catch {}
        }
    }

    private void ShowToast(string message) {
        _toastText.Text = "✓ " + message;
        _toastBorder.Visibility = Visibility.Visible;
    }

    private ControlTemplate CreatePillTemplate(double cornerRadius) {
        ControlTemplate t = new ControlTemplate(typeof(Button));
        FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
        b.SetValue(Border.CornerRadiusProperty, new CornerRadius(cornerRadius));
        b.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
        b.SetValue(Border.BorderBrushProperty, new TemplateBindingExtension(Button.BorderBrushProperty));
        b.SetValue(Border.BorderThicknessProperty, new TemplateBindingExtension(Button.BorderThicknessProperty));
        b.SetValue(Border.PaddingProperty, new TemplateBindingExtension(Button.PaddingProperty));
        FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
        cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        b.AppendChild(cp);
        t.VisualTree = b;
        return t;
    }

    private Button CreateVectorFooterButton(string text, string vectorPath, RoutedEventHandler handler) {
        Button btn = new Button {
            Height = 34,
            Margin = new Thickness(4, 0, 4, 0),
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand,
            ToolTip = text
        };
        StackPanel p = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center };
        p.Children.Add(WallpaperManagerCore.CreateVectorIcon(vectorPath, WallpaperManagerCore.ColorSubtext, 12));
        TextBlock t = new TextBlock {
            Text = " " + text,
            FontSize = 11,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
            VerticalAlignment = VerticalAlignment.Center
        };
        p.Children.Add(t);
        btn.Content = p;
        btn.Template = CreatePillTemplate(8);
        btn.Click += handler;
        return btn;
    }
}

// =============================================================================
// APPLICATION ENTRY POINT: Reliable Single-Press Alt+Shift+G Architecture
// =============================================================================
public static class WallpaperAppEntryPoint {
    public static void CheckAndShutdown(Window closingWindow) {
        if (Application.Current == null) return;
        bool hasVisible = false;
        foreach (Window w in Application.Current.Windows) {
            if (w != closingWindow && w.IsVisible) {
                hasVisible = true;
                break;
            }
        }
        if (!hasVisible) {
            Application.Current.Shutdown();
        }
    }

    [STAThread]
    public static void Main(string[] args) {
        string notice = "";
        string provider = "";
        bool? forcedCoverFlow = null;

        for (int i = 0; i < args.Length; i++) {
            if (args[i].Equals("-Notice", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) {
                notice = args[++i];
            } else if (args[i].Equals("-Provider", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) {
                provider = args[++i];
            } else if (args[i].Equals("-CoverFlow", StringComparison.OrdinalIgnoreCase)) {
                forcedCoverFlow = true;
            } else if (args[i].Equals("-Grid", StringComparison.OrdinalIgnoreCase)) {
                forcedCoverFlow = false;
            }
        }

        WallpaperManagerCore.LoadGlobalConfig();

        bool targetCoverFlow = forcedCoverFlow.HasValue ?
            forcedCoverFlow.Value :
            WallpaperManagerCore.LaunchMode.Equals("coverFlow", StringComparison.OrdinalIgnoreCase);

        IntPtr hSide = WallpaperManagerCore.FindWindow(null, "6e5tz Wallpaper Side Panel");
        IntPtr hCover = WallpaperManagerCore.FindWindow(null, "6e5tz Wallpaper Cover Flow");

        bool sideVisible = (hSide != IntPtr.Zero && WallpaperManagerCore.IsWindowVisible(hSide));
        bool coverVisible = (hCover != IntPtr.Zero && WallpaperManagerCore.IsWindowVisible(hCover));

        WallpaperManagerCore.LogDiagnostic("SHORTCUT", string.Format("Invoked. Target: {0}, SideVis: {1}, CoverVis: {2}, Forced: {3}",
            (targetCoverFlow ? "CoverFlow" : "Grid"), sideVisible, coverVisible, (forcedCoverFlow.HasValue ? forcedCoverFlow.Value.ToString() : "none")));

        // Single-press toggle & mode transition handling
        if (targetCoverFlow) {
            if (coverVisible) {
                // Cover Flow is already open and visible -> toggle close cleanly!
                WallpaperManagerCore.LogDiagnostic("SHORTCUT", "Toggle closing visible Cover Flow window.");
                WallpaperManagerCore.PostMessage(hCover, WallpaperManagerCore.WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                return;
            }
            if (sideVisible) {
                // Side Panel was open, user switched or requested Cover Flow -> close Side Panel and transition!
                WallpaperManagerCore.LogDiagnostic("SHORTCUT", "Transitioning: closing Side Panel to open Cover Flow.");
                WallpaperManagerCore.PostMessage(hSide, WallpaperManagerCore.WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
            }
        } else {
            if (sideVisible) {
                // Side Panel is already open and visible -> toggle close cleanly!
                WallpaperManagerCore.LogDiagnostic("SHORTCUT", "Toggle closing visible Side Panel window.");
                WallpaperManagerCore.PostMessage(hSide, WallpaperManagerCore.WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                return;
            }
            if (coverVisible) {
                // Cover Flow was open, user switched or requested Grid -> close Cover Flow and transition!
                WallpaperManagerCore.LogDiagnostic("SHORTCUT", "Transitioning: closing Cover Flow to open Side Panel.");
                WallpaperManagerCore.PostMessage(hCover, WallpaperManagerCore.WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
            }
        }

        // Cleanup any stale background processes with dead/invisible windows
        Process current = Process.GetCurrentProcess();
        string[] procNames = new string[] { "wallpaper-gallery", "WallpaperSidePanel" };
        foreach (string pn in procNames) {
            foreach (Process p in Process.GetProcessesByName(pn)) {
                if (p.Id != current.Id) {
                    try { p.Kill(); } catch {}
                }
            }
        }

        Application app = new Application();
        app.ShutdownMode = ShutdownMode.OnExplicitShutdown;

        if (targetCoverFlow) {
            WallpaperCoverFlowWindow cfWin = new WallpaperCoverFlowWindow(provider, "", "");
            app.MainWindow = cfWin;
            cfWin.Closed += (s, e) => {
                WallpaperManagerCore.LogDiagnostic("WINDOW", "Cover Flow window closed.");
                CheckAndShutdown(cfWin);
            };
            cfWin.Show();
            WallpaperManagerCore.LogDiagnostic("WINDOW", "Cover Flow window opened and visible.");
            app.Run();
        } else {
            WallpaperSidePanel sideWin = new WallpaperSidePanel(notice, provider);
            app.MainWindow = sideWin;
            sideWin.Closed += (s, e) => {
                WallpaperManagerCore.LogDiagnostic("WINDOW", "Side Panel window closed.");
                CheckAndShutdown(sideWin);
            };
            sideWin.Show();
            WallpaperManagerCore.LogDiagnostic("WINDOW", "Side Panel window opened and visible.");
            app.Run();
        }
    }
}
