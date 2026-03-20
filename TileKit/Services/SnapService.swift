import AppKit

class SnapService {
    private var dragMonitor: Any?
    private var upMonitor: Any?
    private var overlayWindow: NSPanel?
    private var currentSnapRect: UnitRect?
    private var snapRegions = SnapRegion.defaults
    private weak var accessibilityService: AccessibilityService?
    private let threshold: CGFloat = 5

    func start(accessibilityService: AccessibilityService) {
        self.accessibilityService = accessibilityService

        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.handleDrag(event)
        }
        upMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.handleDrop(event)
        }
    }

    func stop() {
        if let monitor = dragMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = upMonitor { NSEvent.removeMonitor(monitor) }
        dragMonitor = nil
        upMonitor = nil
        hideOverlay()
    }

    private func handleDrag(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else { return }

        if let edge = detectSnapEdge(mouseLocation: mouseLocation, screen: screen) {
            let region = snapRegions.first { $0.edge == edge }
            if let rect = region?.targetRect {
                currentSnapRect = rect
                showOverlay(for: rect, on: screen)
                return
            }
        }

        currentSnapRect = nil
        hideOverlay()
    }

    private func handleDrop(_ event: NSEvent) {
        guard let rect = currentSnapRect else { return }
        hideOverlay()
        accessibilityService?.tileFocusedWindow(to: rect)
        currentSnapRect = nil
    }

    private func detectSnapEdge(mouseLocation: NSPoint, screen: NSScreen) -> SnapEdge? {
        let f = screen.frame
        let nearLeft = mouseLocation.x - f.minX < threshold
        let nearRight = f.maxX - mouseLocation.x < threshold
        let nearTop = f.maxY - mouseLocation.y < threshold
        let nearBottom = mouseLocation.y - f.minY < threshold

        if nearLeft && nearTop { return .topLeft }
        if nearRight && nearTop { return .topRight }
        if nearLeft && nearBottom { return .bottomLeft }
        if nearRight && nearBottom { return .bottomRight }
        if nearLeft { return .left }
        if nearRight { return .right }
        if nearTop { return .top }
        if nearBottom { return .bottom }
        return nil
    }

    private func showOverlay(for unitRect: UnitRect, on screen: NSScreen) {
        let visible = screen.visibleFrame
        let frame = CGRect(
            x: visible.origin.x + unitRect.x * visible.width,
            y: visible.origin.y + (1.0 - unitRect.y - unitRect.height) * visible.height,
            width: unitRect.width * visible.width,
            height: unitRect.height * visible.height
        )

        if overlayWindow == nil {
            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isOpaque = false
            panel.hasShadow = false
            panel.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15)
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

            let borderView = NSView(frame: panel.contentView!.bounds)
            borderView.autoresizingMask = [.width, .height]
            borderView.wantsLayer = true
            borderView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
            borderView.layer?.borderWidth = 2
            borderView.layer?.cornerRadius = 8
            panel.contentView?.addSubview(borderView)

            overlayWindow = panel
        }

        overlayWindow?.setFrame(frame, display: true)
        overlayWindow?.orderFront(nil)
    }

    private func hideOverlay() {
        overlayWindow?.orderOut(nil)
    }

    deinit {
        stop()
    }
}
