# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Modern Dark Catppuccin Gallery UI
# Native lightweight WPF / XAML interface for browsing collections & switching wallpapers
# ==============================================================================

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Ensure STA thread for WPF
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    $scriptPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
    $pwshCandidates = @(
        (Join-Path $env:USERPROFILE 'scoop\apps\pwsh\current\pwsh.exe'),
        'C:\Program Files\PowerShell\7\pwsh.exe',
        'powershell.exe'
    )
    $hostExe = $pwshCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $hostExe) { $hostExe = 'powershell.exe' }

    Start-Process -FilePath $hostExe -ArgumentList "-Sta", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"" -WindowStyle Hidden
    exit 0
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$scriptRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $scriptRoot 'common.ps1')
. (Join-Path $scriptRoot 'config.ps1')
. (Join-Path $scriptRoot 'state.ps1')
. (Join-Path $scriptRoot 'detection.ps1')
. (Join-Path $scriptRoot 'collections\folders.ps1')
. (Join-Path $scriptRoot 'providers\static.ps1')
. (Join-Path $scriptRoot 'providers\wallpaper-engine.ps1')
. (Join-Path $scriptRoot 'providers\lively.ps1')
. (Join-Path $scriptRoot 'manager.ps1')

$managerScript = Join-Path $scriptRoot 'manager.ps1'

# Catppuccin Mocha Color Palette
$C_Base = "#1e1e2e"
$C_Mantle = "#181825"
$C_Crust = "#11111b"
$C_Surface0 = "#313244"
$C_Surface1 = "#45475a"
$C_Surface2 = "#585b70"
$C_Text = "#cdd6f4"
$C_Subtext = "#a6adc8"
$C_Blue = "#89b4fa"
$C_Mauve = "#cba6f7"
$C_Green = "#a6e3a1"
$C_Red = "#f38ba8"
$C_Peach = "#fab387"
$C_Overlay = "#6c7086"

