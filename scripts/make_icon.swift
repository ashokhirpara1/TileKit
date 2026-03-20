#!/usr/bin/env swift
// Generates AppIcon.icns for TileKit — draws a grid/tiling icon at all required sizes.
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]

func drawIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext

    // Background — rounded rect, dark
    let bg = NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                          xRadius: s * 0.18, yRadius: s * 0.18)
    NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1).setFill()
    bg.fill()

    // Draw a 2x2 grid of rounded tiles with a gap
    let pad = s * 0.14
    let gap = s * 0.06
    let tileW = (s - pad * 2 - gap) / 2
    let tileH = (s - pad * 2 - gap) / 2
    let r = s * 0.06

    let positions: [(CGFloat, CGFloat)] = [
        (pad, pad + tileH + gap),           // top-left
        (pad + tileW + gap, pad + tileH + gap), // top-right
        (pad, pad),                          // bottom-left
        (pad + tileW + gap, pad),            // bottom-right
    ]

    // Highlight one tile (top-left) in accent blue
    let accentColor = NSColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1)
    let dimColor = NSColor(red: 0.35, green: 0.35, blue: 0.40, alpha: 1)

    for (i, (x, y)) in positions.enumerated() {
        let rect = CGRect(x: x, y: y, width: tileW, height: tileH)
        let tile = NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r)
        (i == 0 ? accentColor : dimColor).setFill()
        tile.fill()
    }

    image.unlockFocus()
    return image
}

// Build iconset directory
let fm = FileManager.default
let projectDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath

let iconsetPath = "\(projectDir)/AppIcon.iconset"
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizeSpecs: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, filename) in sizeSpecs {
    let img = drawIcon(size: size)
    // Fix #10: use NSBitmapImageRep with explicit pixel dimensions and correct DPI
    // @2x files need 144 DPI so iconutil recognises the retina scale
    let isRetina = filename.contains("@2x")
    let dpi: CGFloat = isRetina ? 144 : 72
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: CGFloat(size) * 72 / dpi, height: CGFloat(size) * 72 / dpi)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size)))
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(filename)"))
    print("Generated \(filename) (\(size)px, \(Int(dpi))dpi)")
}

// Convert iconset → icns
let outputPath = "\(projectDir)/AppIcon.icns"
let result = Process()
result.launchPath = "/usr/bin/iconutil"
result.arguments = ["-c", "icns", iconsetPath, "-o", outputPath]
result.launch()
result.waitUntilExit()

try? fm.removeItem(atPath: iconsetPath)

if result.terminationStatus == 0 {
    print("✅ AppIcon.icns created at \(outputPath)")
} else {
    print("❌ iconutil failed")
    exit(1)
}
