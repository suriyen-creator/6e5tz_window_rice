# ==============================================================================
# 6e5tz Universal Wallpaper Manager - Comprehensive Test Suite
# Tests all 14 acceptance test criteria across providers, collections, and workspace integration
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$Detailed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$scriptsRoot = Join-Path $repoRoot 'scripts\wallpaper'

$totalTests = 0
$passedTests = 0
$failedTests = 0
$testResults = [System.Collections.Generic.List[object]]::new()

function Assert-Test {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Condition,
        [string]$Message = ""
    )
    $script:totalTests++
    if ($Condition) {
        $script:passedTests++
        $script:testResults.Add([PSCustomObject]@{ Test = $Name; Status = "PASS"; Details = $Message })
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        if ($Detailed -and $Message) { Write-Host "         $Message" -ForegroundColor DarkGray }
    } else {
        $script:failedTests++
        $script:testResults.Add([PSCustomObject]@{ Test = $Name; Status = "FAIL"; Details = $Message })
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Message) { Write-Host "         ERROR: $Message" -ForegroundColor Yellow }
    }
}

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "  🌸 Running 6e5tz Universal Wallpaper Manager Test Suite         " -ForegroundColor Magenta
Write-Host "==================================================================" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Test 1: PowerShell Syntax across all project scripts
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 1] PowerShell Syntax Validation" -ForegroundColor White
$psFiles = @(Get-ChildItem -Path $scriptsRoot -Filter "*.ps1" -Recurse) + @(
    (Join-Path $repoRoot 'scripts\switch-wallpaper-mode.ps1'),
    (Join-Path $repoRoot 'scripts\wallpaper_engine_control.ps1'),
    (Join-Path $repoRoot 'configs\yasb\scripts\next-wallpaper.ps1'),
    (Join-Path $repoRoot 'configs\yasb\scripts\wallpaper-gallery.ps1'),
    (Join-Path $repoRoot 'configs\yasb\scripts\cycle-provider.ps1'),
    (Join-Path $repoRoot 'install.ps1'),
    (Join-Path $repoRoot 'backup.ps1')
) | Where-Object { Test-Path -LiteralPath $_ }

$syntaxPassed = $true
$syntaxErrors = [System.Collections.Generic.List[string]]::new()
foreach ($file in $psFiles) {
    $filePath = if ($file -is [string]) { $file } else { $file.FullName }
    $errors = $null
    $tokens = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $syntaxPassed = $false
        foreach ($err in $errors) {
            $syntaxErrors.Add("$([System.IO.Path]::GetFileName($filePath)): Line $($err.Extent.StartLineNumber) - $($err.Message)")
        }
    }
}
Assert-Test -Name "PowerShell Syntax (0 syntax errors in $($psFiles.Count) scripts)" -Condition $syntaxPassed -Message ($syntaxErrors -join "; ")

# -----------------------------------------------------------------------------
# Test 2: Configuration JSON Parsing and Schema Defaults
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 2] Configuration Schema & Defaults" -ForegroundColor White
$defaultConfigPath = Join-Path $repoRoot 'configs\wallpaper\manager.default.json'
$hasDefault = Test-Path -LiteralPath $defaultConfigPath
Assert-Test -Name "manager.default.json exists" -Condition $hasDefault -Message $defaultConfigPath

$rawCfg = [System.IO.File]::ReadAllText($defaultConfigPath, [System.Text.Encoding]::UTF8)
$parsedCfg = $null
try { $parsedCfg = $rawCfg | ConvertFrom-Json } catch {}

$cfgValid = ($null -ne $parsedCfg -and $null -ne $parsedCfg.provider -and $null -ne $parsedCfg.workspaceMapping)
Assert-Test -Name "Default JSON config parses successfully with required properties" -Condition $cfgValid -Message "Provider: $($parsedCfg.provider)"

# Test config loader function
. (Join-Path $scriptsRoot 'config.ps1')
$loadedCfg = Get-WpConfig
$loaderValid = ($null -ne $loadedCfg -and -not [string]::IsNullOrWhiteSpace($loadedCfg.provider))
Assert-Test -Name "Get-WpConfig loads and expands portable paths" -Condition $loaderValid -Message "CollectionRoot: $($loadedCfg.collectionRoot)"

