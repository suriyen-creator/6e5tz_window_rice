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
using System.Windows.Threading;

// =============================================================================
// 6e5tz Universal Wallpaper Manager - High Performance Desktop Core
// Standalone 3D Cover Flow + Adaptive 2-Column Grid + Zero-Console Execution
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
    // Active Monitor WorkArea Resolution (Win32)
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

    // -------------------------------------------------------------------------
    // Catppuccin Mocha Color Palette
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

    public static SolidColorBrush BrushOf(Color c, double opacity = 1.0) {
        SolidColorBrush b = new SolidColorBrush(c);
        b.Opacity = opacity;
        b.Freeze();
        return b;
    }

    // -------------------------------------------------------------------------
    // Shared Paths & Global Cache
    // -------------------------------------------------------------------------
    public static string UserProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    public static string ConfigDir = Path.Combine(UserProfile, @".config\6e5tz");
    public static string ConfigFile = Path.Combine(ConfigDir, "wallpaper-manager.json");
    public static string StateFile = Path.Combine(ConfigDir, "wallpaper-state.json");
    public static string WallpaperEngineExe = FindWallpaperEngineExe();
    public static string SteamWorkshopDir = FindSteamWorkshopDir();
    public static string DefaultProjectsDir = FindDefaultProjectsDir();

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
// WINDOW 1: Standalone Centered 3D Cover Flow Window
// =============================================================================
public class WallpaperCoverFlowWindow : Window {
    private string _activeProvider = "Static";
    private string _activeCollection = "Default";
    private string _currentWallpaper = "";
    private List<WallpaperItem> _items = new List<WallpaperItem>();
    private int _selectedIndex = 0;

    // Cover Flow Cards
    private Border _cardLeft;
    private Border _cardCenter;
    private Border _cardRight;
    private Image _imgLeft;
    private Image _imgCenter;
    private Image _imgRight;

    // HUD Text
    private TextBlock _txtTitle;
    private TextBlock _badgeProvider;
    private TextBlock _badgeType;
    private TextBlock _badgeIndex;
    private Border _badgeActive;
    private Border _toastBorder;
    private TextBlock _toastText;
    private StackPanel _providerPillsPanel;
    private StackPanel _colPillsPanel;

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

