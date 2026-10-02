#!/usr/bin/env swift
// Draws Leve's app icon: a white leaf on a soft mint-to-sky gradient, in the macOS icon grid
// (an 824 pt rounded square centered on a 1024 pt canvas). Writes <out>/AppIcon.iconset; `make icon`
// turns it into Support/AppIcon.icns, which is committed.
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "artifacts/icon"
let iconset = URL(fileURLWithPath: output).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(pixels: Int) -> Data? {
    let side = CGFloat(pixels)
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)
    else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let scale = side / 1024
    let tile = NSRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185 * scale, yRadius: 185 * scale)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.62, green: 0.90, blue: 0.80, alpha: 1),
        ending: NSColor(calibratedRed: 0.45, green: 0.72, blue: 0.95, alpha: 1))
    gradient?.draw(in: shape, angle: -60)

    let configuration = NSImage.SymbolConfiguration(pointSize: 430 * scale, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let leaf = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)
    {
        let size = leaf.size
        let origin = NSPoint(x: (side - size.width) / 2, y: (side - size.height) / 2)
        leaf.draw(in: NSRect(origin: origin, size: size))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let file = iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        guard let data = render(pixels: points * scale) else {
            FileHandle.standardError.write(Data("error: could not render \(points)@\(scale)x\n".utf8))
            exit(1)
        }
        try data.write(to: file)
    }
}
FileHandle.standardError.write(Data("Wrote \(iconset.path)\n".utf8))