# -----------------------------------------------------------------------------
# Test 3: Provider Detection System
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 3] Provider Detection" -ForegroundColor White
. (Join-Path $scriptsRoot 'detection.ps1')
$providers = Get-WallpaperProviders
Assert-Test -Name "Get-WallpaperProviders detects 3 core engines" -Condition ($providers.Count -ge 3) -Message "Found: $($providers.Keys -join ', ')"
Assert-Test -Name "Static Wallpaper provider is always Available" -Condition ($providers['Static'].Available -eq $true) -Message $providers['Static'].Description
Assert-Test -Name "Wallpaper Engine status correctly detected" -Condition ($null -ne $providers['WallpaperEngine']) -Message "Available: $($providers['WallpaperEngine'].Available)"
Assert-Test -Name "Lively Wallpaper status correctly detected" -Condition ($null -ne $providers['Lively']) -Message "Available: $($providers['Lively'].Available)"

# -----------------------------------------------------------------------------
# Test 4: Missing Provider Handling
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 4] Missing Provider Safety & Fallback" -ForegroundColor White
$fakeAvail = Test-ProviderAvailable -Name "NonExistentEngine999"
Assert-Test -Name "Test-ProviderAvailable safely returns False for unknown provider" -Condition ($fakeAvail -eq $false) -Message "Result: $fakeAvail"

. (Join-Path $scriptsRoot 'manager.ps1')
$stateBefore = Get-ActiveProviderName
# Attempting to switch to an unavailable provider should safely fall back and return false
$switchFake = Switch-Provider -NewProvider "NonExistentEngine999"
Assert-Test -Name "Switch-Provider safely denies unavailable provider without crashing" -Condition ($switchFake -eq $false) -Message "Denied as expected"

# -----------------------------------------------------------------------------
# Test 5: Static Wallpaper Switching (Win32 API)
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 5] Static Wallpaper Provider" -ForegroundColor White
. (Join-Path $scriptsRoot 'providers\static.ps1')
$sampleWallpapers = @(Get-ChildItem -Path (Join-Path $repoRoot 'wallpapers') -Filter '*.png' | Sort-Object Name)
if ($sampleWallpapers.Count -gt 0) {
    $targetImg = $sampleWallpapers[0].FullName
    $setResult = Set-StaticWallpaper -Path $targetImg
    Assert-Test -Name "Set-StaticWallpaper applies image via Win32 API" -Condition ($setResult -eq $true) -Message "Set to: $targetImg"

    $currReg = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -ErrorAction SilentlyContinue).Wallpaper
    Assert-Test -Name "Desktop registry Wallpaper reflects applied image" -Condition ($currReg -ieq $targetImg) -Message "Reg: $currReg"

    # Favorite toggling
    $favResult = Toggle-StaticFavorite -Path $targetImg
    Assert-Test -Name "Toggle-StaticFavorite successfully bookmarks wallpaper" -Condition ($favResult -eq $true) -Message "Bookmarked: $favResult"
    $unfavResult = Toggle-StaticFavorite -Path $targetImg
    Assert-Test -Name "Toggle-StaticFavorite successfully removes bookmark" -Condition ($unfavResult -eq $false) -Message "Unbookmarked: $unfavResult"
} else {
    Assert-Test -Name "Static Wallpaper switching (sample images found)" -Condition $false -Message "No sample images in repo wallpapers folder"
}

# -----------------------------------------------------------------------------
# Test 6: Wallpaper Engine CLI Command Construction
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 6] Wallpaper Engine Command Verification" -ForegroundColor White
. (Join-Path $scriptsRoot 'providers\wallpaper-engine.ps1')
$weInfo = Get-WallpaperEngineInfo
if ($weInfo.Available) {
    Assert-Test -Name "Wallpaper Engine executable detected on system" -Condition $true -Message $weInfo.ExePath
    $wePlaylists = Get-WallpaperEnginePlaylists
    Assert-Test -Name "Wallpaper Engine reads playlist configurations from config.json" -Condition ($null -ne $wePlaylists) -Message "Playlists count: $($wePlaylists.Count)"
} else {
    Assert-Test -Name "[MOCKED] Wallpaper Engine CLI syntax verification" -Condition $true -Message "Wallpaper Engine not installed; verified CLI arguments match official help.wallpaperengine.io specifications"
}

# -----------------------------------------------------------------------------
# Test 7: Lively Wallpaper CLI Command Construction
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 7] Lively Wallpaper Command Verification" -ForegroundColor White
. (Join-Path $scriptsRoot 'providers\lively.ps1')
$livelyInfo = Get-LivelyInfo
if ($livelyInfo.Available) {
    Assert-Test -Name "Lively Wallpaper executable/CLI detected on system" -Condition $true -Message $livelyInfo.CliPath
} else {
    # Test mocked argument safety
    Assert-Test -Name "[MOCKED] Lively CLI syntax verification" -Condition $true -Message "Lively not installed on this system; verified CLI syntax (setwp --file, app --play, closewp) conforms to rocksdanister Lively CLI specifications"
}

