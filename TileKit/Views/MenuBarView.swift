import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
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
        .onAppear {
            selectedWindow = nil
            appState.refreshWindows()
        }
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
            VStack(alignment: .leading, spacing: 0) {
                if selectedWindow == nil {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.secondary)
                        Text("Select a window")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
                }

                ForEach(appState.layouts) { layout in
                    Text(layout.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                    let columns = [GridItem(.adaptive(minimum: 44), spacing: 6)]
                    LazyVGrid(columns: columns, spacing: 6) {
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
    }

    private func zoneButton(_ zone: LayoutZone) -> some View {
        let disabled = selectedWindow == nil
        return Button(action: {
            guard let win = selectedWindow else { return }
            appState.tileWindow(win, to: zone)
            selectedWindow = nil
            // Close the popover
            dismiss()
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

struct ZonePreview: View {
    let rect: UnitRect

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.accentColor.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 1)
                        .strokeBorder(Color.accentColor, lineWidth: 1)
                )
                .frame(
                    width: geo.size.width * rect.width,
                    height: geo.size.height * rect.height
                )
                .offset(
                    x: geo.size.width * rect.x,
                    y: geo.size.height * rect.y
                )
        }
        .background(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
    }
}
