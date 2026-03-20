# TileKit

> A lightweight macOS window tiling app that lives in your menu bar.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

TileKit lets you tile **any open window** to any layout — halves, thirds, quarters, custom grids — with a click or hotkey. Unlike macOS's built-in tiling, you pick the window and the zone independently.

---

## Why TileKit?

macOS Sequoia introduced native window tiling, but it has real limitations:

| | macOS Built-in | TileKit |
|---|---|---|
| Tile any open window | ❌ Must drag to edge or use green button | ✅ Pick any window from a list |
| Thirds & quarters | ❌ Halves only | ✅ Thirds, quarters, two-thirds, custom |
| Custom layouts | ❌ Fixed presets only | ✅ Define your own zones and ratios |
| Hotkeys for any layout | ❌ Limited | ✅ Assign shortcuts to any zone |
| Works on macOS 14 | ❌ Tiling is macOS 15+ only | ✅ Works from macOS 14 (Sonoma) |
| Menu bar control | ❌ No | ✅ One click from menu bar |

**The core problem:** macOS tiling requires you to already have the window focused and visible. If you want to arrange 3 windows at once, you have to switch to each one individually. TileKit lets you tile any window from wherever you are — no switching, no dragging.

---

## Screenshots

### Window Picker
Select any open window on the left, pick a layout zone on the right.

```
┌─────────────────────────┬──────────────────────────┐
│  Google Chrome          │  Halves                  │
│    Google Chrome        │  [▌ ] [ ▐] [══] [  ═]   │
│  Code                   │                          │
│  ▶ Code          ←sel   │  Thirds                  │
│    Code – 2             │  [▌ ] [│ ] [ ▐]          │
│  Brave Browser          │                          │
│    Brave Browser        │  Quarters                │
│                         │  [▘ ] [▝ ] [▖ ] [▗ ]    │
├─────────────────────────┴──────────────────────────┤
│  Settings...                          Quit TileKit  │
└────────────────────────────────────────────────────┘
```

---

## Features

- **Pick any window** — not just the frontmost one
- **All layouts** — halves, thirds, quarters, two-thirds + third, full screen
- **Hotkeys** — assign keyboard shortcuts to any zone
- **Drag-to-snap** — drag a window to a screen edge to snap it
- **Multi-display aware** — tiles to whichever screen the window is on
- **Launch at Login** — starts automatically with macOS
- **Zero bloat** — lives in the menu bar, no Dock icon

---

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac

---

## Installation

### Download (Recommended)

1. Go to [Releases](https://github.com/ashokhirpara1/TileKit/releases/latest)
2. Download `TileKit-x.x.dmg`
3. Open the DMG and drag **TileKit.app** to your **Applications** folder
4. On first launch: **right-click → Open** to bypass Gatekeeper (unsigned build)

> **Why the warning?** Code signing requires an Apple Developer account ($99/year). TileKit is unsigned but fully open source — you can inspect and build it yourself.

### Homebrew (coming soon)
```bash
brew install --cask tilekit --no-quarantine
```

### Build from Source
```bash
git clone https://github.com/ashokhirpara1/TileKit.git
cd TileKit
bash scripts/build.sh 1.0
# Output: dist/TileKit-1.0.dmg
```

---

## Usage

### First Launch
TileKit will ask for **Accessibility permission** — this is required to move and resize windows. Grant it in **System Settings → Privacy & Security → Accessibility**.

### Tiling a Window
1. Click the **TileKit icon** in the menu bar
2. Select a **window** from the left panel
3. Click a **layout zone** on the right

### Hotkeys
Open **Settings → Shortcuts** to assign hotkeys to any zone. Hotkeys always tile the frontmost window.

### Layouts
Open **Settings → Layouts** to add, remove, or customize layouts and zones. Each zone is defined as a fraction of the screen (e.g. left third = x:0, width:1/3).

---

## Building

```bash
# Install Swift (comes with Xcode or Command Line Tools)
xcode-select --install

# Clone
git clone https://github.com/ashokhirpara1/TileKit.git
cd TileKit

# Build debug (for development)
xcodebuild -scheme TileKit -destination "platform=macOS" build

# Build release DMG
bash scripts/build.sh 1.0

# Regenerate app icon
swift scripts/make_icon.swift TileKit/TileKit/Resources
```

---

## Project Structure

```
TileKit/
├── TileKit/
│   ├── TileKitApp.swift          # App entry point, AppState
│   ├── TileKit.entitlements      # Accessibility entitlements
│   ├── Model/
│   │   ├── GridLayout.swift      # Layout, LayoutZone, UnitRect
│   │   ├── WindowInfo.swift      # Open window metadata
│   │   └── KeyCombo.swift        # Hotkey model
│   ├── Services/
│   │   ├── AccessibilityService.swift  # AX API: list/move windows
│   │   ├── HotkeyService.swift         # Global hotkey listener
│   │   ├── SnapService.swift           # Drag-to-snap
│   │   └── PermissionService.swift     # Accessibility permission check
│   ├── Views/
│   │   ├── MenuBarView.swift     # Two-panel window picker
│   │   ├── OnboardingView.swift  # First-launch setup
│   │   ├── SettingsView.swift    # Settings window
│   │   ├── GridEditorView.swift  # Layout editor
│   │   └── HotkeyRecorderView.swift
│   └── Utilities/
│       └── Defaults.swift        # UserDefaults keys
├── scripts/
│   ├── build.sh                  # Release build + DMG packaging
│   └── make_icon.swift           # Programmatic icon generator
└── .github/
    └── workflows/
        └── release.yml           # Auto-release on git tag push
```

---

## How It Works

**Layouts** are stored as unit rectangles (fractions of 0–1). When you tile a window, TileKit:

1. Finds the `AXUIElement` for the target window by its `CGWindowID`
2. Detects which screen the window is on via `NSScreen`
3. Multiplies the unit rect fractions by `screen.visibleFrame` to get pixel coordinates
4. Calls `AXUIElementSetAttributeValue` to move and resize the window

This means layouts automatically adapt to any screen resolution or multi-display setup.

---

## Contributing

Pull requests are welcome. For major changes, open an issue first.

```bash
git clone https://github.com/ashokhirpara1/TileKit.git
cd TileKit
# make your changes
xcodebuild -scheme TileKit -destination "platform=macOS" build
```

---

## License

[MIT](LICENSE)

---

## Support

If TileKit saves you time every day, consider buying me a coffee ☕

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-support-yellow?logo=buy-me-a-coffee)](https://buymeacoffee.com/ashokhirpara)

Every coffee helps keep this project maintained and free for everyone.
