#!/usr/bin/env swift
// Renders the disk image's background at 1x and 2x into artifacts/dmg-bg.png and
// artifacts/dmg-bg@2x.png; `make icon` joins them into Support/LeveInstallerBackground.tiff. The
// distinctive file name keeps Finder from reusing another volume's cached artwork. Adapted from
// WindowHop's scripts/render-dmg-background.swift (#7).
// The coordinates match scripts/make-dmg.sh's defaults: window 680x400, the app icon centered at
// (180, 225), Applications at (500, 225), icons 112 points.
import AppKit

/// AppKit returns nil here only when it cannot allocate the object; stop with its name.
func required<T>(_ value: T?, _ what: String) -> T {
    guard let value else { fatalError("could not create \(what)") }
    return value
}

let size = NSSize(width: 680, height: 400)
// The app icon's fill, extended-sRGB 0.54, 0.84, 0.86 in Support/AppIcon.icon.
let teal = NSColor(srgbRed: 0.54, green: 0.84, blue: 0.86, alpha: 1)
let deepTeal = NSColor(srgbRed: 0.24, green: 0.56, blue: 0.59, alpha: 1)

func draw(scale: CGFloat) -> NSBitmapImageRep {
    let rep = required(
        NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0),
        "a bitmap at scale \(scale)")
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // A quiet, light surface; the teal is only an accent. Finder draws the two icons above it.
    required(
        NSGradient(colors: [
            NSColor(srgbRed: 0.97, green: 0.99, blue: 0.99, alpha: 1),
            NSColor(srgbRed: 0.91, green: 0.96, blue: 0.96, alpha: 1),
        ]), "the background gradient"
    ).draw(in: NSRect(origin: .zero, size: size), angle: -90)

    func text(_ string: String, font: NSFont, color: NSColor, centerYFromTop: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let measured = (string as NSString).size(withAttributes: attributes)
        (string as NSString).draw(
            at: NSPoint(x: (size.width - measured.width) / 2, y: size.height - centerYFromTop - measured.height / 2),
            withAttributes: attributes)
    }

    // The leaf mark, small and above the title, distinct from the draggable icons below.
    let leafConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        .applying(NSImage.SymbolConfiguration(paletteColors: [deepTeal]))
    if let leaf = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(leafConfiguration)
    {
        let leafSize = leaf.size
        leaf.draw(in: NSRect(
            x: (size.width - leafSize.width) / 2, y: size.height - 40 - leafSize.height / 2,
            width: leafSize.width, height: leafSize.height))
    }

    text(
        "Leve", font: .systemFont(ofSize: 25, weight: .semibold),
        color: NSColor(calibratedWhite: 0.14, alpha: 1), centerYFromTop: 78)
    text(
        "Drag Leve to Applications", font: .systemFont(ofSize: 14.5, weight: .medium),
        color: NSColor(calibratedWhite: 0.4, alpha: 1), centerYFromTop: 112)

    // The arrow between the two icon slots.
    let arrowColor = teal.blended(withFraction: 0.25, of: deepTeal) ?? teal
    arrowColor.setStroke()
    arrowColor.setFill()
    let arrowY = size.height - 225
    let shaft = NSBezierPath()
    shaft.lineWidth = 5
    shaft.lineCapStyle = .round
    shaft.move(to: NSPoint(x: 276, y: arrowY))
    shaft.line(to: NSPoint(x: 388, y: arrowY))
    shaft.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 384, y: arrowY + 14))
    head.line(to: NSPoint(x: 408, y: arrowY))
    head.line(to: NSPoint(x: 384, y: arrowY - 14))
    head.close()
    head.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let outputDirectory = "artifacts"
try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
for (scale, name) in [(CGFloat(1), "dmg-bg.png"), (2, "dmg-bg@2x.png")] {
    try required(draw(scale: scale).representation(using: .png, properties: [:]), "PNG data")
        .write(to: URL(fileURLWithPath: "\(outputDirectory)/\(name)"))
    print("wrote \(outputDirectory)/\(name)")
}
