# Window Picker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the TileKit menu bar popup with a side-by-side window picker + zone grid so users can tile any open window, not just the frontmost one.

**Architecture:** Add a `WindowInfo` model and `listWindows()`/`tileWindow(_:to:)` methods to `AccessibilityService`. Update `AppState` to expose the window list. Rewrite `MenuBarView` as a two-panel HStack: scrollable window list on the left, zone grid on the right.

**Tech Stack:** SwiftUI, AppKit, CoreGraphics (`CGWindowListCopyWindowInfo`), Accessibility (`AXUIElement`)

---

### Task 1: Add `WindowInfo` model

**Files:**
- Create: `TileKit/TileKit/Model/WindowInfo.swift`

**Step 1: Create the file**

```swift
import AppKit

struct WindowInfo: Identifiable, Equatable {
    let id: CGWindowID
    let pid: pid_t
    let windowTitle: String
    let appName: String
    let appIcon: NSImage

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}
```

**Step 2: Build the project**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

**Step 3: Commit**

```bash
git add TileKit/TileKit/Model/WindowInfo.swift
git commit -m "feat: add WindowInfo model"
```

---

### Task 2: Add `listWindows()` to `AccessibilityService`

**Files:**
- Modify: `TileKit/TileKit/Services/AccessibilityService.swift`

**Step 1: Add the method after `startObservingFrontmostApp()`**

```swift
func listWindows() -> [WindowInfo] {
    let tileKitPID = ProcessInfo.processInfo.processIdentifier
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return []
    }

    // Build a lookup: pid -> NSRunningApplication
    var appByPID: [pid_t: NSRunningApplication] = [:]
    for app in NSWorkspace.shared.runningApplications {
        appByPID[app.processIdentifier] = app
    }

    var titleCounts: [pid_t: Int] = [:]
    var results: [WindowInfo] = []

    for entry in windowList {
        guard
            let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
            let pidNum = entry[kCGWindowOwnerPID as String] as? pid_t,
            pidNum != tileKitPID,
            let windowID = entry[kCGWindowNumber as String] as? CGWindowID,
            let app = appByPID[pidNum]
        else { continue }

        let appName = entry[kCGWindowOwnerName as String] as? String ?? "Unknown"
        let rawTitle = entry[kCGWindowName as String] as? String ?? ""

        // Build a unique title: fall back to "AppName – N" for untitled windows
        let windowTitle: String
        if rawTitle.isEmpty {
            titleCounts[pidNum, default: 0] += 1
            let n = titleCounts[pidNum]!
            windowTitle = n == 1 ? appName : "\(appName) – \(n)"
        } else {
            windowTitle = rawTitle
        }

        let icon = app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()

        results.append(WindowInfo(
            id: windowID,
            pid: pidNum,
            windowTitle: windowTitle,
            appName: appName,
            appIcon: icon
        ))
    }

    return results
}
```

**Step 2: Build**

`Cmd+B` — expected: no errors.

**Step 3: Commit**

```bash
git add TileKit/TileKit/Services/AccessibilityService.swift
git commit -m "feat: add listWindows() to AccessibilityService"
```

---

### Task 3: Add `tileWindow(_:to:)` to `AccessibilityService`

**Files:**
- Modify: `TileKit/TileKit/Services/AccessibilityService.swift`

**Step 1: Add method after `tileFocusedWindow(to:)`**

```swift
func tileWindow(_ info: WindowInfo, to unitRect: UnitRect) {
    let axApp = AXUIElementCreateApplication(info.pid)
    var windowsRef: AnyObject?
    guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
          let axWindows = windowsRef as? [AXUIElement] else { return }

    // Find the AX window whose title matches
    let target = axWindows.first { axWindow in
        var titleRef: AnyObject?
        guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
              let title = titleRef as? String else { return false }
        return title == info.windowTitle
    } ?? axWindows.first  // fallback: use first window if title match fails

    guard let window = target else { return }
    let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
    let pixelRect = resolveRect(unitRect, on: screen)
    moveWindow(window, to: pixelRect)
}
```

**Step 2: Build**

`Cmd+B` — expected: no errors.

**Step 3: Commit**

```bash
git add TileKit/TileKit/Services/AccessibilityService.swift
git commit -m "feat: add tileWindow(_:to:) to AccessibilityService"
```

---

### Task 4: Update `AppState`

**Files:**
- Modify: `TileKit/TileKit/TileKitApp.swift`

**Step 1: Add `windows` published property and update `tileWindow`**

Add inside `AppState`:

```swift
@Published var windows: [WindowInfo] = []

func refreshWindows() {
    windows = accessibilityService.listWindows()
}

func tileWindow(_ info: WindowInfo, to zone: LayoutZone) {
    accessibilityService.tileWindow(info, to: zone.rect)
}
```

