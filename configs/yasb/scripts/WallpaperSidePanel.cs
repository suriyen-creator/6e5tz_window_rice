using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
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

public class WallpaperSidePanel : Window {
    // Win32 Interop
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    private const int SPI_SETDESKWALLPAPER = 0x0014;
    private const int SPIF_UPDATEINIFILE = 0x01;
    private const int SPIF_SENDCHANGE = 0x02;

    [StructLayout(LayoutKind.Sequential)]
    private struct AccentPolicy {
        public int AccentState;
        public int AccentFlags;
        public int GradientColor;
        public int AnimationId;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct WindowCompositionAttributeData {
        public int Attribute;
        public IntPtr Data;
        public int SizeOfData;
    }

    [DllImport("user32.dll")]
    private static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

    // Catppuccin Mocha Color Palette
    private static readonly Color ColorBase = (Color)ColorConverter.ConvertFromString("#1e1e2e");
    private static readonly Color ColorMantle = (Color)ColorConverter.ConvertFromString("#181825");
    private static readonly Color ColorCrust = (Color)ColorConverter.ConvertFromString("#11111b");
    private static readonly Color ColorSurface0 = (Color)ColorConverter.ConvertFromString("#313244");
    private static readonly Color ColorSurface1 = (Color)ColorConverter.ConvertFromString("#45475a");
    private static readonly Color ColorSurface2 = (Color)ColorConverter.ConvertFromString("#585b70");
    private static readonly Color ColorText = (Color)ColorConverter.ConvertFromString("#cdd6f4");
    private static readonly Color ColorSubtext = (Color)ColorConverter.ConvertFromString("#a6adc8");
    private static readonly Color ColorOverlay = (Color)ColorConverter.ConvertFromString("#6c7086");
    private static readonly Color ColorBlue = (Color)ColorConverter.ConvertFromString("#89b4fa");
    private static readonly Color ColorMauve = (Color)ColorConverter.ConvertFromString("#cba6f7");
    private static readonly Color ColorGreen = (Color)ColorConverter.ConvertFromString("#a6e3a1");
    private static readonly Color ColorRed = (Color)ColorConverter.ConvertFromString("#f38ba8");
    private static readonly Color ColorPeach = (Color)ColorConverter.ConvertFromString("#fab387");

    private static SolidColorBrush BrushOf(Color c, double opacity = 1.0) {
        SolidColorBrush b = new SolidColorBrush(c);
        b.Opacity = opacity;
        b.Freeze();
        return b;
    }

    // Paths
    private string _userProfile;
    private string _configDir;
    private string _configFile;
    private string _stateFile;
    private string _managerScript;
    private string _wallpaperEngineExe;

    // State & Config
    private Dictionary<string, object> _config;
    private Dictionary<string, object> _state;
    private string _activeProvider = "Static";
    private string _activeCollection = "Default";
    private string _currentWallpaper = "";
    private string _uiPosition = "right";
    private double _panelWidth = 420;
    private string _initialNotice = "";

    // UI Controls
    private Border _rootBorder;
    private Border _toastBorder;
    private TextBlock _toastText;
    private StackPanel _providersPanel;
    private StackPanel _collectionsPanel;
    private WrapPanel _gridWrapPanel;
    private TextBlock _gridHeader;
    private Dictionary<string, Button> _providerButtons = new Dictionary<string, Button>();
    private Dictionary<string, Button> _collectionButtons = new Dictionary<string, Button>();
    private List<Border> _thumbnailCards = new List<Border>();

    private bool _isClosing = false;
    private DateTime _loadTime = DateTime.Now;
    private double _targetLeft = 0;
    private double _offscreenLeft = 0;

