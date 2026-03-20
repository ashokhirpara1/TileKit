import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            LayoutsSettingsView()
                .environmentObject(appState)
                .tabItem { Label("Layouts", systemImage: "rectangle.split.3x3") }

            ShortcutsSettingsView()
                .environmentObject(appState)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 550, height: 420)
    }
}

// MARK: - Layouts Tab

struct LayoutsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedLayout: GridLayout?
    @State private var showingEditor = false

    var body: some View {
        HSplitView {
            // Layout list
            VStack {
                List(appState.layouts, selection: $selectedLayout) { layout in
                    Text(layout.name)
                        .tag(layout)
                }
                .frame(minWidth: 150)

                HStack {
                    Button("+") { addLayout() }
                    Button("-") { removeSelected() }
                        .disabled(selectedLayout == nil)
                    Spacer()
                }
                .padding(4)
            }

            // Zone list for selected layout
            VStack {
                if let layout = selectedLayout,
                   let index = appState.layouts.firstIndex(where: { $0.id == layout.id }) {
                    GridEditorView(layout: $appState.layouts[index])
                        .onChange(of: appState.layouts[index]) {
                            appState.saveLayouts()
                        }
                } else {
                    Text("Select a layout")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding()
    }

    private func addLayout() {
        let layout = GridLayout(name: "Custom", zones: [
            LayoutZone(name: "Left Half", rect: .leftHalf),
            LayoutZone(name: "Right Half", rect: .rightHalf),
        ])
        appState.layouts.append(layout)
        selectedLayout = layout
        appState.saveLayouts()
    }

    private func removeSelected() {
        guard let selected = selectedLayout else { return }
        appState.layouts.removeAll { $0.id == selected.id }
        selectedLayout = nil
        appState.saveLayouts()
    }
}

// MARK: - Shortcuts Tab

struct ShortcutsSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            ForEach(appState.layouts) { layout in
                Section(layout.name) {
                    ForEach(layout.zones) { zone in
                        if let layoutIdx = appState.layouts.firstIndex(where: { $0.id == layout.id }),
                           let zoneIdx = appState.layouts[layoutIdx].zones.firstIndex(where: { $0.id == zone.id }) {
                            HStack {
                                Text(zone.name)
                                Spacer()
                                HotkeyRecorderView(
                                    keyCombo: $appState.layouts[layoutIdx].zones[zoneIdx].shortcut
                                )
                                .frame(width: 140)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onChange(of: appState.layouts) {
            appState.saveLayouts()
        }
    }
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    // Fix #8: persist snapEnabled across restarts
    @AppStorage("snapEnabled") private var snapEnabled = true

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: Binding(
                get: { appState.launchAtLogin },
                set: { appState.setLaunchAtLogin($0) }
            ))

            Toggle("Enable drag-to-snap", isOn: $snapEnabled)
                .onChange(of: snapEnabled) { _, enabled in
                    if enabled {
                        appState.snapService.start(accessibilityService: appState.accessibilityService)
                    } else {
                        appState.snapService.stop()
                    }
                }

            Section {
                HStack {
                    Text("Accessibility:")
                    if appState.isAccessibilityGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Granted")
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Button("Grant") { PermissionService.requestPermission() }
                        Button("Check") { appState.checkPermission() }
                    }
                }
            }
        }
        .padding()
    }
}