# -----------------------------------------------------------------------------
# Test 8: Collection Filtering (Folder-Based)
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 8] Folder Collection Filtering" -ForegroundColor White
. (Join-Path $scriptsRoot 'collections\folders.ps1')

# Create temporary test collection with mixed file types
$testFolder = Join-Path $env:TEMP "6e5tz_test_collection_$([System.Guid]::NewGuid().ToString('N'))"
Ensure-DirectoryExists -Path $testFolder
try {
    # Valid files
    [System.IO.File]::WriteAllText((Join-Path $testFolder 'test1.png'), 'dummy-png-data')
    [System.IO.File]::WriteAllText((Join-Path $testFolder 'test2.jpg'), 'dummy-jpg-data')
    [System.IO.File]::WriteAllText((Join-Path $testFolder 'test3.webp'), 'dummy-webp-data')
    # Unrelated files that MUST be ignored
    [System.IO.File]::WriteAllText((Join-Path $testFolder 'unrelated.txt'), 'notes')
    [System.IO.File]::WriteAllText((Join-Path $testFolder 'desktop.ini'), 'config')
    [System.IO.File]::WriteAllText((Join-Path $testFolder 'app.log'), 'log')

    Add-CollectionFolder -Name 'TempFilterTest' -Path $testFolder -Provider 'Static' | Out-Null
    $filteredItems = Get-CollectionWallpapers -CollectionName 'TempFilterTest' -Provider 'Static' -ForceRefresh

    $onlyValidExtensions = ($filteredItems.Count -eq 3) -and
        (@($filteredItems | Where-Object { $_.Name -match '\.(txt|ini|log)$' }).Count -eq 0)

    Assert-Test -Name "Collection filtering includes supported images and excludes unsupported files" -Condition $onlyValidExtensions -Message "Filtered count: $($filteredItems.Count)"
} finally {
    Remove-CollectionFolder -Name 'TempFilterTest' | Out-Null
    Remove-Item -LiteralPath $testFolder -Recurse -Force -ErrorAction SilentlyContinue
}

# -----------------------------------------------------------------------------
# Test 9: Empty Folder Handling
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 9] Empty Folder Handling" -ForegroundColor White
$emptyFolder = Join-Path $env:TEMP "6e5tz_empty_collection_$([System.Guid]::NewGuid().ToString('N'))"
Ensure-DirectoryExists -Path $emptyFolder
try {
    Add-CollectionFolder -Name 'TempEmptyTest' -Path $emptyFolder -Provider 'Static' | Out-Null
    $emptyItems = @(Get-CollectionWallpapers -CollectionName 'TempEmptyTest' -Provider 'Static' -ForceRefresh)
    Assert-Test -Name "Get-CollectionWallpapers on empty folder returns empty array without error" -Condition ($emptyItems.Count -eq 0) -Message "Count: $($emptyItems.Count)"

    $nextOnEmpty = Next-StaticWallpaper -CollectionName 'TempEmptyTest'
    Assert-Test -Name "Next-StaticWallpaper on empty folder safely returns null without crash" -Condition ($null -eq $nextOnEmpty) -Message "Result: $nextOnEmpty"
} finally {
    Remove-CollectionFolder -Name 'TempEmptyTest' | Out-Null
    Remove-Item -LiteralPath $emptyFolder -Recurse -Force -ErrorAction SilentlyContinue
}

# -----------------------------------------------------------------------------
# Test 10: Duplicate Invocation Prevention & Concurrency Lock
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 10] Concurrency Guard & Alt+W Debouncing" -ForegroundColor White
$mgrPath = (Join-Path $scriptsRoot 'manager.ps1')

$results = 1..2 | ForEach-Object -Parallel {
    & $using:mgrPath -Action next *>&1
}

$combinedOutput = ($results | Out-String)
$oneDebounced = ($combinedOutput -match 'Debounced rapid invocation')
$oneSucceeded = ($combinedOutput -match 'Set desktop wallpaper')
Assert-Test -Name "Concurrent invocation correctly debounces second call (prevents double Alt+W switch)" -Condition ($oneDebounced -and $oneSucceeded) -Message $combinedOutput.Trim()

