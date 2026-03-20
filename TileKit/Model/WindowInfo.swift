import AppKit

struct WindowInfo: Identifiable, Equatable {
    let id: CGWindowID
    let pid: pid_t
    let rawTitle: String       // original title from CGWindowListCopyWindowInfo (may be empty)
    let windowTitle: String    // display title, with fallback for untitled windows
    let appName: String
    let appIcon: NSImage

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}