$xamlString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="6e5tz Universal Wallpaper Manager"
        Height="720" Width="1040"
        WindowStartupLocation="CenterScreen"
        Background="$C_Crust"
        Foreground="$C_Text"
        FontFamily="Segoe UI, Inter, Sans-serif">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="$C_Surface0"/>
            <Setter Property="Foreground" Value="$C_Text"/>
            <Setter Property="BorderBrush" Value="$C_Surface1"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="14,7"/>
            <Setter Property="Margin" Value="4,2"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="$C_Surface1"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="$C_Blue"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="$C_Surface2"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="$C_Mantle" CornerRadius="12" Padding="16,12" Margin="0,0,0,14" BorderBrush="$C_Surface0" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="🌸 6e5tz" FontSize="20" FontWeight="Bold" Foreground="$C_Mauve" Margin="0,0,8,0"/>
                        <TextBlock Text="Universal Wallpaper Manager" FontSize="18" FontWeight="SemiBold" Foreground="$C_Text" VerticalAlignment="Center"/>
                    </StackPanel>
                    <TextBlock x:Name="TxtSubtitle" Text="Linux-like desktop wallpaper environment for Windows" FontSize="12" Foreground="$C_Subtext" Margin="0,3,0,0"/>
                </StackPanel>
                <Border Grid.Column="1" Background="$C_Base" CornerRadius="8" Padding="12,6" BorderBrush="$C_Surface1" BorderThickness="1">
                    <TextBlock x:Name="TxtActiveStatus" Text="Provider: Static | Collection: Default" FontSize="12" FontWeight="SemiBold" Foreground="$C_Green" VerticalAlignment="Center"/>
                </Border>
            </Grid>
        </Border>

        <!-- Section 1: Engine Selector -->
        <Border Grid.Row="1" Background="$C_Base" CornerRadius="10" Padding="12,10" Margin="0,0,0,12" BorderBrush="$C_Surface0" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="WALLPAPER ENGINE" FontSize="11" FontWeight="Bold" Foreground="$C_Mauve" VerticalAlignment="Center" Margin="6,0,16,0"/>
                <StackPanel Grid.Column="1" Orientation="Horizontal" x:Name="PanelEngines">
                    <Button x:Name="BtnEngineStatic" Content="  Static Wallpaper  "/>
                    <Button x:Name="BtnEngineWallpaperEngine" Content="  Wallpaper Engine  "/>
                    <Button x:Name="BtnEngineLively" Content="  Lively Wallpaper  "/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Section 2: Collections Pill Bar -->
        <Border Grid.Row="2" Background="$C_Base" CornerRadius="10" Padding="12,10" Margin="0,0,0,12" BorderBrush="$C_Surface0" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="COLLECTIONS" FontSize="11" FontWeight="Bold" Foreground="$C_Blue" VerticalAlignment="Center" Margin="6,0,16,0"/>
                <ScrollViewer Grid.Column="1" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled">
                    <StackPanel Orientation="Horizontal" x:Name="PanelCollections"/>
                </ScrollViewer>
                <Button Grid.Column="2" x:Name="BtnRefreshFolders" Content=" 🔄 Refresh " Margin="8,0,0,0" ToolTip="Refresh collections from disk"/>
            </Grid>
        </Border>

        <!-- Section 3: Wallpaper Grid -->
        <Border Grid.Row="3" Background="$C_Base" CornerRadius="12" Padding="12" Margin="0,0,0,14" BorderBrush="$C_Surface0" BorderThickness="1">
            <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" x:Name="ScrollGrid">
                <WrapPanel x:Name="PanelWallpaperGrid" ItemWidth="236" ItemHeight="172" Margin="4"/>
            </ScrollViewer>
        </Border>

        <!-- Section 4: Controls & Status -->
        <Border Grid.Row="4" Background="$C_Mantle" CornerRadius="12" Padding="16,10" BorderBrush="$C_Surface0" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Orientation="Horizontal">
                    <Button x:Name="BtnPrevious" Content="  ◄ Previous  "/>
                    <Button x:Name="BtnNext" Content="  Next ►  "/>
                    <Button x:Name="BtnShuffle" Content="  🔀 Shuffle  "/>
                    <Button x:Name="BtnFavorite" Content="  ★ Favorite  "/>
                </StackPanel>
                <TextBlock Grid.Column="1" x:Name="TxtCurrentWallpaper" Text="Active Wallpaper: Ready" FontSize="12" Foreground="$C_Subtext" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" Margin="14,0"/>
                <StackPanel Grid.Column="2" Orientation="Horizontal">
                    <Button x:Name="BtnOpenFolder" Content=" 📁 Open Folder "/>
                    <Button x:Name="BtnWorkspaceSettings" Content=" 🖥️ Workspaces "/>
                    <Button x:Name="BtnClose" Content=" Close "/>
                </StackPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlString))
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Get Controls
$txtActiveStatus = $window.FindName("TxtActiveStatus")
$txtCurrentWallpaper = $window.FindName("TxtCurrentWallpaper")
$panelCollections = $window.FindName("PanelCollections")
$panelWallpaperGrid = $window.FindName("PanelWallpaperGrid")
$btnEngineStatic = $window.FindName("BtnEngineStatic")
$btnEngineWallpaperEngine = $window.FindName("BtnEngineWallpaperEngine")
$btnEngineLively = $window.FindName("BtnEngineLively")
$btnRefreshFolders = $window.FindName("BtnRefreshFolders")
$btnPrevious = $window.FindName("BtnPrevious")
$btnNext = $window.FindName("BtnNext")
$btnShuffle = $window.FindName("BtnShuffle")
$btnFavorite = $window.FindName("BtnFavorite")
$btnOpenFolder = $window.FindName("BtnOpenFolder")
$btnWorkspaceSettings = $window.FindName("BtnWorkspaceSettings")
$btnClose = $window.FindName("BtnClose")

$script:CurrentProvider = Get-ActiveProviderName
$script:CurrentCollection = Get-ActiveCollectionName -ProviderName $script:CurrentProvider

function Get-Brush {
    param([string]$Hex)
    return [System.Windows.Media.BrushConverter]::new().ConvertFromString($Hex)
}

function Update-EngineButtonsState {
    $providers = Get-WallpaperProviders

    # Static
    $isStaticActive = ($script:CurrentProvider -eq 'Static')
    $btnEngineStatic.Background = if ($isStaticActive) { Get-Brush $C_Mauve } else { Get-Brush $C_Surface0 }
    $btnEngineStatic.Foreground = if ($isStaticActive) { Get-Brush $C_Crust } else { Get-Brush $C_Text }

    # Wallpaper Engine
    $isWeActive = ($script:CurrentProvider -eq 'WallpaperEngine')
    $btnEngineWallpaperEngine.IsEnabled = $providers['WallpaperEngine'].Available
    $btnEngineWallpaperEngine.Content = if ($providers['WallpaperEngine'].Available) { "  Wallpaper Engine  " } else { "  Wallpaper Engine (Offline)  " }
    $btnEngineWallpaperEngine.Background = if ($isWeActive) { Get-Brush $C_Mauve } else { Get-Brush $C_Surface0 }
    $btnEngineWallpaperEngine.Foreground = if ($isWeActive) { Get-Brush $C_Crust } else { Get-Brush $C_Text }

    # Lively
    $isLivelyActive = ($script:CurrentProvider -eq 'Lively')
    $btnEngineLively.IsEnabled = $providers['Lively'].Available
    $btnEngineLively.Content = if ($providers['Lively'].Available) { "  Lively Wallpaper  " } else { "  Lively (Offline)  " }
    $btnEngineLively.Background = if ($isLivelyActive) { Get-Brush $C_Mauve } else { Get-Brush $C_Surface0 }
    $btnEngineLively.Foreground = if ($isLivelyActive) { Get-Brush $C_Crust } else { Get-Brush $C_Text }
}