        if (!string.IsNullOrEmpty(provider)) {
            _activeProvider = provider;
        } else if (!string.IsNullOrEmpty(stateProvider)) {
            _activeProvider = stateProvider;
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
        } else {
            _activeCollection = (_activeProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) ? "Default Projects" : "Default";
        }
    }

    private void SetupWindow() {
        this.Title = "6e5tz Cover Flow";
        this.WindowStyle = WindowStyle.None;
        this.AllowsTransparency = true;
        this.Background = Brushes.Transparent;
        this.Topmost = true;
        this.ShowInTaskbar = false;

        Rect workArea = WallpaperManagerCore.GetActiveMonitorWorkArea();
        this.Width = Math.Min(1020, workArea.Width - 60);
        this.Height = Math.Min(600, workArea.Height - 60);
        this.Left = workArea.Left + (workArea.Width - this.Width) / 2;
        this.Top = workArea.Top + (workArea.Height - this.Height) / 2;

        this.Opacity = 0.0;

        this.Loaded += (s, e) => {
            Rect activeWork = WallpaperManagerCore.GetActiveMonitorWorkArea();
            this.Left = activeWork.Left + (activeWork.Width - this.Width) / 2;
            this.Top = activeWork.Top + (activeWork.Height - this.Height) / 2;

            WallpaperManagerCore.EnableAcrylic(this);

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

    private void CloseCleanly() {
        if (_isClosing) return;
        _isClosing = true;

        DoubleAnimation fadeOut = new DoubleAnimation {
            To = 0.0,
            Duration = TimeSpan.FromMilliseconds(130),
            AccelerationRatio = 0.9
        };
        fadeOut.Completed += (s, e) => {
            this.Close();
            if (Application.Current != null && Application.Current.MainWindow == this) {
                Application.Current.Shutdown();
            }
        };
        this.BeginAnimation(Window.OpacityProperty, fadeOut);
    }

    private void BuildUI() {
        Border root = new Border {
            CornerRadius = new CornerRadius(18),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMantle, 0.94),
            BorderBrush = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
            BorderThickness = new Thickness(1.5),
            Effect = new DropShadowEffect {
                BlurRadius = 40,
                ShadowDepth = 8,
                Color = Colors.Black,
                Opacity = 0.65
            },
            Padding = new Thickness(24, 16, 24, 16)
        };

        Grid grid = new Grid();
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 0: Header & Providers
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 1: Collection Pills
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 2: Toast
        grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // 3: 3D Stage
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 4: HUD Title & Badges
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 5: Action Toolbar
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 6: Footer Prompt

        // ---------------------------------------------------------------------
        // Row 0: Header Row (Title, Providers, Close)
        // ---------------------------------------------------------------------
        Grid headerGrid = new Grid { Margin = new Thickness(0, 0, 0, 6) };
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        StackPanel titleStack = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        Border dot = new Border {
            Width = 10,
            Height = 10,
            CornerRadius = new CornerRadius(5),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 10, 0)
        };
        TextBlock titleTxt = new TextBlock {
            Text = "6e5tz COVER FLOW",
            FontSize = 15,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText)
        };
        titleStack.Children.Add(dot);
        titleStack.Children.Add(titleTxt);
        Grid.SetColumn(titleStack, 0);
        headerGrid.Children.Add(titleStack);

        // Center: Provider pills
        _providerPillsPanel = new StackPanel {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(_providerPillsPanel, 1);
        headerGrid.Children.Add(_providerPillsPanel);

        // Right: Close Button
        Button btnClose = new Button {
            Content = "✕",
            Width = 32,
            Height = 32,
            FontSize = 13,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.7),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        ControlTemplate ct = new ControlTemplate(typeof(Button));
        FrameworkElementFactory cb = new FrameworkElementFactory(typeof(Border));
        cb.SetValue(Border.CornerRadiusProperty, new CornerRadius(16));
        cb.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
        FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
        cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        cb.AppendChild(cp);
        ct.VisualTree = cb;
        btnClose.Template = ct;
        btnClose.Click += (s, e) => CloseCleanly();
        Grid.SetColumn(btnClose, 2);
        headerGrid.Children.Add(btnClose);

        Grid.SetRow(headerGrid, 0);
        grid.Children.Add(headerGrid);

        // ---------------------------------------------------------------------
        // Row 1: Collections Row
        // ---------------------------------------------------------------------
        ScrollViewer colScroll = new ScrollViewer {
            HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled,
            Margin = new Thickness(0, 0, 0, 6),
            HorizontalAlignment = HorizontalAlignment.Center
        };
        _colPillsPanel = new StackPanel { Orientation = Orientation.Horizontal };
        colScroll.Content = _colPillsPanel;
        Grid.SetRow(colScroll, 1);
        grid.Children.Add(colScroll);

        // ---------------------------------------------------------------------
        // Row 2: Toast Banner
        // ---------------------------------------------------------------------
        _toastBorder = new Border {
            CornerRadius = new CornerRadius(8),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.7),
            BorderBrush = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(12, 5, 12, 5),
            Margin = new Thickness(0, 0, 0, 6),
            HorizontalAlignment = HorizontalAlignment.Center,
            Visibility = Visibility.Collapsed
        };
        _toastText = new TextBlock {
            Text = "",
            FontSize = 11,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen)
        };
        _toastBorder.Child = _toastText;
        Grid.SetRow(_toastBorder, 2);
        grid.Children.Add(_toastBorder);

        // ---------------------------------------------------------------------
        // Row 2: 3D Cover Flow Stage
        // ---------------------------------------------------------------------
        Grid stage = new Grid {
            Height = 280,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            ClipToBounds = false
        };

        // Left Card
        _cardLeft = CreateStageCard(out _imgLeft, 340, 205, isCenter: false);
        _cardLeft.Cursor = Cursors.Hand;
        _cardLeft.MouseLeftButtonUp += (s, e) => Navigate(-1);
        TransformGroup leftTg = new TransformGroup();
        leftTg.Children.Add(new ScaleTransform(0.78, 0.78, 170, 102));
        leftTg.Children.Add(new SkewTransform(0, 9, 170, 102));
        leftTg.Children.Add(new TranslateTransform(-185, 0));
        _cardLeft.RenderTransform = leftTg;
        _cardLeft.Opacity = 0.52;
        Panel.SetZIndex(_cardLeft, 10);

        // Right Card
        _cardRight = CreateStageCard(out _imgRight, 340, 205, isCenter: false);
        _cardRight.Cursor = Cursors.Hand;
        _cardRight.MouseLeftButtonUp += (s, e) => Navigate(1);
        TransformGroup rightTg = new TransformGroup();
        rightTg.Children.Add(new ScaleTransform(0.78, 0.78, 170, 102));
        rightTg.Children.Add(new SkewTransform(0, -9, 170, 102));
        rightTg.Children.Add(new TranslateTransform(185, 0));
        _cardRight.RenderTransform = rightTg;
        _cardRight.Opacity = 0.52;
        Panel.SetZIndex(_cardRight, 10);

        // Center Card (Primary Focal Point)
        _cardCenter = CreateStageCard(out _imgCenter, 400, 240, isCenter: true);
        _cardCenter.Cursor = Cursors.Hand;
        _cardCenter.MouseLeftButtonUp += (s, e) => ApplyCurrent();
        Panel.SetZIndex(_cardCenter, 30);

        stage.Children.Add(_cardLeft);
        stage.Children.Add(_cardRight);
        stage.Children.Add(_cardCenter);

        stage.MouseWheel += (s, e) => {
            if (e.Delta < 0) Navigate(1);
            else if (e.Delta > 0) Navigate(-1);
        };

        Grid.SetRow(stage, 3);
        grid.Children.Add(stage);

        // ---------------------------------------------------------------------
        // Row 4: HUD Title & Badges
        // ---------------------------------------------------------------------
        StackPanel hud = new StackPanel {
            Orientation = Orientation.Vertical,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 8, 0, 6)
        };

        _txtTitle = new TextBlock {
            Text = "Loading wallpapers...",
            FontSize = 17,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
            HorizontalAlignment = HorizontalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
            MaxWidth = 600,
            Margin = new Thickness(0, 0, 0, 5)
        };
        hud.Children.Add(_txtTitle);

        StackPanel badges = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center };
        badges.Children.Add(CreateBadgePill("Static", out _badgeProvider, WallpaperManagerCore.ColorBlue));
        badges.Children.Add(CreateBadgePill("Scene", out _badgeType, WallpaperManagerCore.ColorPeach));
        badges.Children.Add(CreateBadgePill("1 / 1", out _badgeIndex, WallpaperManagerCore.ColorSubtext));

        _badgeActive = new Border {
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(10, 3, 10, 3),
            Margin = new Thickness(4, 0, 4, 0),
            Visibility = Visibility.Collapsed
        };
        TextBlock actTxt = new TextBlock {
            Text = "✓ Active Desktop",
            FontSize = 10.5,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust)
        };
        _badgeActive.Child = actTxt;
        badges.Children.Add(_badgeActive);

        hud.Children.Add(badges);
        Grid.SetRow(hud, 4);
        grid.Children.Add(hud);

        // ---------------------------------------------------------------------
        // Row 5: Action Toolbar
        // ---------------------------------------------------------------------
        StackPanel actionRow = new StackPanel {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 2, 0, 6)
        };

        Button btnPrev = CreateActionBtn("◀ Prev", (s, e) => Navigate(-1), 90);
        Button btnApply = CreateActionBtn("✓ Apply Wallpaper (Enter)", (s, e) => ApplyCurrent(), 190, isAccent: true);
        Button btnNext = CreateActionBtn("Next ▶", (s, e) => Navigate(1), 90);
        Button btnFav = CreateActionBtn("★ Favorite", (s, e) => ToggleFavorite(), 100);

        actionRow.Children.Add(btnPrev);
        actionRow.Children.Add(btnApply);
        actionRow.Children.Add(btnNext);
        actionRow.Children.Add(btnFav);

        Grid.SetRow(actionRow, 5);
        grid.Children.Add(actionRow);

        // ---------------------------------------------------------------------
        // Row 6: Footer Prompt
        // ---------------------------------------------------------------------
        TextBlock footer = new TextBlock {
            Text = "Left / Right Arrow to Preview • Enter to Apply • Esc to Close",
            FontSize = 11,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay),
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 2)
        };
        Grid.SetRow(footer, 6);
        grid.Children.Add(footer);

        root.Child = grid;
        this.Content = root;
    }

    private Border CreateStageCard(out Image img, double width, double height, bool isCenter) {
        Border card = new Border {
            Width = width,
            Height = height,
            CornerRadius = new CornerRadius(12),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust),
            BorderBrush = isCenter ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface1),
            BorderThickness = new Thickness(isCenter ? 2.5 : 1),
            ClipToBounds = true,
            Effect = isCenter ? new DropShadowEffect {
                BlurRadius = 28,
                ShadowDepth = 6,
                Color = WallpaperManagerCore.ColorMauve,
                Opacity = 0.45
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
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(10, 3, 10, 3),
            Margin = new Thickness(4, 0, 4, 0)
        };
        tb = new TextBlock {
            Text = text,
            FontSize = 10.5,
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
            Height = 32,
            Margin = new Thickness(4, 0, 4, 0),
            FontSize = 11.5,
            FontWeight = FontWeights.Bold,
            Foreground = isAccent ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
            Background = isAccent ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        ControlTemplate t = new ControlTemplate(typeof(Button));
        FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
        b.SetValue(Border.CornerRadiusProperty, new CornerRadius(16));
        b.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
        FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
        cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        b.AppendChild(cp);
        t.VisualTree = b;
        btn.Template = t;
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

        UpdateCards();
    }

    private void RenderProviderPills() {
        if (_providerPillsPanel == null) return;
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
                Height = 24,
                Margin = new Thickness(0, 0, 6, 0),
                Padding = new Thickness(10, 0, 10, 0),
                FontSize = 10,
                FontWeight = isActive ? FontWeights.Bold : FontWeights.Normal,
                Foreground = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : (isAvailable ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay)),
                Background = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorBlue) : (isAvailable ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMantle, 0.4)),
                BorderThickness = new Thickness(isActive ? 0 : 1),
                BorderBrush = isActive ? null : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface1),
                IsEnabled = isAvailable,
                Cursor = isAvailable ? Cursors.Hand : Cursors.No
            };

            ControlTemplate t = new ControlTemplate(typeof(Button));
            FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
            b.SetValue(Border.CornerRadiusProperty, new CornerRadius(12));
            b.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
            FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
            cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
            cp.SetValue(ContentPresenter.MarginProperty, new Thickness(8, 0, 8, 0));
            b.AppendChild(cp);
            t.VisualTree = b;
            btn.Template = t;

            if (isAvailable) {
                string targetP = p;
                btn.Click += (s, e) => SwitchProvider(targetP);
            }

            _providerPillsPanel.Children.Add(btn);
        }
    }

    private void SwitchProvider(string newProvider) {
        if (_activeProvider.Equals(newProvider, StringComparison.OrdinalIgnoreCase)) return;

        if (newProvider.Equals("Static", StringComparison.OrdinalIgnoreCase)) {
            WallpaperManagerCore.StopWallpaperEngine();
            _activeProvider = "Static";
            _activeCollection = "Default";
            ShowToast("Switched to Static Provider");
        } else if (newProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            WallpaperManagerCore.StartWallpaperEngine();
            _activeProvider = "WallpaperEngine";
            _activeCollection = "Default Projects";
            ShowToast("Switched to Wallpaper Engine Provider");
        }

        LoadCollectionItems();
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
                    foreach (string d in Directory.GetDirectories(root)) {
                        string name = Path.GetFileName(d);
                        if (!name.StartsWith(".") && !collections.Contains(name)) collections.Add(name);
                    }
                } catch {}
            }
        }

        foreach (string col in collections) {
            bool isSel = _activeCollection.Equals(col, StringComparison.OrdinalIgnoreCase);
            Button pill = new Button {
                Content = col,
                Height = 24,
                Margin = new Thickness(3, 0, 3, 0),
                Padding = new Thickness(10, 0, 10, 0),
                FontSize = 10.5,
                FontWeight = isSel ? FontWeights.Bold : FontWeights.Normal,
                Foreground = isSel ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
                Background = isSel ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
                BorderThickness = new Thickness(0),
                Cursor = Cursors.Hand
            };
            ControlTemplate t = new ControlTemplate(typeof(Button));
            FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
            b.SetValue(Border.CornerRadiusProperty, new CornerRadius(12));
            b.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
            FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
            cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
            b.AppendChild(cp);
            t.VisualTree = b;
            pill.Template = t;

            string targetCol = col;
            pill.Click += (s, e) => {
                _activeCollection = targetCol;
                LoadCollectionItems();
            };
            _colPillsPanel.Children.Add(pill);
        }
    }

    private void Navigate(int delta) {
        if (_items.Count == 0) return;
        _selectedIndex = (_selectedIndex + delta + _items.Count) % _items.Count;
        UpdateCards();
    }

    private void UpdateCards() {
        if (_items.Count == 0) {
            _txtTitle.Text = "No wallpapers found in collection '" + _activeCollection + "'";
            _badgeProvider.Text = _activeProvider;
            _badgeType.Text = "None";
            _badgeIndex.Text = "0 / 0";
            _badgeActive.Visibility = Visibility.Collapsed;
            _imgLeft.Source = null;
            _imgCenter.Source = null;
            _imgRight.Source = null;
            return;
        }

        int total = _items.Count;
        int centerIdx = _selectedIndex;
        int leftIdx = (centerIdx - 1 + total) % total;
        int rightIdx = (centerIdx + 1) % total;

        WallpaperItem center = _items[centerIdx];
        WallpaperItem left = _items[leftIdx];
        WallpaperItem right = _items[rightIdx];

        WallpaperManagerCore.LoadThumbnailAsync(center.PreviewPath, _imgCenter, 480);
        WallpaperManagerCore.LoadThumbnailAsync(left.PreviewPath, _imgLeft, 320);
        WallpaperManagerCore.LoadThumbnailAsync(right.PreviewPath, _imgRight, 320);

        _txtTitle.Text = center.Title;
        _badgeProvider.Text = center.Provider;
        _badgeType.Text = center.Type;
        _badgeIndex.Text = string.Format("{0} / {1}", centerIdx + 1, total);

        bool isActive = !string.IsNullOrEmpty(_currentWallpaper) &&
            (_currentWallpaper.Equals(center.ItemPath, StringComparison.OrdinalIgnoreCase) ||
             _currentWallpaper.Equals(Path.GetDirectoryName(center.ItemPath), StringComparison.OrdinalIgnoreCase));

        _badgeActive.Visibility = isActive ? Visibility.Visible : Visibility.Collapsed;
        _cardCenter.BorderBrush = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve);
    }

    private void ApplyCurrent() {
        if (_items.Count == 0 || _selectedIndex < 0 || _selectedIndex >= _items.Count) return;
        WallpaperItem item = _items[_selectedIndex];

        WallpaperManagerCore.ApplyWallpaperDirect(item.Provider, item.ItemPath);
        _currentWallpaper = item.ItemPath;

        ShowToast("Applied: " + item.Title);
        UpdateCards();
    }

    private void ToggleFavorite() {
        if (_items.Count == 0) return;
        WallpaperItem item = _items[_selectedIndex];
        ShowToast("Favorited: " + item.Title);
    }

    private void ShowToast(string message) {
        _toastText.Text = "✓ " + message;
        _toastBorder.Visibility = Visibility.Visible;
    }
}

