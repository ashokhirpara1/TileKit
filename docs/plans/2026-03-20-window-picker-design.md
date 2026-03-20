# Window Picker Design
Date: 2026-03-20

## Goal
Replace the current menu bar popup (which only tiles the frontmost window) with a side-by-side UI: pick any open window on the left, pick a layout zone on the right.

## Data Layer

### `WindowInfo` struct
```swift
struct WindowInfo {
    let pid: pid_t
    let windowTitle: String
    let appName: String
    let appIcon: NSImage
}
```

### `AccessibilityService.listWindows() -> [WindowInfo]`
- Uses `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`
- Filters: layer == 0, excludes TileKit's own PID
- Falls back to "AppName – N" for untitled windows
- Groups results by app for display

### `AccessibilityService.tileWindow(_ info: WindowInfo, to rect: UnitRect)`
- Creates `AXUIElementCreateApplication(info.pid)`
- Reads `kAXWindowsAttribute` to find the AX window matching `info.windowTitle`
- Calls existing `moveWindow(_:to:)` — silently no-ops if window no longer exists

## UI Layout

Popover width: ~460px. Two panels side-by-side, divided by a `Divider()`.

### Left panel (~200px) — Window List
- Scrollable
- App name + icon as section header
- Window titles as selectable rows
- Selected row: accent color highlight
- Empty state: "No windows open" in secondary text

### Right panel (~240px) — Zone Grid
- All layout zones shown as clickable `ZonePreview` tiles, grouped by layout name
- Zones dimmed + "Select a window" hint when nothing is selected
- Clicking a zone → tiles selected window → closes popover

### Bottom bar (full width)
- Settings and Quit buttons unchanged

## Edge Cases
- **No title**: fallback to "AppName – N"
- **Window closed between selection and click**: `tileWindow` silently no-ops
- **No open windows**: empty state message in left panel
- **Hotkeys**: unchanged — still tile frontmost window, bypass this UI entirely

## Files to Change
- `Services/AccessibilityService.swift` — add `listWindows()`, `tileWindow(_:to:)`
- `Views/MenuBarView.swift` — replace layout with two-panel side-by-side UI
- `TileKitApp.swift` — `AppState.tileWindow(to:)` updated to accept a `WindowInfo`
- `Model/WindowInfo.swift` — new file for the struct
