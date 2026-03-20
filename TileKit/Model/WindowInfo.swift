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
