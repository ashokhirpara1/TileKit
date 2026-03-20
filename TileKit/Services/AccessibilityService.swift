import AppKit
import ApplicationServices

class AccessibilityService {

    private var previousFrontmostApp: AXUIElement?
    private var observer: NSObjectProtocol?

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func startObservingFrontmostApp() {
        // Guard against duplicate registration (fix #5 / #6)
        guard observer == nil else { return }
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
        if let prevApp = previousFrontmostApp {
            var focusedWindow: AnyObject?
            if AXUIElementCopyAttributeValue(prevApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
               focusedWindow != nil {
                return (focusedWindow as! AXUIElement)
            }
        }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              focusedApp != nil else { return nil }
        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              focusedWindow != nil else { return nil }
        return (focusedWindow as! AXUIElement)
    }

    func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success,
              value != nil else { return nil }
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
        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        moveWindow(window, to: resolveRect(unitRect, on: screen))
    }

    // Fix #1: match by CGWindowID instead of title (handles untitled + duplicate-title windows)
    // kAXWindowIDAttribute is not in the public SDK headers — use the string literal directly
    private let kAXWindowID = "AXWindowID" as CFString

    func tileWindow(_ info: WindowInfo, to unitRect: UnitRect) {
        let axApp = AXUIElementCreateApplication(info.pid)
        var windowsRef: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement] else { return }

        let target = axWindows.first { axWindow in
            var idRef: AnyObject?
            guard AXUIElementCopyAttributeValue(axWindow, kAXWindowID, &idRef) == .success,
                  idRef != nil else { return false }
            return (idRef as! CGWindowID) == info.id
        } ?? axWindows.first

        guard let window = target else { return }
        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        moveWindow(window, to: resolveRect(unitRect, on: screen))
    }

    func resolveRect(_ unitRect: UnitRect, on screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        // Fix #7: safe primary screen height access
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height

        let screenX = visible.origin.x + unitRect.x * visible.width
        let screenY = visible.origin.y + (1.0 - unitRect.y - unitRect.height) * visible.height
        let width = unitRect.width * visible.width
        let height = unitRect.height * visible.height
        let flippedY = primaryHeight - screenY - height

        return CGRect(x: screenX, y: flippedY, width: width, height: height)
    }

    func screenForWindow(_ window: AXUIElement) -> NSScreen? {
        guard let position = getWindowPosition(window) else { return nil }
        // Fix #7: safe primary screen height access
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let bottomLeftY = primaryHeight - position.y
        return NSScreen.screens.first { screen in
            screen.frame.contains(CGPoint(x: position.x + 50, y: bottomLeftY - 10))
        }
    }
}