function Render-CollectionButtons {
    $panelCollections.Children.Clear()
    $folders = Get-CollectionFolders -Provider $script:CurrentProvider

    foreach ($folder in $folders) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = "$($folder.Name) ($($folder.ItemCount))"
        $isActive = ($folder.Name -ieq $script:CurrentCollection)
        $btn.Background = if ($isActive) { Get-Brush $C_Blue } else { Get-Brush $C_Surface0 }
        $btn.Foreground = if ($isActive) { Get-Brush $C_Crust } else { Get-Brush $C_Text }

        $targetName = $folder.Name
        $btn.add_Click({
            $script:CurrentCollection = $targetName
            Set-ActiveCollectionName -ProviderName $script:CurrentProvider -CollectionName $targetName
            Render-CollectionButtons
            Render-WallpaperGrid
        })
        $panelCollections.Children.Add($btn) | Out-Null
    }
}

function Render-WallpaperGrid {
    $panelWallpaperGrid.Children.Clear()
    $wallpapers = Get-CollectionWallpapers -CollectionName $script:CurrentCollection -Provider $script:CurrentProvider

    $state = Get-WpState
    $currentActive = [string]$state.currentWallpaper
    $txtActiveStatus.Text = "Provider: $($script:CurrentProvider) | Collection: $($script:CurrentCollection)"
    $txtCurrentWallpaper.Text = if ($currentActive) { "Active: $(Split-Path -Leaf $currentActive)" } else { "No active wallpaper" }

    if ($wallpapers.Count -eq 0) {
        $emptyText = New-Object System.Windows.Controls.TextBlock
        $emptyText.Text = "No wallpapers found in collection '$($script:CurrentCollection)'"
        $emptyText.Foreground = Get-Brush $C_Subtext
        $emptyText.FontSize = 14
        $emptyText.Margin = New-Object System.Windows.Thickness(20)
        $panelWallpaperGrid.Children.Add($emptyText) | Out-Null
        return
    }

    foreach ($wp in $wallpapers) {
        $card = New-Object System.Windows.Controls.Border
        $card.Width = 224
        $card.Height = 160
        $card.Margin = New-Object System.Windows.Thickness(6)
        $card.CornerRadius = New-Object System.Windows.CornerRadius(10)
        $card.Cursor = [System.Windows.Input.Cursors]::Hand

        $isActive = ($wp.FullName -ieq $currentActive)
        $card.BorderBrush = if ($isActive) { Get-Brush $C_Blue } else { Get-Brush $C_Surface1 }
        $thicknessVal = if ($isActive) { 2.5 } else { 1.0 }
        $card.BorderThickness = New-Object System.Windows.Thickness($thicknessVal)
        $card.Background = Get-Brush $C_Mantle

        $grid = New-Object System.Windows.Controls.Grid
        $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = New-Object System.Windows.GridLength(118) }))
        $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = New-Object System.Windows.GridLength(36) }))

        # Thumbnail Image
        $img = New-Object System.Windows.Controls.Image
        $img.Stretch = [System.Windows.Media.Stretch]::UniformToFill
        $img.ClipToBounds = $true

        try {
            $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.UriSource = [Uri]$wp.FullName
            $bmp.DecodePixelWidth = 240
            $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.EndInit()
            $img.Source = $bmp
        } catch {}

        [System.Windows.Controls.Grid]::SetRow($img, 0)
        $grid.Children.Add($img) | Out-Null

        # Title footer
        $footer = New-Object System.Windows.Controls.Border
        $footer.Background = Get-Brush $C_Base
        $footer.Padding = New-Object System.Windows.Thickness(8, 4, 8, 4)

        $footerGrid = New-Object System.Windows.Controls.Grid
        $footerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) }))
        $footerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Auto) }))

        $label = New-Object System.Windows.Controls.TextBlock
        $label.Text = $wp.Name
        $label.FontSize = 11
        $label.FontWeight = [System.Windows.FontWeights]::SemiBold
        $label.Foreground = Get-Brush $C_Text
        $label.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
        $label.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($label, 0)
        $footerGrid.Children.Add($label) | Out-Null

        if ($isActive) {
            $badge = New-Object System.Windows.Controls.Border
            $badge.Background = Get-Brush $C_Blue
            $badge.CornerRadius = New-Object System.Windows.CornerRadius(4)
            $badge.Padding = New-Object System.Windows.Thickness(6, 2, 6, 2)
            $badgeText = New-Object System.Windows.Controls.TextBlock
            $badgeText.Text = "ACTIVE"
            $badgeText.FontSize = 9
            $badgeText.FontWeight = [System.Windows.FontWeights]::Bold
            $badgeText.Foreground = Get-Brush $C_Crust
            $badge.Child = $badgeText
            [System.Windows.Controls.Grid]::SetColumn($badge, 1)
            $footerGrid.Children.Add($badge) | Out-Null
        }

        $footer.Child = $footerGrid
        [System.Windows.Controls.Grid]::SetRow($footer, 1)
        $grid.Children.Add($footer) | Out-Null

        $card.Child = $grid

        $targetFile = $wp.FullName
        $card.add_MouseDown({
            Write-WpLog -Message "Selected wallpaper: $targetFile" -Level Info
            & $managerScript -Action set -Path $targetFile -Provider $script:CurrentProvider | Out-Null
            Render-WallpaperGrid
        })

        $panelWallpaperGrid.Children.Add($card) | Out-Null
    }
}