Keep the existing `tileWindow(to zone: LayoutZone)` for hotkey use.

**Step 2: Build**

`Cmd+B` — expected: no errors.

**Step 3: Commit**

```bash
git add TileKit/TileKit/TileKitApp.swift
git commit -m "feat: expose windows list and tileWindow(_:to:) on AppState"
```

---

### Task 5: Rewrite `MenuBarView` as two-panel layout

**Files:**
- Modify: `TileKit/TileKit/Views/MenuBarView.swift`

**Step 1: Replace the entire file**

```swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedWindow: WindowInfo? = nil

    var body: some View {
        VStack(spacing: 0) {
            if !appState.isAccessibilityGranted {
                accessibilityPrompt
                    .padding(8)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    windowList
                        .frame(width: 200)

                    Divider()

                    zoneGrid
                        .frame(width: 240)
                }
                .frame(height: 320)
            }

            Divider()

            HStack {
                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)

                Spacer()

                Button("Quit TileKit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(width: 442)
        .onAppear { appState.refreshWindows() }
    }

    // MARK: - Window List

    private var windowList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if appState.windows.isEmpty {
                    Text("No windows open")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(12)
                } else {
                    let grouped = groupedWindows()
                    ForEach(grouped, id: \.appName) { group in
                        appHeader(group.appName, icon: group.icon)
                        ForEach(group.windows) { info in
                            windowRow(info)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func appHeader(_ name: String, icon: NSImage) -> some View {
        HStack(spacing: 4) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 14, height: 14)
            Text(name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private func windowRow(_ info: WindowInfo) -> some View {
        let isSelected = selectedWindow == info
        return Button(action: {
            selectedWindow = isSelected ? nil : info
        }) {
            Text(info.windowTitle)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    // MARK: - Zone Grid

    private var zoneGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(appState.layouts) { layout in
                    Text(layout.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], spacing: 6) {
                        ForEach(layout.zones) { zone in
                            zoneButton(zone)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            }
            .padding(.vertical, 4)
        }
        .overlay(
            Group {
                if selectedWindow == nil {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.secondary)
                        Text("Select a window")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        )
    }

    private func zoneButton(_ zone: LayoutZone) -> some View {
        let disabled = selectedWindow == nil
        return Button(action: {
            guard let win = selectedWindow else { return }
            appState.tileWindow(win, to: zone)
            selectedWindow = nil
            // Close the popover
            NSApp.keyWindow?.close()
        }) {
            ZonePreview(rect: zone.rect)
                .frame(width: 44, height: 30)
                .opacity(disabled ? 0.3 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(zone.name)
    }

    // MARK: - Accessibility prompt

    private var accessibilityPrompt: some View {
        VStack(spacing: 8) {
            Text("Accessibility permission required")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Grant Permission") {
                PermissionService.requestPermission()
            }

            Button("Check Again") {
                appState.checkPermission()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private struct AppGroup {
        let appName: String
        let icon: NSImage
        let windows: [WindowInfo]
    }

    private func groupedWindows() -> [AppGroup] {
        var order: [String] = []
        var map: [String: AppGroup] = [:]

        for info in appState.windows {
            if map[info.appName] == nil {
                order.append(info.appName)
                map[info.appName] = AppGroup(appName: info.appName, icon: info.appIcon, windows: [info])
            } else {
                map[info.appName] = AppGroup(
                    appName: info.appName,
                    icon: map[info.appName]!.icon,
                    windows: map[info.appName]!.windows + [info]
                )
            }
        }

        return order.compactMap { map[$0] }
    }
}
```

**Step 2: Build**

`Cmd+B` — expected: no errors.

**Step 3: Manual smoke test**
1. Run TileKit (`Cmd+R`)
2. Open Safari and Finder
3. Click TileKit menu bar icon
4. Verify: left panel shows Safari and Finder windows, right panel shows zones (dimmed)
5. Click a window → verify it highlights, zones become active
6. Click a zone → verify that window moves to that position

**Step 4: Commit**

```bash
git add TileKit/TileKit/Views/MenuBarView.swift
git commit -m "feat: replace menu with two-panel window picker + zone grid"
```

---

## Verification

1. Open 2+ apps with windows (e.g. Safari, Finder, VS Code)
2. Click TileKit menu bar icon
3. Left panel: groups windows by app with icons and titles
4. Click a window → highlighted in blue
5. Right panel: zones are now active (not dimmed)
6. Click a zone → that specific window tiles to that zone
7. Click another window, click another zone → tiles correctly
8. Hotkeys (if configured) still tile the frontmost window as before
9. Untitled windows appear as "AppName" or "AppName – 2"