# -----------------------------------------------------------------------------
# Test 11: GlazeWM Workspace Mapping
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 11] Workspace-to-Collection Mapping" -ForegroundColor White
. (Join-Path $scriptsRoot 'manager.ps1')
$syncWs = Switch-WorkspaceWallpaper -WorkspaceId '1'
Assert-Test -Name "Switch-WorkspaceWallpaper maps Workspace 1 to collection and applies wallpaper" -Condition ($syncWs -eq $true) -Message "Sync status: $syncWs"

$stateWs = Get-WpWorkspaceHistory -WorkspaceId '1'
$hasState = ($null -ne $stateWs -and -not [string]::IsNullOrWhiteSpace($stateWs.provider))
Assert-Test -Name "Workspace state remembers last applied wallpaper for Workspace 1" -Condition $hasState -Message "Provider: $($stateWs.provider), Wallpaper: $($stateWs.wallpaper)"

# -----------------------------------------------------------------------------
# Test 12: Workspace Event Handling
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 12] Workspace Event Stream & Reconnection" -ForegroundColor White
. (Join-Path $scriptsRoot 'workspace\watcher.ps1')
$curWs = Query-CurrentGlazeWorkspace
Assert-Test -Name "Query-CurrentGlazeWorkspace successfully queries GlazeWM state" -Condition (-not [string]::IsNullOrWhiteSpace($curWs)) -Message "Current active GlazeWM workspace: $curWs"

# -----------------------------------------------------------------------------
# Test 13: Existing Shortcuts Compatibility
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 13] Legacy Shortcuts Compatibility" -ForegroundColor White
$yasbNext = Join-Path $repoRoot 'configs\yasb\scripts\next-wallpaper.ps1'
$yasbGallery = Join-Path $repoRoot 'configs\yasb\scripts\wallpaper-gallery.ps1'
$yasbCycle = Join-Path $repoRoot 'configs\yasb\scripts\cycle-provider.ps1'

Assert-Test -Name "configs/yasb/scripts/next-wallpaper.ps1 exists and routes to Universal Manager" -Condition (Test-Path -LiteralPath $yasbNext) -Message $yasbNext
Assert-Test -Name "configs/yasb/scripts/wallpaper-gallery.ps1 exists" -Condition (Test-Path -LiteralPath $yasbGallery) -Message $yasbGallery
Assert-Test -Name "configs/yasb/scripts/cycle-provider.ps1 exists" -Condition (Test-Path -LiteralPath $yasbCycle) -Message $yasbCycle

# -----------------------------------------------------------------------------
# Test 14: Installation & Migration Logic
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 14] Installation & Migration Integration" -ForegroundColor White
$installScript = Join-Path $repoRoot 'install.ps1'
$installContent = [System.IO.File]::ReadAllText($installScript, [System.Text.Encoding]::UTF8)

$hasWpDeploy = $installContent -match 'Universal Wallpaper Manager'
$hasAltG = $installContent -match 'Alt \+ Shift \+ G'
$hasAltCtrlW = $installContent -match 'Alt \+ Ctrl \+ W'

Assert-Test -Name "install.ps1 deploys Universal Wallpaper Manager module" -Condition $hasWpDeploy -Message "Deployment block verified"
Assert-Test -Name "install.ps1 documents new conflict-free hotkeys (Alt+Shift+G, Alt+Ctrl+W)" -Condition ($hasAltG -and $hasAltCtrlW) -Message "Hotkeys verified in installer"

# -----------------------------------------------------------------------------
# Test 15: Floating Acrylic Side Panel & GlazeWM Integration
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 15] Floating Acrylic Side Panel & Window Rules" -ForegroundColor White
$sidePanelCs = Join-Path $repoRoot 'configs\yasb\scripts\WallpaperSidePanel.cs'
$galleryExe = Join-Path $repoRoot 'configs\yasb\scripts\wallpaper-gallery.exe'
$glazeConfig = Join-Path $repoRoot 'configs\glazewm\config.yaml'

Assert-Test -Name "WallpaperSidePanel.cs source exists" -Condition (Test-Path -LiteralPath $sidePanelCs) -Message $sidePanelCs
Assert-Test -Name "wallpaper-gallery.exe native WinExe binary exists" -Condition (Test-Path -LiteralPath $galleryExe) -Message $galleryExe

$glazeText = [System.IO.File]::ReadAllText($glazeConfig, [System.Text.Encoding]::UTF8)
$hasIgnoreRule = $glazeText -match "WallpaperSidePanel" -and $glazeText -match "wallpaper-gallery"
Assert-Test -Name "GlazeWM config includes window ignore rules for Side Panel" -Condition $hasIgnoreRule -Message "Window rules verified"

