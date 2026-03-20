import SwiftUI
import AppKit

struct HotkeyRecorderView: View {
    @Binding var keyCombo: KeyCombo?
    @State private var isRecording = false

    var body: some View {
        HStack {
            if isRecording {
                Text("Press keys...")
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.accentColor, lineWidth: 1)
                    )
            } else {
                Button(action: { isRecording = true }) {
                    Text(keyCombo?.displayString ?? "None")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if keyCombo != nil {
                Button(action: { keyCombo = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .background(
            isRecording ? KeyCaptureView(isRecording: $isRecording, keyCombo: $keyCombo) : nil
        )
    }
}

struct KeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var keyCombo: KeyCombo?

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onCapture = { combo in
            keyCombo = combo
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {}
}

class KeyCaptureNSView: NSView {
    var onCapture: ((KeyCombo) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
            return
        }

        let combo = KeyCombo(
            keyCode: event.keyCode,
            control: event.modifierFlags.contains(.control),
            option: event.modifierFlags.contains(.option),
            shift: event.modifierFlags.contains(.shift),
            command: event.modifierFlags.contains(.command)
        )

        // Require at least one modifier
        if combo.control || combo.option || combo.shift || combo.command {
            onCapture?(combo)
        }
    }
}
