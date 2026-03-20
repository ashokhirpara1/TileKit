import Foundation

enum LayoutStore {
    private static let key = "TileKit.layouts"

    static func load() -> [GridLayout] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let layouts = try? JSONDecoder().decode([GridLayout].self, from: data) else {
            return Self.defaultLayouts
        }
        return layouts
    }

    static func save(_ layouts: [GridLayout]) {
        if let data = try? JSONEncoder().encode(layouts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static let defaultLayouts: [GridLayout] = [
        GridLayout(name: "Halves", zones: [
            LayoutZone(name: "Left Half", rect: .leftHalf,
                      shortcut: KeyCombo(keyCode: 123, control: true, option: true, shift: false, command: false)),
            LayoutZone(name: "Right Half", rect: .rightHalf,
                      shortcut: KeyCombo(keyCode: 124, control: true, option: true, shift: false, command: false)),
            LayoutZone(name: "Top Half", rect: .topHalf,
                      shortcut: KeyCombo(keyCode: 126, control: true, option: true, shift: false, command: false)),
            LayoutZone(name: "Bottom Half", rect: .bottomHalf,
                      shortcut: KeyCombo(keyCode: 125, control: true, option: true, shift: false, command: false)),
        ]),
        GridLayout(name: "Thirds", zones: [
            LayoutZone(name: "Left Third", rect: .leftThird,
                      shortcut: KeyCombo(keyCode: 2, control: true, option: true, shift: false, command: false)),
            LayoutZone(name: "Center Third", rect: .centerThird,
                      shortcut: KeyCombo(keyCode: 3, control: true, option: true, shift: false, command: false)),
            LayoutZone(name: "Right Third", rect: .rightThird,
                      shortcut: KeyCombo(keyCode: 5, control: true, option: true, shift: false, command: false)),
        ]),
        GridLayout(name: "Quarters", zones: [
            LayoutZone(name: "Top Left", rect: .topLeftQuarter,
                      shortcut: KeyCombo(keyCode: 32, control: true, option: true, shift: false, command: false)),
            LayoutZone(name: "Top Right", rect: .topRightQuarter,
                      shortcut: KeyCombo(keyCode: 34, control: true, option: true, shift: false, command: false)),
            LayoutZone(name: "Bottom Left", rect: .bottomLeftQuarter,
                      shortcut: KeyCombo(keyCode: 38, control: true, option: true, shift: false, command: false)),
            LayoutZone(name: "Bottom Right", rect: .bottomRightQuarter,
                      shortcut: KeyCombo(keyCode: 40, control: true, option: true, shift: false, command: false)),
        ]),
        GridLayout(name: "Two Thirds + Third", zones: [
            LayoutZone(name: "Left 2/3", rect: UnitRect(x: 0, y: 0, width: 2.0/3, height: 1)),
            LayoutZone(name: "Right 1/3", rect: UnitRect(x: 2.0/3, y: 0, width: 1.0/3, height: 1)),
        ]),
        GridLayout(name: "Full Screen", zones: [
            LayoutZone(name: "Full Screen", rect: .fullScreen,
                      shortcut: KeyCombo(keyCode: 36, control: true, option: true, shift: false, command: false)),
        ]),
    ]
}