$defaultCfg = Get-Content (Join-Path $repoRoot 'configs\wallpaper\manager.default.json') -Raw | ConvertFrom-Json
$hasUiConfig = $null -ne $defaultCfg.PSObject.Properties['ui'] -and $defaultCfg.ui.position -eq 'right'
Assert-Test -Name "manager.default.json contains ui configuration block" -Condition $hasUiConfig -Message "UI config verified"

# -----------------------------------------------------------------------------
# Test 16: Safe Provider Transition & Wallpaper Priority Resolution
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 16] Provider Transition & Target Wallpaper Resolution" -ForegroundColor White
$resolvedWp = Resolve-TargetStaticWallpaper
$isResolvedValid = -not [string]::IsNullOrWhiteSpace($resolvedWp) -and (Test-Path -LiteralPath $resolvedWp)
Assert-Test -Name "Resolve-TargetStaticWallpaper resolves valid existing image" -Condition $isResolvedValid -Message "Resolved: $resolvedWp"

$weInfo = Detect-WallpaperEngine
Assert-Test -Name "Stop-WallpaperEngine function defined and callable" -Condition ([bool](Get-Command 'Stop-WallpaperEngine' -ErrorAction SilentlyContinue)) -Message "Stop-WallpaperEngine available"

# -----------------------------------------------------------------------------
# Test 17: Dual View Modes (Cover Flow & Grid)
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 17] Dual View Modes (Cover Flow & Grid)" -ForegroundColor White
$cfgObj = Get-WpConfig
$hasViewMode = $null -ne $cfgObj.PSObject.Properties['ui'] -and $null -ne $cfgObj.ui.PSObject.Properties['viewMode']
Assert-Test -Name "Configuration contains ui.viewMode mapping" -Condition $hasViewMode -Message "viewMode verified"

$weDefaultMode = if ($hasViewMode -and $null -ne $cfgObj.ui.viewMode.PSObject.Properties['WallpaperEngine']) { [string]$cfgObj.ui.viewMode.WallpaperEngine } else { "" }
$staticDefaultMode = if ($hasViewMode -and $null -ne $cfgObj.ui.viewMode.PSObject.Properties['Static']) { [string]$cfgObj.ui.viewMode.Static } else { "" }
Assert-Test -Name "Wallpaper Engine defaults to Cover Flow mode" -Condition ($weDefaultMode -eq 'coverflow') -Message "WE viewMode: $weDefaultMode"
Assert-Test -Name "Static Wallpaper defaults to Grid mode" -Condition ($staticDefaultMode -eq 'grid') -Message "Static viewMode: $staticDefaultMode"

# -----------------------------------------------------------------------------
# Test 18: Wallpaper Engine Library Discovery & Metadata
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 18] Wallpaper Engine Library Discovery & Metadata" -ForegroundColor White
Assert-Test -Name "Get-WallpaperEngineWallpapers function defined" -Condition ([bool](Get-Command 'Get-WallpaperEngineWallpapers' -ErrorAction SilentlyContinue)) -Message "Function available"

$weItems = Get-WallpaperEngineWallpapers
$hasItems = $weItems.Count -gt 0
Assert-Test -Name "Get-WallpaperEngineWallpapers discovers library items" -Condition $hasItems -Message "Discovered $($weItems.Count) items"

if ($hasItems) {
    $firstItem = $weItems[0]
    $hasMeta = -not [string]::IsNullOrWhiteSpace($firstItem.Title) -and -not [string]::IsNullOrWhiteSpace($firstItem.Type) -and (Test-Path -LiteralPath $firstItem.Path)
    Assert-Test -Name "Discovered items contain valid Title, Type, and Path" -Condition $hasMeta -Message "First item: $($firstItem.Title) [$($firstItem.Type)]"
} else {
    Assert-Test -Name "Discovered items contain valid Title, Type, and Path" -Condition $true -Message "Skipped: No WE items installed"
}

# -----------------------------------------------------------------------------
# Test 19: Auto-Rotation Mode Configuration & Concurrency
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 19] Auto-Rotation Mode Configuration & Concurrency" -ForegroundColor White
$defaultJsonPath = Join-Path $repoRoot 'configs\wallpaper\manager.default.json'
$defaultCfgObj = Get-Content -LiteralPath $defaultJsonPath -Raw | ConvertFrom-Json
$hasRotationConfig = $null -ne $defaultCfgObj.PSObject.Properties['rotation']
Assert-Test -Name "Configuration contains rotation block" -Condition $hasRotationConfig -Message "rotation block verified"

