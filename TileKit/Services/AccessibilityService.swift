import AppKit
import ApplicationServices

class AccessibilityService {

    private var previousFrontmostApp: AXUIElement?
    private var observer: NSObjectProtocol?

    func startObservingFrontmostApp() {
        let tileKitBundleID = Bundle.main.bundleIdentifier
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != tileKitBundleID else { return }
            self?.previousFrontmostApp = AXUIElementCreateApplication(app.processIdentifier)
        }
    }

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
                rawTitle: rawTitle,
                windowTitle: windowTitle,
                appName: appName,
                appIcon: icon
            ))
        }

        return results
    }

    func getFocusedWindow() -> AXUIElement? {
        // Use previously frontmost app to avoid returning TileKit's own window
        if let prevApp = previousFrontmostApp {
            var focusedWindow: AnyObject?
            if AXUIElementCopyAttributeValue(prevApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success {
                return (focusedWindow as! AXUIElement)
            }
        }
        // Fallback: system-wide focused app
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
            return nil
        }
        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success else {
            return nil
        }
        return (focusedWindow as! AXUIElement)
    }

    func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success else {
            return nil
        }
        var point = CGPoint.zero
        AXValueGetValue(value as! AXValue, .cgPoint, &point)
        return point
    }

    func moveWindow(_ window: AXUIElement, to rect: CGRect) {
        var position = rect.origin
        var size = rect.size

        if let posValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    func tileFocusedWindow(to unitRect: UnitRect) {
        guard let window = getFocusedWindow() else { return }

        // Determine which screen the window is on
        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
        let pixelRect = resolveRect(unitRect, on: screen)
        moveWindow(window, to: pixelRect)
    }

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
            return title == info.rawTitle
        } ?? axWindows.first  // fallback: use first window if title match fails

        guard let window = target else { return }
        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
        let pixelRect = resolveRect(unitRect, on: screen)
        moveWindow(window, to: pixelRect)
    }

    func resolveRect(_ unitRect: UnitRect, on screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        let primaryHeight = NSScreen.screens[0].frame.height

        // Calculate in screen coordinates (bottom-left origin)
        let screenX = visible.origin.x + unitRect.x * visible.width
        let screenY = visible.origin.y + (1.0 - unitRect.y - unitRect.height) * visible.height
        let width = unitRect.width * visible.width
        let height = unitRect.height * visible.height

        // Flip Y for AXUIElement (top-left origin)
        let flippedY = primaryHeight - screenY - height

        return CGRect(x: screenX, y: flippedY, width: width, height: height)
    }

    func screenForWindow(_ window: AXUIElement) -> NSScreen? {
        guard let position = getWindowPosition(window) else { return nil }
        // AX position is top-left origin, convert to bottom-left for NSScreen
        let primaryHeight = NSScreen.screens[0].frame.height
        let bottomLeftY = primaryHeight - position.y

        return NSScreen.screens.first { screen in
            screen.frame.contains(CGPoint(x: position.x + 50, y: bottomLeftY - 10))
        }
    }
}
