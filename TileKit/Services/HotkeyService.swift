import CoreGraphics
import AppKit

class HotkeyService {
    private var eventTap: CFMachPort?
    private var shortcuts: [(KeyCombo, UnitRect)] = []
    private weak var accessibilityService: AccessibilityService?

    func start(layouts: [GridLayout], accessibilityService: AccessibilityService) {
        self.accessibilityService = accessibilityService
        updateLayouts(layouts)
        installEventTap()
    }

    func updateLayouts(_ layouts: [GridLayout]) {
        shortcuts = layouts.flatMap { layout in
            layout.zones.compactMap { zone in
                guard let combo = zone.shortcut else { return nil }
                return (combo, zone.rect)
            }
        }
    }

    private func installEventTap() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout {
                if let tap = service.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passRetained(event)
            }

            return service.handleKeyEvent(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            print("Failed to create event tap. Check Accessibility permissions.")
            return
        }

        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleKeyEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        for (combo, rect) in shortcuts {
            if combo.matches(keyCode: keyCode, flags: flags) {
                DispatchQueue.main.async { [weak self] in
                    self?.accessibilityService?.tileFocusedWindow(to: rect)
                }
                return nil // swallow the event
            }
        }

        return Unmanaged.passRetained(event)
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
}