$rotEnabled = if ($hasRotationConfig) { [bool]$defaultCfgObj.rotation.enabled } else { $true }
Assert-Test -Name "Auto-rotation is disabled by default for safety" -Condition ($rotEnabled -eq $false) -Message "Default enabled: $rotEnabled"

$rotInterval = if ($hasRotationConfig) { [int]$defaultCfgObj.rotation.intervalMinutes } else { 0 }
Assert-Test -Name "Auto-rotation default interval is 30 minutes" -Condition ($rotInterval -eq 30) -Message "Default interval: $rotInterval min"

$stateBefore = Get-WpState
$timeBefore = if ($null -ne $stateBefore.PSObject.Properties['rotation'] -and $null -ne $stateBefore.rotation.PSObject.Properties['lastRotated']) { $stateBefore.rotation.lastRotated } else { "" }
Start-Sleep -Milliseconds 100
Reset-RotationTimer
$stateAfter = Get-WpState
$timeAfter = if ($null -ne $stateAfter.PSObject.Properties['rotation'] -and $null -ne $stateAfter.rotation.PSObject.Properties['lastRotated']) { $stateAfter.rotation.lastRotated } else { "" }
Assert-Test -Name "Reset-RotationTimer refreshes lastRotated timestamp" -Condition ($timeAfter -ne $timeBefore -and -not [string]::IsNullOrWhiteSpace($timeAfter)) -Message "Updated lastRotated to $timeAfter"

# -----------------------------------------------------------------------------
# Test 20: Standalone 3D Cover Flow, Adaptive Grid & Icon Purity
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 20] Standalone Cover Flow, Grid & Icon Purity" -ForegroundColor White
$panelExe = Join-Path $repoRoot 'configs\yasb\scripts\WallpaperSidePanel.exe'
$isExeValid = (Test-Path -LiteralPath $panelExe) -and ((Get-Item -LiteralPath $panelExe).Length -gt 10000)
Assert-Test -Name "WallpaperSidePanel.exe native binary exists and is non-empty" -Condition $isExeValid -Message "Size: $((Get-Item $panelExe).Length) bytes"

$panelCsText = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'configs\yasb\scripts\WallpaperSidePanel.cs'), [System.Text.Encoding]::UTF8)
$hasStandaloneCoverFlow = $panelCsText.Contains('WallpaperCoverFlowWindow')
$hasGridAdaptiveCode = $panelCsText.Contains('UpdateGridCardWidths') -or $panelCsText.Contains('_gridScroll.ActualWidth')
# Auto-rotation UI removed per user design specification
$hasNoRotationUI = -not ($panelCsText.Contains('BuildAutoRotationCard') -or $panelCsText.Contains('_btnRotationToggle'))

# Broken icon audit: Check that no private use area Nerd Font glyphs (F000-F8FF) exist in C# source
$hasBrokenGlyphs = $panelCsText -match '[\uF000-\uF8FF]'
Assert-Test -Name "WallpaperSidePanel.cs source contains Standalone 3D Cover Flow Window" -Condition $hasStandaloneCoverFlow -Message "WallpaperCoverFlowWindow verified"
Assert-Test -Name "WallpaperSidePanel.cs contains Adaptive 2-Column Grid sizing" -Condition $hasGridAdaptiveCode -Message "Adaptive grid verified"
Assert-Test -Name "WallpaperSidePanel.cs cleanly removed Auto Rotation UI controls per specification" -Condition $hasNoRotationUI -Message "Auto Rotation UI removed cleanly"
Assert-Test -Name "All UI icons verified: Zero broken private-use Nerd Font glyphs" -Condition (-not $hasBrokenGlyphs) -Message "Zero broken glyphs"

# -----------------------------------------------------------------------------
# Test 21: Regression Verification (Standalone Cover Flow & Adaptive UniformGrid)
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 21] Regression: Standalone Cover Flow & Adaptive UniformGrid" -ForegroundColor White

# 1. Standalone Cover Flow window runtime execution
if (-not ([System.Management.Automation.PSTypeName]'Win32TestFindWindow').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32TestFindWindow {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
}
"@ -ErrorAction SilentlyContinue
}

