import Foundation
import CoreGraphics

enum SnapEdge: String, Codable, CaseIterable {
    case left, right, top, bottom
    case topLeft, topRight, bottomLeft, bottomRight
}

struct SnapRegion {
    var edge: SnapEdge
    var targetRect: UnitRect

    static let defaults: [SnapRegion] = [
        SnapRegion(edge: .left, targetRect: .leftHalf),
        SnapRegion(edge: .right, targetRect: .rightHalf),
        SnapRegion(edge: .top, targetRect: .fullScreen),
        SnapRegion(edge: .topLeft, targetRect: .topLeftQuarter),
        SnapRegion(edge: .topRight, targetRect: .topRightQuarter),
        SnapRegion(edge: .bottomLeft, targetRect: .bottomLeftQuarter),
        SnapRegion(edge: .bottomRight, targetRect: .bottomRightQuarter),
    ]
}
