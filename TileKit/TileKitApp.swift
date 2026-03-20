import SwiftUI

@main
struct TileKitApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("TileKit", systemImage: "rectangle.split.3x3") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 500, minHeight: 400)
        }
    }
}

class AppState: ObservableObject {
    @Published var layouts: [GridLayout] = []
    @Published var isAccessibilityGranted = false

    let accessibilityService = AccessibilityService()
    let hotkeyService = HotkeyService()
    let snapService = SnapService()

    init() {
        layouts = LayoutStore.load()
        isAccessibilityGranted = PermissionService.isTrusted()

        if isAccessibilityGranted {
            startServices()
        }
    }

    func startServices() {
        accessibilityService.startObservingFrontmostApp()
        hotkeyService.start(layouts: layouts, accessibilityService: accessibilityService)
        snapService.start(accessibilityService: accessibilityService)
    }

    func checkPermission() {
        isAccessibilityGranted = PermissionService.isTrusted()
        if isAccessibilityGranted {
            startServices()
        }
    }

    func saveLayouts() {
        LayoutStore.save(layouts)
        hotkeyService.updateLayouts(layouts)
    }

    func tileWindow(to zone: LayoutZone) {
        accessibilityService.tileFocusedWindow(to: zone.rect)
    }

    @Published var windows: [WindowInfo] = []

    func refreshWindows() {
        windows = accessibilityService.listWindows()
    }

    func tileWindow(_ info: WindowInfo, to zone: LayoutZone) {
        accessibilityService.tileWindow(info, to: zone.rect)
    }
}