    [STAThread]
    public static void Main(string[] args) {
        // Parse command line arguments
        string notice = "";
        string provider = "";
        for (int i = 0; i < args.Length; i++) {
            if (args[i].Equals("-Notice", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) {
                notice = args[++i];
            } else if (args[i].Equals("-Provider", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) {
                provider = args[++i];
            }
        }

        // Single-instance and Toggle logic
        Process current = Process.GetCurrentProcess();
        Process[] running = Process.GetProcessesByName(current.ProcessName);
        bool hasOtherInstance = false;
        foreach (Process p in running) {
            if (p.Id != current.Id) {
                hasOtherInstance = true;
                try {
                    p.Kill();
                } catch {}
            }
        }

        // If another instance was open and no Notice was supplied, toggle closed!
        if (hasOtherInstance && string.IsNullOrEmpty(notice)) {
            return;
        }

        Application app = new Application();
        WallpaperSidePanel window = new WallpaperSidePanel(notice, provider);
        app.Run(window);
    }

    public WallpaperSidePanel(string notice, string preferredProvider) {
        _initialNotice = notice;
        if (!string.IsNullOrEmpty(preferredProvider)) {
            _activeProvider = preferredProvider;
        }

        InitializePaths();
        LoadConfigAndState();

        if (!string.IsNullOrEmpty(preferredProvider)) {
            _activeProvider = preferredProvider;
        }

        SetupWindow();
        BuildUI();

        if (!string.IsNullOrEmpty(_initialNotice)) {
            ShowToast(_initialNotice);
        }
    }

    private void InitializePaths() {
        _userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        _configDir = Path.Combine(_userProfile, @".config\6e5tz");
        _configFile = Path.Combine(_configDir, "wallpaper-manager.json");
        _stateFile = Path.Combine(_configDir, "wallpaper-state.json");

        string[] mgrCandidates = new string[] {
            Path.Combine(_configDir, @"scripts\wallpaper\manager.ps1"),
            Path.Combine(_userProfile, @"Documents\window_rice\scripts\wallpaper\manager.ps1"),
            Path.Combine(_userProfile, @".dotfiles\window_rice\scripts\wallpaper\manager.ps1")
        };
        foreach (string m in mgrCandidates) {
            if (File.Exists(m)) { _managerScript = m; break; }
        }

        string[] weCandidates = new string[] {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Steam\steamapps\common\wallpaper_engine\wallpaper64.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Steam\steamapps\common\wallpaper_engine\wallpaper64.exe")
        };
        foreach (string w in weCandidates) {
            if (File.Exists(w)) { _wallpaperEngineExe = w; break; }
        }
    }

    private void LoadConfigAndState() {
        JavaScriptSerializer serializer = new JavaScriptSerializer();
        if (File.Exists(_configFile)) {
            try {
                string json = File.ReadAllText(_configFile);
                _config = serializer.Deserialize<Dictionary<string, object>>(json);
                if (_config != null && _config.ContainsKey("provider") && _config["provider"] != null) {
                    _activeProvider = _config["provider"].ToString();
                }
                if (_config != null && _config.ContainsKey("ui") && _config["ui"] is Dictionary<string, object>) {
                    var ui = (Dictionary<string, object>)_config["ui"];
                    if (ui.ContainsKey("position") && ui["position"] != null) _uiPosition = ui["position"].ToString();
                    if (ui.ContainsKey("width") && ui["width"] != null) double.TryParse(ui["width"].ToString(), out _panelWidth);
                }
            } catch {}
        }
        if (_config == null) _config = new Dictionary<string, object>();

        if (File.Exists(_stateFile)) {
            try {
                string json = File.ReadAllText(_stateFile);
                _state = serializer.Deserialize<Dictionary<string, object>>(json);
                if (_state != null) {
                    if (_state.ContainsKey("activeProvider") && _state["activeProvider"] != null)
                        _activeProvider = _state["activeProvider"].ToString();
                    if (_state.ContainsKey("currentWallpaper") && _state["currentWallpaper"] != null)
                        _currentWallpaper = _state["currentWallpaper"].ToString();
                }
            } catch {}
        }
        if (_state == null) _state = new Dictionary<string, object>();
    }

    private void SetupWindow() {
        this.Title = "6e5tz Wallpaper Manager";
        this.WindowStyle = WindowStyle.None;
        this.AllowsTransparency = true;
        this.Background = Brushes.Transparent;
        this.Topmost = true;
        this.ShowInTaskbar = false;

        Rect workArea = SystemParameters.WorkArea;
        double panelHeight = Math.Max(500, workArea.Height - 32);
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
            ApplyAcrylicBlur();

            // Slide in animation
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

    private void ApplyAcrylicBlur() {
        try {
            IntPtr hwnd = new WindowInteropHelper(this).Handle;
            int accentState = 4; // ACCENT_ENABLE_ACRYLICBLURBEHIND
            int gradientColor = unchecked((int)0xCC181825); // Mantle Catppuccin color with alpha

            AccentPolicy policy = new AccentPolicy {
                AccentState = accentState,
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

    private void SlideOutAndClose() {
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
            this.Close();
        };

        this.BeginAnimation(Window.LeftProperty, slideOut);
        this.BeginAnimation(Window.OpacityProperty, fadeOut);
    }

    private void BuildUI() {
        _rootBorder = new Border {
            CornerRadius = new CornerRadius(16),
            Background = BrushOf(ColorMantle, 0.94),
            BorderBrush = BrushOf(ColorSurface0),
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
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Header
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Toast Notice
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Providers
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Collections
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // Wallpapers
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Bottom Toolbar

        // Row 0: Header
        Grid headerGrid = new Grid { Margin = new Thickness(0, 0, 0, 12) };
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        StackPanel titleStack = new StackPanel { Orientation = Orientation.Vertical };
        StackPanel titleRow = new StackPanel { Orientation = Orientation.Horizontal };
        Border dot = new Border {
            Width = 9,
            Height = 9,
            CornerRadius = new CornerRadius(4.5),
            Background = BrushOf(ColorMauve),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 8, 0)
        };
        TextBlock titleText = new TextBlock {
            Text = "6e5tz Wallpaper Manager",
            FontSize = 15,
            FontWeight = FontWeights.Bold,
            Foreground = BrushOf(ColorText)
        };
        titleRow.Children.Add(dot);
        titleRow.Children.Add(titleText);

        TextBlock subtitleText = new TextBlock {
            Text = "Universal Desktop Rice • Acrylic Side Panel",
            FontSize = 11,
            Foreground = BrushOf(ColorSubtext),
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
            Foreground = BrushOf(ColorSubtext),
            Background = BrushOf(ColorSurface0, 0.6),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand
        };
        // Rounded style for close button
        ControlTemplate closeTemplate = new ControlTemplate(typeof(Button));
        FrameworkElementFactory closeBorder = new FrameworkElementFactory(typeof(Border));
        closeBorder.SetValue(Border.CornerRadiusProperty, new CornerRadius(14));
        closeBorder.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
        FrameworkElementFactory closePresenter = new FrameworkElementFactory(typeof(ContentPresenter));
        closePresenter.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        closePresenter.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        closeBorder.AppendChild(closePresenter);
        closeTemplate.VisualTree = closeBorder;
        closeBtn.Template = closeTemplate;
        closeBtn.Click += (s, e) => SlideOutAndClose();

        Grid.SetColumn(titleStack, 0);
        Grid.SetColumn(closeBtn, 1);
        headerGrid.Children.Add(titleStack);
        headerGrid.Children.Add(closeBtn);
        Grid.SetRow(headerGrid, 0);
        mainGrid.Children.Add(headerGrid);

        // Row 1: Toast Notice Banner
        _toastBorder = new Border {
            CornerRadius = new CornerRadius(8),
            Background = BrushOf(ColorSurface0, 0.7),
            BorderBrush = BrushOf(ColorGreen),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(12, 8, 12, 8),
            Margin = new Thickness(0, 0, 0, 12),
            Visibility = Visibility.Collapsed
        };
        _toastText = new TextBlock {
            Text = "",
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            Foreground = BrushOf(ColorGreen),
            VerticalAlignment = VerticalAlignment.Center
        };
        _toastBorder.Child = _toastText;
        Grid.SetRow(_toastBorder, 1);
        mainGrid.Children.Add(_toastBorder);

        // Row 2: Provider Selector
        StackPanel providerSection = new StackPanel { Margin = new Thickness(0, 0, 0, 12) };
        TextBlock providerLabel = new TextBlock {
            Text = "WALLPAPER PROVIDER",
            FontSize = 10,
            FontWeight = FontWeights.Bold,
            Foreground = BrushOf(ColorOverlay),
            Margin = new Thickness(2, 0, 0, 6)
        };
        _providersPanel = new StackPanel { Orientation = Orientation.Horizontal };
        providerSection.Children.Add(providerLabel);
        providerSection.Children.Add(_providersPanel);
        Grid.SetRow(providerSection, 2);
        mainGrid.Children.Add(providerSection);

        // Row 3: Collections Selector
        StackPanel collectionSection = new StackPanel { Margin = new Thickness(0, 0, 0, 12) };
        TextBlock collectionLabel = new TextBlock {
            Text = "COLLECTIONS",
            FontSize = 10,
            FontWeight = FontWeights.Bold,
            Foreground = BrushOf(ColorOverlay),
            Margin = new Thickness(2, 0, 0, 6)
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

        // Row 4: Wallpaper Grid
        Grid wallGridContainer = new Grid();
        wallGridContainer.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        wallGridContainer.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        _gridHeader = new TextBlock {
            Text = "WALLPAPERS",
            FontSize = 10,
            FontWeight = FontWeights.Bold,
            Foreground = BrushOf(ColorOverlay),
            Margin = new Thickness(2, 0, 0, 6)
        };
        Grid.SetRow(_gridHeader, 0);
        wallGridContainer.Children.Add(_gridHeader);

        ScrollViewer wallScroll = new ScrollViewer {
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
            Margin = new Thickness(0, 0, 0, 8)
        };
        _gridWrapPanel = new WrapPanel { Orientation = Orientation.Horizontal };
        wallScroll.Content = _gridWrapPanel;
        Grid.SetRow(wallScroll, 1);
        wallGridContainer.Children.Add(wallScroll);

        Grid.SetRow(wallGridContainer, 4);
        mainGrid.Children.Add(wallGridContainer);

        // Row 5: Bottom Toolbar
        Border footerBorder = new Border {
            Background = BrushOf(ColorCrust, 0.6),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(8),
            Margin = new Thickness(0, 6, 0, 0)
        };
        UniformGrid footerGrid = new UniformGrid { Columns = 4 };

        Button prevBtn = CreateFooterButton("◄ Prev", (s, e) => TriggerManagerAction("prev"));
        Button nextBtn = CreateFooterButton("Next ►", (s, e) => TriggerManagerAction("next"));
        Button shuffleBtn = CreateFooterButton("🔀 Shuffle", (s, e) => TriggerManagerAction("shuffle"));
        Button folderBtn = CreateFooterButton("📁 Folder", (s, e) => OpenCollectionFolder());

        footerGrid.Children.Add(prevBtn);
        footerGrid.Children.Add(nextBtn);
        footerGrid.Children.Add(shuffleBtn);
        footerGrid.Children.Add(folderBtn);
        footerBorder.Child = footerGrid;

        Grid.SetRow(footerBorder, 5);
        mainGrid.Children.Add(footerBorder);

        _rootBorder.Child = mainGrid;
        this.Content = _rootBorder;

        // Render dynamic contents
        RenderProviders();
        RenderCollections();
        RenderWallpapers();
    }

    private Button CreateFooterButton(string text, RoutedEventHandler handler) {
        Button btn = new Button {
            Content = text,
            Height = 32,
            Margin = new Thickness(3, 0, 3, 0),
            FontSize = 11,
            FontWeight = FontWeights.SemiBold,
            Foreground = BrushOf(ColorText),
            Background = BrushOf(ColorSurface0),
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

    private void ShowToast(string message, bool isSuccess = true) {
        _toastText.Text = (isSuccess ? "✔ " : "ℹ ") + message;
        _toastText.Foreground = isSuccess ? BrushOf(ColorGreen) : BrushOf(ColorMauve);
        _toastBorder.BorderBrush = isSuccess ? BrushOf(ColorGreen) : BrushOf(ColorMauve);
        _toastBorder.Visibility = Visibility.Visible;
    }

    private void RenderProviders() {
        _providersPanel.Children.Clear();
        _providerButtons.Clear();

        string[] providers = new string[] { "Static", "WallpaperEngine", "Lively" };
        string[] labels = new string[] { "Static", "Wallpaper Engine", "Lively" };

        bool hasWE = !string.IsNullOrEmpty(_wallpaperEngineExe) && File.Exists(_wallpaperEngineExe);
        bool hasLively = false; // Lively is not installed on this system

        for (int i = 0; i < providers.Length; i++) {
            string p = providers[i];
            string lbl = labels[i];
            bool isAvailable = (p == "Static") || (p == "WallpaperEngine" && hasWE) || (p == "Lively" && hasLively);
            bool isActive = _activeProvider.Equals(p, StringComparison.OrdinalIgnoreCase);

            Button btn = new Button {
                Content = lbl,
                Height = 30,
                Margin = new Thickness(0, 0, 8, 0),
                Padding = new Thickness(14, 0, 14, 0),
                FontSize = 11,
                FontWeight = isActive ? FontWeights.Bold : FontWeights.Normal,
                Foreground = isActive ? BrushOf(ColorCrust) : (isAvailable ? BrushOf(ColorText) : BrushOf(ColorOverlay)),
                Background = isActive ? BrushOf(ColorBlue) : (isAvailable ? BrushOf(ColorSurface0) : BrushOf(ColorMantle, 0.4)),
                BorderThickness = new Thickness(isActive ? 0 : 1),
                BorderBrush = isActive ? null : BrushOf(ColorSurface1),
                IsEnabled = isAvailable,
                Cursor = isAvailable ? Cursors.Hand : Cursors.No
            };

            ControlTemplate t = new ControlTemplate(typeof(Button));
            FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
            b.SetValue(Border.CornerRadiusProperty, new CornerRadius(15));
            b.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
            b.SetValue(Border.BorderThicknessProperty, new TemplateBindingExtension(Button.BorderThicknessProperty));
            b.SetValue(Border.BorderBrushProperty, new TemplateBindingExtension(Button.BorderBrushProperty));
            FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
            cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
            cp.SetValue(ContentPresenter.MarginProperty, new Thickness(12, 0, 12, 0));
            b.AppendChild(cp);
            t.VisualTree = b;
            btn.Template = t;

            if (isAvailable) {
                string targetP = p;
                btn.Click += (s, e) => SwitchToProvider(targetP);
            }

            _providerButtons[p] = btn;
            _providersPanel.Children.Add(btn);
        }
    }

    private void RenderCollections() {
        _collectionsPanel.Children.Clear();
        _collectionButtons.Clear();

        List<string> collections = new List<string>();

        if (_activeProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            // Read playlists from config.json
            string weConfig = Path.Combine(Path.GetDirectoryName(_wallpaperEngineExe), "config.json");
            if (File.Exists(weConfig)) {
                try {
                    string raw = File.ReadAllText(weConfig);
                    JavaScriptSerializer js = new JavaScriptSerializer();
                    var dict = js.Deserialize<Dictionary<string, object>>(raw);
                    foreach (var kvp in dict) {
                        if (kvp.Value is Dictionary<string, object>) {
                            var v = (Dictionary<string, object>)kvp.Value;
                            if (v.ContainsKey("general") && v["general"] is Dictionary<string, object>) {
                                var g = (Dictionary<string, object>)v["general"];
                                if (g.ContainsKey("playlists") && g["playlists"] is object[]) {
                                    foreach (var pl in (object[])g["playlists"]) {
                                        if (pl is Dictionary<string, object>) {
                                            var pld = (Dictionary<string, object>)pl;
                                            if (pld.ContainsKey("name") && pld["name"] != null) {
                                                collections.Add(pld["name"].ToString());
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch {}
            }
            if (collections.Count == 0) collections.Add("Default");
        } else {
            // Static provider: query subfolders in collection root
            string root = Path.Combine(_userProfile, @"Pictures\Wallpapers");
            if (_config.ContainsKey("collectionRoot") && _config["collectionRoot"] != null) {
                root = _config["collectionRoot"].ToString().Replace("__USERPROFILE__", _userProfile);
            }
            collections.Add("Default");
            if (Directory.Exists(root)) {
                try {
                    foreach (string dir in Directory.GetDirectories(root)) {
                        string name = Path.GetFileName(dir);
                        if (!name.StartsWith(".") && !collections.Contains(name)) {
                            collections.Add(name);
                        }
                    }
                } catch {}
            }
        }

        foreach (string col in collections) {
            bool isActive = _activeCollection.Equals(col, StringComparison.OrdinalIgnoreCase);
            Button btn = new Button {
                Content = col,
                Height = 26,
                Margin = new Thickness(0, 0, 6, 0),
                FontSize = 11,
                FontWeight = isActive ? FontWeights.Bold : FontWeights.Normal,
                Foreground = isActive ? BrushOf(ColorCrust) : BrushOf(ColorText),
                Background = isActive ? BrushOf(ColorMauve) : BrushOf(ColorSurface0),
                BorderThickness = new Thickness(0),
                Cursor = Cursors.Hand
            };

            ControlTemplate t = new ControlTemplate(typeof(Button));
            FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
            b.SetValue(Border.CornerRadiusProperty, new CornerRadius(13));
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
                RenderWallpapers();
            };

            _collectionButtons[col] = btn;
            _collectionsPanel.Children.Add(btn);
        }
    }

    private void RenderWallpapers() {
        _gridWrapPanel.Children.Clear();
        _thumbnailCards.Clear();

        if (_activeProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            _gridHeader.Text = "WALLPAPER ENGINE ACTIVE";
            TextBlock info = new TextBlock {
                Text = "Wallpaper Engine is active.\nPlayback is rendered directly on desktop via DirectX hook.",
                FontSize = 12,
                Foreground = BrushOf(ColorSubtext),
                Margin = new Thickness(6, 12, 6, 12)
            };
            _gridWrapPanel.Children.Add(info);
            return;
        }

        // Static provider: load images from active collection
        string root = Path.Combine(_userProfile, @"Pictures\Wallpapers");
        if (_config.ContainsKey("collectionRoot") && _config["collectionRoot"] != null) {
            root = _config["collectionRoot"].ToString().Replace("__USERPROFILE__", _userProfile);
        }

        string targetDir = root;
        if (!_activeCollection.Equals("Default", StringComparison.OrdinalIgnoreCase)) {
            string sub = Path.Combine(root, _activeCollection);
            if (Directory.Exists(sub)) targetDir = sub;
        }

        List<string> imageFiles = new List<string>();
        if (Directory.Exists(targetDir)) {
            try {
                string[] all = Directory.GetFiles(targetDir);
                foreach (string f in all) {
                    string ext = Path.GetExtension(f).ToLower();
                    if (ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".webp" || ext == ".bmp") {
                        imageFiles.Add(f);
                    }
                }
            } catch {}
        }

        _gridHeader.Text = string.Format("WALLPAPERS ({0})", imageFiles.Count);

        double cardWidth = (_panelWidth - 52) / 2; // 2 columns with spacing
        double cardHeight = cardWidth * 0.65;

        foreach (string file in imageFiles) {
            string filePath = file;
            string fileName = Path.GetFileName(filePath);
            bool isCurrent = !string.IsNullOrEmpty(_currentWallpaper) && _currentWallpaper.Equals(filePath, StringComparison.OrdinalIgnoreCase);

            Border card = new Border {
                Width = cardWidth,
                Height = cardHeight,
                Margin = new Thickness(4),
                CornerRadius = new CornerRadius(10),
                Background = BrushOf(ColorCrust),
                BorderBrush = isCurrent ? BrushOf(ColorBlue) : BrushOf(ColorSurface0),
                BorderThickness = new Thickness(isCurrent ? 2.5 : 1),
                ClipToBounds = true,
                Cursor = Cursors.Hand,
                Tag = filePath
            };

            Grid cardGrid = new Grid();

            // Image element
            Image img = new Image {
                Stretch = Stretch.UniformToFill,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            cardGrid.Children.Add(img);

            // Bottom overlay bar with filename
            Border labelOverlay = new Border {
                VerticalAlignment = VerticalAlignment.Bottom,
                Background = BrushOf(ColorCrust, 0.78),
                Padding = new Thickness(6, 4, 6, 4)
            };
            TextBlock lbl = new TextBlock {
                Text = fileName,
                FontSize = 10,
                FontWeight = FontWeights.SemiBold,
                Foreground = isCurrent ? BrushOf(ColorBlue) : BrushOf(ColorText),
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            labelOverlay.Child = lbl;
            cardGrid.Children.Add(labelOverlay);

            // Active checkmark badge
            if (isCurrent) {
                Border badge = new Border {
                    HorizontalAlignment = HorizontalAlignment.Right,
                    VerticalAlignment = VerticalAlignment.Top,
                    Margin = new Thickness(0, 6, 6, 0),
                    Width = 20,
                    Height = 20,
                    CornerRadius = new CornerRadius(10),
                    Background = BrushOf(ColorBlue)
                };
                TextBlock chk = new TextBlock {
                    Text = "✔",
                    FontSize = 11,
                    FontWeight = FontWeights.Bold,
                    Foreground = BrushOf(ColorCrust),
                    HorizontalAlignment = HorizontalAlignment.Center,
                    VerticalAlignment = VerticalAlignment.Center
                };
                badge.Child = chk;
                cardGrid.Children.Add(badge);
            }

            card.Child = cardGrid;

            // Click to apply wallpaper
            card.MouseLeftButtonUp += (s, e) => {
                ApplyStaticWallpaper(filePath);
            };

            _thumbnailCards.Add(card);
            _gridWrapPanel.Children.Add(card);

            // Load thumbnail asynchronously
            Dispatcher.BeginInvoke(new Action(() => {
                try {
                    BitmapImage bi = new BitmapImage();
                    bi.BeginInit();
                    bi.UriSource = new Uri(filePath, UriKind.Absolute);
                    bi.DecodePixelWidth = 220;
                    bi.CacheOption = BitmapCacheOption.OnLoad;
                    bi.EndInit();
                    bi.Freeze();
                    img.Source = bi;
                } catch {}
            }), DispatcherPriority.Background);
        }
    }

    private void ApplyStaticWallpaper(string filePath) {
        if (!File.Exists(filePath)) return;

        // 1. If Wallpaper Engine is running, stop it so static wallpaper is visible
        if (_activeProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            StopWallpaperEngine();
            _activeProvider = "Static";
            RenderProviders();
        }

        // 2. Set desktop wallpaper via Win32 API
        try {
            SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, filePath, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
        } catch {}

        // Ensure Wallpaper Engine is stopped
        StopWallpaperEngine();

        // 3. Update state
        _currentWallpaper = filePath;
        UpdateStateFile("Static", filePath);

        // 4. Update UI highlights
        ShowToast("Applied: " + Path.GetFileName(filePath));
        RenderWallpapers();
    }

    private void SwitchToProvider(string newProvider) {
        if (_activeProvider.Equals(newProvider, StringComparison.OrdinalIgnoreCase)) return;

        if (newProvider.Equals("Static", StringComparison.OrdinalIgnoreCase)) {
            // Stop Wallpaper Engine hook window
            StopWallpaperEngine();

            // Resolve wallpaper to show
            string wpToApply = _currentWallpaper;
            if (string.IsNullOrEmpty(wpToApply) || !File.Exists(wpToApply)) {
                string root = Path.Combine(_userProfile, @"Pictures\Wallpapers");
                if (Directory.Exists(root)) {
                    string[] files = Directory.GetFiles(root);
                    foreach (string f in files) {
                        string ext = Path.GetExtension(f).ToLower();
                        if (ext == ".jpg" || ext == ".png") { wpToApply = f; break; }
                    }
                }
            }

            if (!string.IsNullOrEmpty(wpToApply) && File.Exists(wpToApply)) {
                try {
                    SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, wpToApply, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
                } catch {}
                _currentWallpaper = wpToApply;
            }

            StopWallpaperEngine();
            _activeProvider = "Static";
            UpdateStateFile("Static", _currentWallpaper);
            ShowToast("Switched to Static Wallpaper");
        } else if (newProvider.Equals("WallpaperEngine", StringComparison.OrdinalIgnoreCase)) {
            // Start or resume Wallpaper Engine
            StartWallpaperEngine();
            _activeProvider = "WallpaperEngine";
            UpdateStateFile("WallpaperEngine", _currentWallpaper);
            ShowToast("Switched to Wallpaper Engine");
        }

        RenderProviders();
        RenderCollections();
        RenderWallpapers();
    }

    private void StopWallpaperEngine() {
        if (!string.IsNullOrEmpty(_wallpaperEngineExe) && File.Exists(_wallpaperEngineExe)) {
            try {
                ProcessStartInfo psi = new ProcessStartInfo {
                    FileName = _wallpaperEngineExe,
                    Arguments = "-control stop",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                Process.Start(psi);
            } catch {}
        }
    }

    private void StartWallpaperEngine() {
        if (!string.IsNullOrEmpty(_wallpaperEngineExe) && File.Exists(_wallpaperEngineExe)) {
            try {
                ProcessStartInfo psi = new ProcessStartInfo {
                    FileName = _wallpaperEngineExe,
                    Arguments = "-control play",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                Process.Start(psi);
            } catch {}
        }
    }

    private void UpdateStateFile(string provider, string currentWp) {
        try {
            _state["activeProvider"] = provider;
            _state["currentWallpaper"] = currentWp;
            _state["lastSwitched"] = DateTime.Now.ToString("o");

            JavaScriptSerializer js = new JavaScriptSerializer();
            string json = js.Serialize(_state);
            File.WriteAllText(_stateFile, json);
        } catch {}

        if (File.Exists(_configFile)) {
            try {
                _config["provider"] = provider;
                JavaScriptSerializer js = new JavaScriptSerializer();
                File.WriteAllText(_configFile, js.Serialize(_config));
            } catch {}
        }
    }

    private void TriggerManagerAction(string action) {
        if (string.IsNullOrEmpty(_managerScript) || !File.Exists(_managerScript)) return;

        string pwsh = "powershell.exe";
        string[] candidates = new string[] {
            Path.Combine(_userProfile, @"scoop\apps\pwsh\current\pwsh.exe"),
            @"C:\Program Files\PowerShell\7\pwsh.exe"
        };
        foreach (string p in candidates) {
            if (File.Exists(p)) { pwsh = p; break; }
        }

        try {
            ProcessStartInfo psi = new ProcessStartInfo {
                FileName = pwsh,
                Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -File \"{0}\" -Action {1}", _managerScript, action),
                CreateNoWindow = true,
                UseShellExecute = false,
                WindowStyle = ProcessWindowStyle.Hidden
            };
            Process proc = Process.Start(psi);
            proc.WaitForExit(2000);

            // Reload state after manager action
            LoadConfigAndState();
            RenderWallpapers();
            ShowToast("Wallpaper Updated (" + action + ")");
        } catch {}
    }

    private void OpenCollectionFolder() {
        string root = Path.Combine(_userProfile, @"Pictures\Wallpapers");
        if (_config.ContainsKey("collectionRoot") && _config["collectionRoot"] != null) {
            root = _config["collectionRoot"].ToString().Replace("__USERPROFILE__", _userProfile);
        }
        string target = root;
        if (!_activeCollection.Equals("Default", StringComparison.OrdinalIgnoreCase)) {
            string sub = Path.Combine(root, _activeCollection);
            if (Directory.Exists(sub)) target = sub;
        }

        if (Directory.Exists(target)) {
            try {
                Process.Start("explorer.exe", target);
            } catch {}
        }
    }
}
