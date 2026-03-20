import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    var onComplete: () -> Void

    @State private var polling = false
    @State private var timer: Timer? = nil

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.split.3x3.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Welcome to TileKit")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("TileKit tiles your windows to any layout with a click or hotkey. It needs Accessibility access to move windows.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    featureRow(icon: "rectangle.lefthalf.filled", text: "Halves, thirds, quarters — any layout")
                    featureRow(icon: "filemenu.and.cursorarrow", text: "Pick any open window to tile")
                }
                HStack(spacing: 12) {
                    featureRow(icon: "keyboard", text: "Customizable hotkeys")
                    featureRow(icon: "menubar.rectangle", text: "Lives quietly in your menu bar")
                }
            }

            Divider()

            VStack(spacing: 10) {
                if polling {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Waiting for permission…")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button(action: grantPermission) {
                        Text("Grant Accessibility Access")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding(32)
        .frame(width: 440)
        .onDisappear { stopPolling() }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private func grantPermission() {
        PermissionService.requestPermission()
        polling = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if PermissionService.isTrusted() {
                stopPolling()
                appState.checkPermission()
                onComplete()
            }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
        polling = false
    }
}
