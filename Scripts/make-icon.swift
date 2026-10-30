// Draws the Spotiw app icon (a Touch Bar lit with album-colored bars above a row of keys)
// and writes Resources/AppIcon.icns and images/logo.png.
//   swift Scripts/make-icon.swift
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

let palette: [NSColor] = [0xFF5F6D, 0xFF8A3D, 0xFFC53D, 0x7BE08A, 0x4FC3F7, 0x8E7CFF, 0xE36BD8].map { color($0) }

func drawBars(in rect: NSRect, heights: [CGFloat], gapRatio: CGFloat) {
    let count = CGFloat(heights.count)
    let barWidth = rect.width / (count + (count - 1) * gapRatio)
    for (i, ratio) in heights.enumerated() {
        let height = rect.height * ratio
        let bar = NSRect(x: rect.minX + CGFloat(i) * barWidth * (1 + gapRatio), y: rect.midY - height / 2,
                         width: barWidth, height: height)
        palette[i % palette.count].setFill()
        NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
    }
}

func renderIcon(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels) / 1024

    // macOS icon grid: an 824 pt rounded square centered in 1024, with a soft shadow
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28 * s
    shadow.shadowOffset = NSSize(width: 0, height: -12 * s)
    shadow.set()
    color(0x16161A).setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSGradient(starting: color(0x3A3A3F), ending: color(0x16161A))!.draw(in: tile, angle: -90)

    // the Touch Bar
    let strip = NSRect(x: 130 * s, y: 560 * s, width: 764 * s, height: 190 * s)
    let stripPath = NSBezierPath(roundedRect: strip, xRadius: 40 * s, yRadius: 40 * s)
    color(0x000000).setFill()
    stripPath.fill()
    color(0xFFFFFF, 0.10).setStroke()
    stripPath.lineWidth = 4 * s
    stripPath.stroke()

    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowBlurRadius = 24 * s
    glow.shadowColor = color(0xE36BD8, 0.5)
    glow.set()
    drawBars(in: strip.insetBy(dx: 60 * s, dy: 34 * s),
             heights: [0.35, 0.7, 0.5, 0.95, 0.6, 1.0, 0.55, 0.8, 0.4], gapRatio: 0.6)
    NSGraphicsContext.restoreGraphicsState()

    // two rows of keys, the lower one offset like a keyboard
    let keyWidth = 150 * s, keyHeight = 130 * s, gap = 28 * s
    for row in 0..<2 {
        for i in 0..<5 {
            let x = 130 * s + CGFloat(i) * (keyWidth + gap) - (row == 1 ? 60 * s : 0)
            let key = NSBezierPath(roundedRect: NSRect(x: x, y: 380 * s - CGFloat(row) * (keyHeight + gap),
                                                       width: keyWidth, height: keyHeight),
                                   xRadius: 22 * s, yRadius: 22 * s)
            color(0x0E0E10).setFill()
            key.fill()
            color(0xFFFFFF, 0.06).setStroke()
            key.lineWidth = 3 * s
            key.stroke()
        }
    }

    // soft highlight on the top half
    NSGradient(starting: NSColor.white.withAlphaComponent(0.10), ending: NSColor.white.withAlphaComponent(0))!
        .draw(in: NSRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try! renderIcon(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try! renderIcon(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()

try! renderIcon(pixels: 512).write(to: root.appendingPathComponent("images/logo.png"))
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns and images/logo.png" : "iconutil failed")
