import SwiftUI
import ServiceManagement

@main
struct TileKitApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("TileKit", systemImage: "rectangle.split.3x3") {
            MenuBarView()
                .environmentObject(appState)
                // Fix #4: OnboardingTrigger has access to openWindow environment value
                .background(OnboardingTrigger(appState: appState))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 500, minHeight: 400)
        }

        Window("Welcome to TileKit", id: "onboarding") {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                NSApp.windows.first { $0.identifier?.rawValue == "onboarding" }?.close()
            }
            .environmentObject(appState)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

// Fix #4: invisible view that opens the onboarding window via SwiftUI environment
private struct OnboardingTrigger: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .onAppear {
                if appState.needsOnboarding {
                    openWindow(id: "onboarding")
                    appState.needsOnboarding = false
                }
            }
    }
}

class AppState: ObservableObject {
    @Published var layouts: [GridLayout] = []
    @Published var isAccessibilityGranted = false
    @Published var launchAtLogin = false
    @Published var windows: [WindowInfo] = []
    @Published var needsOnboarding = false

    let accessibilityService = AccessibilityService()
    let hotkeyService = HotkeyService()
    let snapService = SnapService()

    private var servicesStarted = false

    init() {
        layouts = LayoutStore.load()
        isAccessibilityGranted = PermissionService.isTrusted()
        launchAtLogin = SMAppService.mainApp.status == .enabled

        if isAccessibilityGranted {
            startServices()
        } else if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            needsOnboarding = true
        }
    }

    func startServices() {
        guard !servicesStarted else { return }
        servicesStarted = true
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

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            // SMAppService requires signing; silently ignore in unsigned builds
        }
    }

    func tileWindow(to zone: LayoutZone) {
        accessibilityService.tileFocusedWindow(to: zone.rect)
    }

    func refreshWindows() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let fetched = self.accessibilityService.listWindows()
            DispatchQueue.main.async {
                self.windows = fetched
            }
        }
    }

    func tileWindow(_ info: WindowInfo, to zone: LayoutZone) {
        accessibilityService.tileWindow(info, to: zone.rect)
    }
}