// =============================================================================
// WINDOW 2: Floating Acrylic Side Panel (Adaptive 2-Column Grid)
// =============================================================================
public class WallpaperSidePanel : Window {
    private string _activeProvider = "Static";
    private string _activeCollection = "Default";
    private string _currentWallpaper = "";
    private string _uiPosition = "right";
    private double _panelWidth = 420;
    private string _initialNotice = "";

    // Auto-Rotation State
    private bool _rotationEnabled = false;
    private int _rotationIntervalMinutes = 30;
    private bool _rotationPauseBrowsing = true;
    private bool _rotationIsPaused = false;
    private DateTime _rotationLastRotated = DateTime.UtcNow;
    private DispatcherTimer _rotationTicker;

    // UI Elements
    private Border _rootBorder;
    private Border _toastBorder;
    private TextBlock _toastText;
    private StackPanel _providersPanel;
    private StackPanel _collectionsPanel;
    private TextBlock _gridHeader;
    private ScrollViewer _gridScroll;
    private UniformGrid _gridUniformPanel;
    private List<Border> _thumbnailCards = new List<Border>();

    private Button _btnRotationToggle;
    private TextBlock _txtRotationStatus;
    private StackPanel _rotationIntervalsPanel;
    private Button _btnRotationPauseResume;