# -----------------------------------------------------------------------------
# Event Handlers
# -----------------------------------------------------------------------------
$btnEngineStatic.add_Click({
    & $managerScript -Action provider -Provider 'Static' | Out-Null
    $script:CurrentProvider = 'Static'
    $script:CurrentCollection = Get-ActiveCollectionName -ProviderName 'Static'
    Update-EngineButtonsState
    Render-CollectionButtons
    Render-WallpaperGrid
})

$btnEngineWallpaperEngine.add_Click({
    & $managerScript -Action provider -Provider 'WallpaperEngine' | Out-Null
    $script:CurrentProvider = 'WallpaperEngine'
    $script:CurrentCollection = Get-ActiveCollectionName -ProviderName 'WallpaperEngine'
    Update-EngineButtonsState
    Render-CollectionButtons
    Render-WallpaperGrid
})

$btnEngineLively.add_Click({
    & $managerScript -Action provider -Provider 'Lively' | Out-Null
    $script:CurrentProvider = 'Lively'
    $script:CurrentCollection = Get-ActiveCollectionName -ProviderName 'Lively'
    Update-EngineButtonsState
    Render-CollectionButtons
    Render-WallpaperGrid
})

$btnRefreshFolders.add_Click({
    Clear-CollectionCache
    Render-CollectionButtons
    Render-WallpaperGrid
})

$btnPrevious.add_Click({
    & $managerScript -Action prev -Provider $script:CurrentProvider -Collection $script:CurrentCollection | Out-Null
    Render-WallpaperGrid
})

$btnNext.add_Click({
    & $managerScript -Action next -Provider $script:CurrentProvider -Collection $script:CurrentCollection | Out-Null
    Render-WallpaperGrid
})

$btnShuffle.add_Click({
    & $managerScript -Action shuffle -Provider $script:CurrentProvider -Collection $script:CurrentCollection | Out-Null
    Render-WallpaperGrid
})

$btnFavorite.add_Click({
    Toggle-StaticFavorite | Out-Null
})

$btnOpenFolder.add_Click({
    $folders = Get-CollectionFolders -Provider $script:CurrentProvider
    $curr = $folders | Where-Object { $_.Name -ieq $script:CurrentCollection } | Select-Object -First 1
    if ($curr -and (Test-Path -LiteralPath $curr.Path)) {
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$($curr.Path)`""
    }
})

$btnWorkspaceSettings.add_Click({
    $config = Get-WpConfig
    $wsMsg = "GlazeWM Workspace Mappings:`n"
    if ($null -ne $config.PSObject.Properties['workspaceMapping']) {
        foreach ($prop in $config.workspaceMapping.PSObject.Properties) {
            $wsMsg += "  Workspace $($prop.Name): [$($prop.Value.provider)] $($prop.Value.collection)`n"
        }
    }
    $wsMsg += "`nConfiguration stored in: $script:ConfigFilePath"
    [System.Windows.MessageBox]::Show($wsMsg, "Workspace Wallpapers Mapping", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
})

$btnClose.add_Click({
    $window.Close()
})

# Initial render
Update-EngineButtonsState
Render-CollectionButtons
Render-WallpaperGrid

$window.ShowDialog() | Out-Null