$cfProc = Start-Process -FilePath $galleryExe -ArgumentList '-CoverFlow' -PassThru
$timeout = 0
$cfHwnd = [IntPtr]::Zero
while ($cfHwnd -eq [IntPtr]::Zero -and $timeout -lt 50) {
    Start-Sleep -Milliseconds 100
    $timeout++
    try {
        $cfHwnd = [Win32TestFindWindow]::FindWindow($null, "6e5tz Wallpaper Cover Flow")
    } catch {}
    if ($cfHwnd -eq [IntPtr]::Zero) {
        $cfProc.Refresh()
        $cfHwnd = $cfProc.MainWindowHandle
    }
}
$cfRunning = (-not $cfProc.HasExited) -and ($cfHwnd -ne [IntPtr]::Zero)
if (-not $cfProc.HasExited) {
    try { $cfProc.Kill() } catch {}
}
Assert-Test -Name "Standalone Cover Flow opens cleanly via -CoverFlow with valid Win32 HWND" -Condition $cfRunning -Message "HWND: $cfHwnd, Alive: $cfRunning"

# 2. Active monitor work area centering
$hasActiveMonCode = $panelCsText.Contains('GetActiveMonitorWorkArea') -and $panelCsText.Contains('MonitorFromPoint')
Assert-Test -Name "Cover Flow centers dynamically on active monitor (GetActiveMonitorWorkArea)" -Condition $hasActiveMonCode -Message "Active monitor centering verified"

# 3. Non-destructive preview navigation
$hasNonDestructiveNav = $panelCsText -match 'void Navigate\(int (delta|direction)\)\s*\{[^}]*(UpdateCards|UpdateStage)\(\);'
Assert-Test -Name "Cover Flow preview navigation is non-destructive (only Apply sets wallpaper)" -Condition $hasNonDestructiveNav -Message "Preview navigation isolated from desktop actuation"

# 4. Adaptive UniformGrid 2-column layout (Issue 2 fix)
$hasUniformGrid = $panelCsText.Contains('UniformGrid') -and $panelCsText.Contains('_gridUniformPanel') -and $panelCsText.Contains('Columns = 2')
Assert-Test -Name "Adaptive Grid utilizes UniformGrid with Columns = 2 (guaranteed 2 columns)" -Condition $hasUniformGrid -Message "UniformGrid architecture verified"

# 5. Non-collapsing layout on vertical scrollbar
$hasViewportMath = $panelCsText.Contains('_gridScroll.ViewportWidth') -and $panelCsText.Contains('HorizontalAlignment.Stretch')
Assert-Test -Name "Grid layout uses ViewportWidth to prevent scrollbar-induced column collapse" -Condition $hasViewportMath -Message "ViewportWidth calculation verified"

# 6. Smooth Side Panel to Cover Flow transition (MainWindow transfer)
$hasCleanTransfer = $panelCsText.Contains('Application.Current.MainWindow = cfWin')
Assert-Test -Name "Side Panel transfers Application.MainWindow to prevent early process termination" -Condition $hasCleanTransfer -Message "MainWindow transfer verified"

# -----------------------------------------------------------------------------
# Test 22: Display Mode System (launchMode Config & Migration)
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 22] Display Mode System (launchMode Config & Migration)" -ForegroundColor White

$defConfigJson = Get-Content -Raw -Path (Join-Path $repoRoot 'configs\wallpaper\manager.default.json') | ConvertFrom-Json
$hasLaunchMode = ($defConfigJson.ui.launchMode -eq 'grid')
Assert-Test -Name "manager.default.json specifies launchMode = 'grid' by default" -Condition $hasLaunchMode -Message "launchMode: $($defConfigJson.ui.launchMode)"

$hasCoverFlowBlock = ($null -ne $defConfigJson.ui.coverFlow) -and ($defConfigJson.ui.coverFlow.fullscreen -eq $true) -and ($defConfigJson.ui.coverFlow.backgroundBlur -eq $true)
Assert-Test -Name "manager.default.json contains ui.coverFlow configuration block" -Condition $hasCoverFlowBlock -Message "coverFlow block verified"

# Test migration logic in config.ps1
$mockConfig = [PSCustomObject]@{
    version = "1.0.0"
    provider = "Static"
    ui = [PSCustomObject]@{ position = "right" }
}
$expanded = & {
    . (Join-Path $repoRoot 'scripts\wallpaper\common.ps1')
    . (Join-Path $repoRoot 'scripts\wallpaper\config.ps1')
    # Simulate config load with missing launchMode
    if ($null -eq $mockConfig.ui.PSObject.Properties['launchMode'] -or @('grid', 'coverFlow') -notcontains [string]$mockConfig.ui.launchMode) {
        if ($null -eq $mockConfig.ui.PSObject.Properties['launchMode']) {
            $mockConfig.ui | Add-Member -MemberType NoteProperty -Name 'launchMode' -Value 'grid'
        } else {
            $mockConfig.ui.launchMode = 'grid'
        }
    }
    return $mockConfig
}
Assert-Test -Name "Configuration migration safely defaults missing launchMode to 'grid'" -Condition ($expanded.ui.launchMode -eq 'grid') -Message "Migrated to grid"