    private List<WallpaperItem> _currentItems = new List<WallpaperItem>();
    private bool _isClosing = false;
    private DateTime _loadTime = DateTime.Now;
    private double _targetLeft = 0;
    private double _offscreenLeft = 0;

    [STAThread]
    public static void Main(string[] args) {
        string notice = "";
        string provider = "";
        bool openCoverFlow = false;

        for (int i = 0; i < args.Length; i++) {
            if (args[i].Equals("-Notice", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) {
                notice = args[++i];
            } else if (args[i].Equals("-Provider", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) {
                provider = args[++i];
            } else if (args[i].Equals("-CoverFlow", StringComparison.OrdinalIgnoreCase)) {
                openCoverFlow = true;
            }
        }

        // Single-instance management
        Process current = Process.GetCurrentProcess();
        Process[] running = Process.GetProcessesByName(current.ProcessName);
        bool hasOtherInstance = false;
        foreach (Process p in running) {
            if (p.Id != current.Id) {
                hasOtherInstance = true;
                try { p.Kill(); } catch {}
            }
        }

        if (hasOtherInstance && string.IsNullOrEmpty(notice) && !openCoverFlow) {
            return;
        }

        Application app = new Application();
        app.ShutdownMode = ShutdownMode.OnExplicitShutdown;

        if (openCoverFlow) {
            WallpaperCoverFlowWindow cfWin = new WallpaperCoverFlowWindow(provider, "", "");
            app.MainWindow = cfWin;
            cfWin.Closed += (s, e) => {
                if (Application.Current != null) Application.Current.Shutdown();
            };
            cfWin.Show();
            app.Run();
        } else {
            WallpaperSidePanel sideWin = new WallpaperSidePanel(notice, provider);
            app.MainWindow = sideWin;
            sideWin.Show();
            app.Run();
        }
    }

    public WallpaperSidePanel(string notice, string preferredProvider) {
        _initialNotice = notice;
        if (!string.IsNullOrEmpty(preferredProvider)) _activeProvider = preferredProvider;

        LoadConfigAndState();
        if (!string.IsNullOrEmpty(preferredProvider)) _activeProvider = preferredProvider;

        SetupWindow();
        BuildUI();
        InitializeRotationTicker();

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
                    if (cfg.ContainsKey("rotation") && cfg["rotation"] is Dictionary<string, object>) {
                        var rot = (Dictionary<string, object>)cfg["rotation"];
                        if (rot.ContainsKey("enabled") && rot["enabled"] != null) bool.TryParse(rot["enabled"].ToString(), out _rotationEnabled);
                        if (rot.ContainsKey("intervalMinutes") && rot["intervalMinutes"] != null) int.TryParse(rot["intervalMinutes"].ToString(), out _rotationIntervalMinutes);
                        if (rot.ContainsKey("pauseWhileBrowsing") && rot["pauseWhileBrowsing"] != null) bool.TryParse(rot["pauseWhileBrowsing"].ToString(), out _rotationPauseBrowsing);
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
                    if (state.ContainsKey("rotation") && state["rotation"] is Dictionary<string, object>) {
                        var rs = (Dictionary<string, object>)state["rotation"];
                        if (rs.ContainsKey("isPaused") && rs["isPaused"] != null) bool.TryParse(rs["isPaused"].ToString(), out _rotationIsPaused);
                        if (rs.ContainsKey("lastRotated") && rs["lastRotated"] != null) {
                            DateTime parsed;
                            if (DateTime.TryParse(rs["lastRotated"].ToString(), out parsed)) _rotationLastRotated = parsed.ToUniversalTime();
                        }
                    }
                }
            } catch {}
        }
    }

