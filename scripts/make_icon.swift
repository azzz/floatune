// Draws the app icon and writes Resources/AppIcon.icns.
// Run from the repository root: swift scripts/make_icon.swift
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func linearGradient(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// Draws the icon on a 1024×1024 canvas, origin at the bottom left.
func drawIcon(_ ctx: CGContext) {
    // Background tile on Apple's macOS icon grid: 824 pt inside 1024.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = roundedRect(tile, 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x2A1B5E))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    linearGradient(ctx, [color(0xFF8A5B), color(0xC2408F), color(0x4B2A9E)],
                   from: CGPoint(x: 300, y: 924), to: CGPoint(x: 724, y: 100))

    // Concentric rings behind the panel, like sound waves.
    ctx.setLineWidth(10)
    for (i, radius) in [210.0, 300.0, 390.0].enumerated() {
        ctx.setStrokeColor(color(0xFFFFFF, 0.14 - CGFloat(i) * 0.035))
        ctx.strokeEllipse(in: CGRect(x: 512 - radius, y: 540 - radius, width: radius * 2, height: radius * 2))
    }
    ctx.restoreGState()

    // Floating player panel.
    let panel = CGRect(x: 222, y: 400, width: 580, height: 290)
    let panelPath = roundedRect(panel, 72)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -48), blur: 60, color: color(0x1A0B3D, 0.55))
    ctx.addPath(panelPath)
    ctx.setFillColor(color(0xFFFFFF, 0.97))
    ctx.fillPath()
    ctx.restoreGState()

    // Artwork square.
    let art = CGRect(x: panel.minX + 46, y: panel.minY + 92, width: 152, height: 152)
    ctx.saveGState()
    ctx.addPath(roundedRect(art, 34))
    ctx.clip()
    linearGradient(ctx, [color(0xFF8A5B), color(0x7A3BD1)],
                   from: CGPoint(x: art.minX, y: art.maxY), to: CGPoint(x: art.maxX, y: art.minY))
    ctx.restoreGState()

    // Play triangle on the artwork.
    let cx = art.midX + 8, cy = art.midY
    ctx.move(to: CGPoint(x: cx - 30, y: cy + 40))
    ctx.addLine(to: CGPoint(x: cx + 42, y: cy))
    ctx.addLine(to: CGPoint(x: cx - 30, y: cy - 40))
    ctx.closePath()
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()

    // Title and artist lines.
    let textX = art.maxX + 40
    ctx.setFillColor(color(0x2A1B5E))
    ctx.addPath(roundedRect(CGRect(x: textX, y: art.minY + 92, width: 270, height: 36), 18))
    ctx.fillPath()
    ctx.setFillColor(color(0x2A1B5E, 0.35))
    ctx.addPath(roundedRect(CGRect(x: textX, y: art.minY + 30, width: 190, height: 30), 15))
    ctx.fillPath()

    // Progress bar.
    let bar = CGRect(x: panel.minX + 46, y: panel.minY + 40, width: panel.width - 92, height: 18)
    ctx.setFillColor(color(0x2A1B5E, 0.15))
    ctx.addPath(roundedRect(bar, 9))
    ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(roundedRect(CGRect(x: bar.minX, y: bar.minY, width: bar.width * 0.58, height: bar.height), 9))
    ctx.clip()
    linearGradient(ctx, [color(0xFF8A5B), color(0xC2408F)],
                   from: CGPoint(x: bar.minX, y: 0), to: CGPoint(x: bar.minX + bar.width * 0.58, y: 0))
    ctx.restoreGState()
}

func png(size: Int) -> Data {
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(ctx)
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { exit(1) }

if CommandLine.arguments.count > 1 {
    try png(size: 1024).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
print("Wrote Resources/AppIcon.icns")