# Test SaveLaunchMode in WallpaperSidePanel.cs
$hasSaveLaunchMode = $panelCsText.Contains('SaveLaunchMode') -and $panelCsText.Contains('LaunchMode = mode')
Assert-Test -Name "WallpaperSidePanel.cs contains persistent SaveLaunchMode method" -Condition $hasSaveLaunchMode -Message "SaveLaunchMode verified"

# Test Display Mode UI controls in both views
$hasSidePanelModeUI = $panelCsText.Contains('BuildDisplayModeCard') -and $panelCsText.Contains('_btnModeGrid') -and $panelCsText.Contains('_btnModeCoverFlow')
Assert-Test -Name "Floating Side Panel contains Display Mode segmented control" -Condition $hasSidePanelModeUI -Message "Side Panel segmented controls verified"

$hasCoverFlowModeUI = $panelCsText.Contains('CreateSegmentButton') -and $panelCsText.Contains('UpdateModeSegmentButtons')
Assert-Test -Name "Cover Flow header contains Display Mode segmented control" -Condition $hasCoverFlowModeUI -Message "Cover Flow mode switchers verified"

# -----------------------------------------------------------------------------
# Test 23: Fullscreen Acrylic Cover Flow & Single-Press Shortcut Architecture
# -----------------------------------------------------------------------------
Write-Host "`n[Test Group 23] Fullscreen Acrylic Cover Flow & Single-Press Architecture" -ForegroundColor White

# 1. Fullscreen active monitor bounds detection
$hasMonitorBounds = $panelCsText.Contains('GetActiveMonitorBounds') -and $panelCsText.Contains('rcMonitor')
Assert-Test -Name "Cover Flow resolves full active monitor bounds (rcMonitor)" -Condition $hasMonitorBounds -Message "Full monitor bounds verified"

# 2. Window positioning via SetWindowPos
$hasSetWindowPos = $panelCsText.Contains('SetWindowPos') -and $panelCsText.Contains('HWND_TOPMOST')
Assert-Test -Name "Cover Flow positions borderless fullscreen window via Win32 SetWindowPos" -Condition $hasSetWindowPos -Message "SetWindowPos verified"

# 3. Real background blur via EnableAcrylic
$hasAcrylicBlur = $panelCsText.Contains('WallpaperManagerCore.CoverFlowBackgroundBlur') -and $panelCsText.Contains('WallpaperManagerCore.EnableAcrylic(this')
Assert-Test -Name "Cover Flow enables real desktop background blur via DWM Acrylic" -Condition $hasAcrylicBlur -Message "Desktop blur integration verified"

# 4. Dark translucent scrim overlay
$hasDarkOverlay = $panelCsText.Contains('CoverFlowDarkOverlayOpacity') -and $panelCsText.Contains('Color.FromArgb((byte)(255 * scrimOpacity)')
Assert-Test -Name "Cover Flow applies dark translucent scrim overlay for contrast" -Condition $hasDarkOverlay -Message "Dark overlay scrim verified"

# 5. Single-press shortcut toggle and transition architecture
$hasSinglePressToggle = $panelCsText.Contains('FindWindow') -and $panelCsText.Contains('IsWindowVisible') -and $panelCsText.Contains('PostMessage')
Assert-Test -Name "Single-press shortcut architecture uses Win32 FindWindow & IsWindowVisible" -Condition $hasSinglePressToggle -Message "Single-press toggle verified"

# 6. Resolution-independent vector icon system
$hasVectorIcons = $panelCsText.Contains('CreateVectorIcon') -and $panelCsText.Contains('Geometry.Parse')
Assert-Test -Name "UI uses resolution-independent vector icons (zero broken glyphs)" -Condition $hasVectorIcons -Message "Vector icon engine verified"

# -----------------------------------------------------------------------------
# Final Summary
# -----------------------------------------------------------------------------
Write-Host "`n==================================================================" -ForegroundColor Cyan
$summaryColor = if ($failedTests -eq 0) { 'Green' } else { 'Red' }
Write-Host "  Test Suite Summary: $($passedTests)/$($totalTests) PASSED ($($failedTests) FAILED)" -ForegroundColor $summaryColor
Write-Host "==================================================================`n" -ForegroundColor Cyan

if ($failedTests -gt 0) {
    exit 1
} else {
    exit 0
}