    private void SetupWindow() {
        this.Title = "6e5tz Wallpaper Manager";
        this.WindowStyle = WindowStyle.None;
        this.AllowsTransparency = true;
        this.Background = Brushes.Transparent;
        this.Topmost = true;
        this.ShowInTaskbar = false;

        Rect workArea = SystemParameters.WorkArea;
        double panelHeight = Math.Max(540, workArea.Height - 32);
        double topPos = workArea.Top + 16;

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

        if (_rotationTicker != null) _rotationTicker.Stop();

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
            this.Close();
            if (onClosed != null) onClosed();
            if (Application.Current != null && Application.Current.MainWindow == this) {
                Application.Current.Shutdown();
            }
        };

        this.BeginAnimation(Window.LeftProperty, slideOut);
        this.BeginAnimation(Window.OpacityProperty, fadeOut);
    }

    private void BuildUI() {
        _rootBorder = new Border {
            CornerRadius = new CornerRadius(16),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMantle, 0.94),
            BorderBrush = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
            BorderThickness = new Thickness(1.2),
            Effect = new DropShadowEffect {
                BlurRadius = 32,
                ShadowDepth = 5,
                Opacity = 0.5,
                Color = Colors.Black,
                Direction = 270
            },
            Padding = new Thickness(16)
        };

        Grid mainGrid = new Grid();
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 0: Header
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 1: Toast
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 2: Provider Selector
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 3: Collections Selector
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 4: View Mode Switcher + Header
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // 5: Wallpapers Area
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 6: Auto Rotation Section
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 7: Bottom Toolbar

        // ---------------------------------------------------------------------
        // Row 0: Header
        // ---------------------------------------------------------------------
        Grid headerGrid = new Grid { Margin = new Thickness(0, 0, 0, 10) };
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        StackPanel titleStack = new StackPanel { Orientation = Orientation.Vertical };
        StackPanel titleRow = new StackPanel { Orientation = Orientation.Horizontal };
        Border dot = new Border {
            Width = 9,
            Height = 9,
            CornerRadius = new CornerRadius(4.5),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 8, 0)
        };
        TextBlock titleText = new TextBlock {
            Text = "6e5tz Wallpaper Manager",
            FontSize = 14.5,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText)
        };
        titleRow.Children.Add(dot);
        titleRow.Children.Add(titleText);

        TextBlock subtitleText = new TextBlock {
            Text = "Universal Rice • Adaptive Grid & 3D Cover Flow",
            FontSize = 10.5,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
            Margin = new Thickness(17, 2, 0, 0)
        };
        titleStack.Children.Add(titleRow);
        titleStack.Children.Add(subtitleText);

        Button closeBtn = new Button {
            Content = "✕",
            Width = 28,
            Height = 28,
            FontSize = 12,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.6),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        ControlTemplate ct = new ControlTemplate(typeof(Button));
        FrameworkElementFactory cb = new FrameworkElementFactory(typeof(Border));
        cb.SetValue(Border.CornerRadiusProperty, new CornerRadius(14));
        cb.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
        FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
        cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        cb.AppendChild(cp);
        ct.VisualTree = cb;
        closeBtn.Template = ct;
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
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.7),
            BorderBrush = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(12, 6, 12, 6),
            Margin = new Thickness(0, 0, 0, 8),
            Visibility = Visibility.Collapsed
        };
        _toastText = new TextBlock {
            Text = "",
            FontSize = 11,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen),
            VerticalAlignment = VerticalAlignment.Center
        };
        _toastBorder.Child = _toastText;
        Grid.SetRow(_toastBorder, 1);
        mainGrid.Children.Add(_toastBorder);

        // ---------------------------------------------------------------------
        // Row 2: Provider Selector
        // ---------------------------------------------------------------------
        StackPanel providerSection = new StackPanel { Margin = new Thickness(0, 0, 0, 8) };
        TextBlock providerLabel = new TextBlock {
            Text = "WALLPAPER PROVIDER",
            FontSize = 9.5,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay),
            Margin = new Thickness(2, 0, 0, 4)
        };
        _providersPanel = new StackPanel { Orientation = Orientation.Horizontal };
        providerSection.Children.Add(providerLabel);
        providerSection.Children.Add(_providersPanel);
        Grid.SetRow(providerSection, 2);
        mainGrid.Children.Add(providerSection);

        // ---------------------------------------------------------------------
        // Row 3: Collections Selector
        // ---------------------------------------------------------------------
        StackPanel collectionSection = new StackPanel { Margin = new Thickness(0, 0, 0, 8) };
        TextBlock collectionLabel = new TextBlock {
            Text = "COLLECTIONS / PLAYLISTS",
            FontSize = 9.5,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay),
            Margin = new Thickness(2, 0, 0, 4)
        };
        ScrollViewer colScroll = new ScrollViewer {
            HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled
        };
        _collectionsPanel = new StackPanel { Orientation = Orientation.Horizontal };
        colScroll.Content = _collectionsPanel;
        collectionSection.Children.Add(collectionLabel);
        collectionSection.Children.Add(colScroll);
        Grid.SetRow(collectionSection, 3);
        mainGrid.Children.Add(collectionSection);

        // ---------------------------------------------------------------------
        // Row 4: View Switcher (Open Standalone Cover Flow Button)
        // ---------------------------------------------------------------------
        Grid viewRow = new Grid { Margin = new Thickness(2, 0, 2, 6) };
        viewRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        viewRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        _gridHeader = new TextBlock {
            Text = "WALLPAPERS",
            FontSize = 9.5,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay),
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(_gridHeader, 0);
        viewRow.Children.Add(_gridHeader);

        Button btnOpenCoverFlow = new Button {
            Content = "3D Cover Flow ↗",
            Height = 24,
            Padding = new Thickness(10, 0, 10, 0),
            FontSize = 10.5,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        ControlTemplate btnT = new ControlTemplate(typeof(Button));
        FrameworkElementFactory btnB = new FrameworkElementFactory(typeof(Border));
        btnB.SetValue(Border.CornerRadiusProperty, new CornerRadius(12));
        btnB.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
        FrameworkElementFactory btnCp = new FrameworkElementFactory(typeof(ContentPresenter));
        btnCp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        btnCp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        btnB.AppendChild(btnCp);
        btnT.VisualTree = btnB;
        btnOpenCoverFlow.Template = btnT;
        btnOpenCoverFlow.Click += (s, e) => LaunchStandaloneCoverFlow();

        Grid.SetColumn(btnOpenCoverFlow, 1);
        viewRow.Children.Add(btnOpenCoverFlow);

        Grid.SetRow(viewRow, 4);
        mainGrid.Children.Add(viewRow);

        // ---------------------------------------------------------------------
        // Row 5: Adaptive 2-Column Grid (UniformGrid Symmetrical Layout)
        // ---------------------------------------------------------------------
        _gridScroll = new ScrollViewer {
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
            Margin = new Thickness(0, 0, 0, 6)
        };
        _gridUniformPanel = new UniformGrid {
            Columns = 2,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Top
        };
        _gridScroll.Content = _gridUniformPanel;

        // Auto-recalculate card sizes whenever scrollviewer is measured
        _gridScroll.SizeChanged += (s, e) => {
            UpdateGridCardWidths();
        };

        Grid.SetRow(_gridScroll, 5);
        mainGrid.Children.Add(_gridScroll);

        // ---------------------------------------------------------------------
        // Row 6: Auto-Rotation Card
        // ---------------------------------------------------------------------
        Border rotationCard = BuildAutoRotationCard();
        Grid.SetRow(rotationCard, 6);
        mainGrid.Children.Add(rotationCard);

        // ---------------------------------------------------------------------
        // Row 7: Bottom Toolbar
        // ---------------------------------------------------------------------
        Border footerBorder = new Border {
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust, 0.6),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(6),
            Margin = new Thickness(0, 4, 0, 0)
        };
        UniformGrid footerGrid = new UniformGrid { Columns = 4 };
        footerGrid.Children.Add(CreateFooterButton("◀ Prev", (s, e) => FastPrevWallpaper()));
        footerGrid.Children.Add(CreateFooterButton("Next ▶", (s, e) => FastNextWallpaper()));
        footerGrid.Children.Add(CreateFooterButton("Shuffle", (s, e) => FastShuffleWallpaper()));
        footerGrid.Children.Add(CreateFooterButton("Folder", (s, e) => OpenCollectionFolder()));
        footerBorder.Child = footerGrid;
        Grid.SetRow(footerBorder, 7);
        mainGrid.Children.Add(footerBorder);

        _rootBorder.Child = mainGrid;
        this.Content = _rootBorder;

        // Initial Data Load
        RenderProviders();
        RenderCollections();
        LoadGridWallpapers();
    }

    private void LaunchStandaloneCoverFlow() {
        if (_isClosing) return;
        _isClosing = true;

        if (_rotationTicker != null) _rotationTicker.Stop();

        // 1. Instantiate the Standalone Cover Flow window
        WallpaperCoverFlowWindow cfWin = new WallpaperCoverFlowWindow(_activeProvider, _activeCollection, _currentWallpaper);

        // 2. Transfer MainWindow to Cover Flow so Side Panel closing won't shut down the app
        if (Application.Current != null) {
            Application.Current.MainWindow = cfWin;
        }

        // 3. Show Cover Flow
        cfWin.Show();

        // 4. Slide out and close Side Panel
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
            this.Close();
        };

        this.BeginAnimation(Window.LeftProperty, slideOut);
        this.BeginAnimation(Window.OpacityProperty, fadeOut);
    }

    // -------------------------------------------------------------------------
    // Issue 1 & 2 Fix: Perfectly Balanced Adaptive 2-Column Grid (UniformGrid)
    // -------------------------------------------------------------------------
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

        double spacing = 6.0;
        double colWidth = (availWidth - (cols * spacing)) / cols;
        double cardHeight = Math.Max(90, Math.Floor(colWidth * 0.62));

        foreach (WallpaperItem item in _currentItems) {
            WallpaperItem curItem = item;
            bool isCurrent = !string.IsNullOrEmpty(_currentWallpaper) &&
                (_currentWallpaper.Equals(curItem.ItemPath, StringComparison.OrdinalIgnoreCase) ||
                 _currentWallpaper.Equals(Path.GetDirectoryName(curItem.ItemPath), StringComparison.OrdinalIgnoreCase));

            Border card = new Border {
                HorizontalAlignment = HorizontalAlignment.Stretch,
                Height = cardHeight,
                Margin = new Thickness(3),
                CornerRadius = new CornerRadius(8),
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
                Padding = new Thickness(6, 3, 6, 3)
            };
            TextBlock lbl = new TextBlock {
                Text = curItem.Title,
                FontSize = 9.5,
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
                    Margin = new Thickness(0, 5, 5, 0),
                    Width = 18,
                    Height = 18,
                    CornerRadius = new CornerRadius(9),
                    Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorBlue)
                };
                TextBlock chk = new TextBlock {
                    Text = "✓",
                    FontSize = 10,
                    FontWeight = FontWeights.Bold,
                    Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust),
                    HorizontalAlignment = HorizontalAlignment.Center,
                    VerticalAlignment = VerticalAlignment.Center
                };
                badge.Child = chk;
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

        double spacing = 6.0;
        double colWidth = (availWidth - (cols * spacing)) / cols;
        double cardHeight = Math.Max(90, Math.Floor(colWidth * 0.62));

        foreach (Border card in _thumbnailCards) {
            card.Height = cardHeight;
        }
    }

    private void ApplyGridWallpaper(WallpaperItem item) {
        WallpaperManagerCore.ApplyWallpaperDirect(item.Provider, item.ItemPath);
        _currentWallpaper = item.ItemPath;
        _rotationLastRotated = DateTime.UtcNow;

        ShowToast("Applied: " + item.Title);
        LoadGridWallpapers();
    }

    // -------------------------------------------------------------------------
    // Blazing-Fast Navigation Actions (0-15ms, No PowerShell Process Spawn!)
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // Providers & Collections
    // -------------------------------------------------------------------------
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
                Height = 28,
                Margin = new Thickness(0, 0, 6, 0),
                Padding = new Thickness(12, 0, 12, 0),
                FontSize = 10.5,
                FontWeight = isActive ? FontWeights.Bold : FontWeights.Normal,
                Foreground = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : (isAvailable ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay)),
                Background = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorBlue) : (isAvailable ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMantle, 0.4)),
                BorderThickness = new Thickness(isActive ? 0 : 1),
                BorderBrush = isActive ? null : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface1),
                IsEnabled = isAvailable,
                Cursor = isAvailable ? Cursors.Hand : Cursors.No
            };

            ControlTemplate t = new ControlTemplate(typeof(Button));
            FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
            b.SetValue(Border.CornerRadiusProperty, new CornerRadius(14));
            b.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
            FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
            cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
            cp.SetValue(ContentPresenter.MarginProperty, new Thickness(10, 0, 10, 0));
            b.AppendChild(cp);
            t.VisualTree = b;
            btn.Template = t;

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
                Height = 24,
                Margin = new Thickness(0, 0, 6, 0),
                FontSize = 10.5,
                FontWeight = isActive ? FontWeights.Bold : FontWeights.Normal,
                Foreground = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
                Background = isActive ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
                BorderThickness = new Thickness(0),
                Cursor = Cursors.Hand
            };

            ControlTemplate t = new ControlTemplate(typeof(Button));
            FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
            b.SetValue(Border.CornerRadiusProperty, new CornerRadius(12));
            b.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
            FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
            cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
            cp.SetValue(ContentPresenter.MarginProperty, new Thickness(10, 0, 10, 0));
            b.AppendChild(cp);
            t.VisualTree = b;
            btn.Template = t;

            string colTarget = col;
            btn.Click += (s, e) => {
                _activeCollection = colTarget;
                RenderCollections();
                LoadGridWallpapers();
            };
            _collectionsPanel.Children.Add(btn);
        }
    }

    // -------------------------------------------------------------------------
    // Auto Rotation Card Section
    // -------------------------------------------------------------------------
    private Border BuildAutoRotationCard() {
        Border card = new Border {
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0, 0.45),
            BorderBrush = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface1, 0.5),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(10, 8, 10, 8),
            Margin = new Thickness(0, 0, 0, 6)
        };

        Grid grid = new Grid();
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        // Row 0: Label, Status, Toggle
        Grid topRow = new Grid { Margin = new Thickness(0, 0, 0, 6) };
        topRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        topRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        topRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        TextBlock label = new TextBlock {
            Text = "AUTO ROTATION",
            FontSize = 9.5,
            FontWeight = FontWeights.Bold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay),
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(label, 0);
        topRow.Children.Add(label);

        _txtRotationStatus = new TextBlock {
            Text = _rotationEnabled ? "Active" : "Disabled",
            FontSize = 10,
            FontWeight = FontWeights.SemiBold,
            Foreground = _rotationEnabled ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay),
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 10, 0)
        };
        Grid.SetColumn(_txtRotationStatus, 1);
        topRow.Children.Add(_txtRotationStatus);

        _btnRotationToggle = new Button {
            Content = _rotationEnabled ? "ON" : "OFF",
            Width = 44,
            Height = 22,
            FontSize = 9.5,
            FontWeight = FontWeights.Bold,
            Foreground = _rotationEnabled ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
            Background = _rotationEnabled ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface1),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        ControlTemplate t = new ControlTemplate(typeof(Button));
        FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
        b.SetValue(Border.CornerRadiusProperty, new CornerRadius(11));
        b.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
        FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
        cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        b.AppendChild(cp);
        t.VisualTree = b;
        _btnRotationToggle.Template = t;
        _btnRotationToggle.Click += (s, e) => ToggleAutoRotation();

        Grid.SetColumn(_btnRotationToggle, 2);
        topRow.Children.Add(_btnRotationToggle);
        Grid.SetRow(topRow, 0);
        grid.Children.Add(topRow);

        // Row 1: Intervals & Controls
        Grid bottomRow = new Grid();
        bottomRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        bottomRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        _rotationIntervalsPanel = new StackPanel { Orientation = Orientation.Horizontal };
        int[] intervals = new int[] { 5, 15, 30, 60 };
        foreach (int min in intervals) {
            _rotationIntervalsPanel.Children.Add(CreateIntervalPill(min));
        }
        Grid.SetColumn(_rotationIntervalsPanel, 0);
        bottomRow.Children.Add(_rotationIntervalsPanel);

        StackPanel actionStack = new StackPanel { Orientation = Orientation.Horizontal };
        _btnRotationPauseResume = new Button {
            Content = _rotationIsPaused ? "▶ Resume" : "❚❚ Pause",
            Height = 22,
            Margin = new Thickness(4, 0, 2, 0),
            Padding = new Thickness(8, 0, 8, 0),
            FontSize = 10,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        ControlTemplate t2 = new ControlTemplate(typeof(Button));
        FrameworkElementFactory b2 = new FrameworkElementFactory(typeof(Border));
        b2.SetValue(Border.CornerRadiusProperty, new CornerRadius(6));
        b2.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
        FrameworkElementFactory cp2 = new FrameworkElementFactory(typeof(ContentPresenter));
        cp2.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        cp2.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        cp2.SetValue(ContentPresenter.MarginProperty, new Thickness(6, 0, 6, 0));
        b2.AppendChild(cp2);
        t2.VisualTree = b2;
        _btnRotationPauseResume.Template = t2;
        _btnRotationPauseResume.Click += (s, e) => ToggleRotationPause();
        actionStack.Children.Add(_btnRotationPauseResume);

        Button rotateNowBtn = new Button {
            Content = "↻ Rotate",
            Height = 22,
            Margin = new Thickness(2, 0, 0, 0),
            Padding = new Thickness(8, 0, 8, 0),
            FontSize = 10,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        rotateNowBtn.Template = t2;
        rotateNowBtn.Click += (s, e) => {
            FastNextWallpaper();
            _rotationLastRotated = DateTime.UtcNow;
            ShowToast("Rotated to next wallpaper");
        };
        actionStack.Children.Add(rotateNowBtn);

        Grid.SetColumn(actionStack, 1);
        bottomRow.Children.Add(actionStack);
        Grid.SetRow(bottomRow, 1);
        grid.Children.Add(bottomRow);

        card.Child = grid;
        return card;
    }

    private Button CreateIntervalPill(int minutes) {
        bool isSel = (_rotationIntervalMinutes == minutes);
        Button btn = new Button {
            Content = minutes + "m",
            Height = 22,
            Margin = new Thickness(0, 0, 4, 0),
            Padding = new Thickness(6, 0, 6, 0),
            FontSize = 10,
            FontWeight = isSel ? FontWeights.Bold : FontWeights.Normal,
            Foreground = isSel ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext),
            Background = isSel ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand,
            Tag = minutes
        };
        ControlTemplate t = new ControlTemplate(typeof(Button));
        FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
        b.SetValue(Border.CornerRadiusProperty, new CornerRadius(6));
        b.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
        FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
        cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        cp.SetValue(ContentPresenter.MarginProperty, new Thickness(6, 0, 6, 0));
        b.AppendChild(cp);
        t.VisualTree = b;
        btn.Template = t;

        int targetMin = minutes;
        btn.Click += (s, e) => {
            _rotationIntervalMinutes = targetMin;
            _rotationLastRotated = DateTime.UtcNow;
            UpdateIntervalPillsUI();
            ShowToast("Interval set to " + targetMin + "m");
        };
        return btn;
    }

    private void UpdateIntervalPillsUI() {
        if (_rotationIntervalsPanel == null) return;
        foreach (UIElement elem in _rotationIntervalsPanel.Children) {
            Button btn = elem as Button;
            if (btn != null && btn.Tag is int) {
                int min = (int)btn.Tag;
                bool isSel = (_rotationIntervalMinutes == min);
                btn.Background = isSel ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorMauve) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0);
                btn.Foreground = isSel ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext);
                btn.FontWeight = isSel ? FontWeights.Bold : FontWeights.Normal;
            }
        }
    }

    private void ToggleAutoRotation() {
        _rotationEnabled = !_rotationEnabled;
        _btnRotationToggle.Content = _rotationEnabled ? "ON" : "OFF";
        _btnRotationToggle.Background = _rotationEnabled ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface1);
        _btnRotationToggle.Foreground = _rotationEnabled ? WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorCrust) : WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSubtext);

        _rotationLastRotated = DateTime.UtcNow;
        ShowToast(_rotationEnabled ? "Auto Rotation Enabled" : "Auto Rotation Disabled");
    }

    private void ToggleRotationPause() {
        _rotationIsPaused = !_rotationIsPaused;
        _btnRotationPauseResume.Content = _rotationIsPaused ? "▶ Resume" : "❚❚ Pause";
        ShowToast(_rotationIsPaused ? "Rotation Paused" : "Rotation Resumed");
    }

    private void InitializeRotationTicker() {
        _rotationTicker = new DispatcherTimer();
        _rotationTicker.Interval = TimeSpan.FromSeconds(1);
        _rotationTicker.Tick += (s, e) => {
            if (!_rotationEnabled) {
                _txtRotationStatus.Text = "Disabled";
                _txtRotationStatus.Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorOverlay);
                return;
            }

            if (_rotationIsPaused) {
                _txtRotationStatus.Text = "❚❚ Paused";
                _txtRotationStatus.Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorPeach);
                return;
            }

            double elapsedSec = (DateTime.UtcNow - _rotationLastRotated).TotalSeconds;
            double totalSec = _rotationIntervalMinutes * 60.0;
            double remSec = totalSec - elapsedSec;

            if (remSec <= 0) {
                _rotationLastRotated = DateTime.UtcNow;
                FastNextWallpaper();
                _txtRotationStatus.Text = "Rotating...";
            } else {
                TimeSpan t = TimeSpan.FromSeconds(remSec);
                _txtRotationStatus.Text = string.Format("Next in {0:D2}:{1:D2}", (int)t.TotalMinutes, t.Seconds);
                _txtRotationStatus.Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorGreen);
            }
        };
        _rotationTicker.Start();
    }

    // -------------------------------------------------------------------------
    // Utilities
    // -------------------------------------------------------------------------
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

    private Button CreateFooterButton(string text, RoutedEventHandler handler) {
        Button btn = new Button {
            Content = text,
            Height = 30,
            Margin = new Thickness(3, 0, 3, 0),
            FontSize = 10.5,
            FontWeight = FontWeights.SemiBold,
            Foreground = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorText),
            Background = WallpaperManagerCore.BrushOf(WallpaperManagerCore.ColorSurface0),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        ControlTemplate t = new ControlTemplate(typeof(Button));
        FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
        b.SetValue(Border.CornerRadiusProperty, new CornerRadius(6));
        b.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
        FrameworkElementFactory p = new FrameworkElementFactory(typeof(ContentPresenter));
        p.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        p.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        b.AppendChild(p);
        t.VisualTree = b;
        btn.Template = t;
        btn.Click += handler;
        return btn;
    }
}
