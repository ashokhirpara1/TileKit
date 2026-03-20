import Foundation
import CoreGraphics

struct UnitRect: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    static let fullScreen = UnitRect(x: 0, y: 0, width: 1, height: 1)
    static let leftHalf = UnitRect(x: 0, y: 0, width: 0.5, height: 1)
    static let rightHalf = UnitRect(x: 0.5, y: 0, width: 0.5, height: 1)
    static let topHalf = UnitRect(x: 0, y: 0, width: 1, height: 0.5)
    static let bottomHalf = UnitRect(x: 0, y: 0.5, width: 1, height: 0.5)

    static let leftThird = UnitRect(x: 0, y: 0, width: 1.0/3, height: 1)
    static let centerThird = UnitRect(x: 1.0/3, y: 0, width: 1.0/3, height: 1)
    static let rightThird = UnitRect(x: 2.0/3, y: 0, width: 1.0/3, height: 1)

    static let topLeftQuarter = UnitRect(x: 0, y: 0, width: 0.5, height: 0.5)
    static let topRightQuarter = UnitRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
    static let bottomLeftQuarter = UnitRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
    static let bottomRightQuarter = UnitRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
}

struct LayoutZone: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var rect: UnitRect
    var shortcut: KeyCombo?

    init(id: UUID = UUID(), name: String, rect: UnitRect, shortcut: KeyCombo? = nil) {
        self.id = id
        self.name = name
        self.rect = rect
        self.shortcut = shortcut
    }
}

struct GridLayout: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var zones: [LayoutZone]

    init(id: UUID = UUID(), name: String, zones: [LayoutZone]) {
        self.id = id
        self.name = name
        self.zones = zones
    }
}
