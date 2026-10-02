import AppKit
import SwiftUI

/// A small dot in a calendar's color. Menus draw SF Symbols as monochrome templates, so the dot is
/// a non-template bitmap that keeps its color in the menu and in Settings.
enum CalendarDot {
    static func image(_ color: NSColor, diameter: CGFloat = 8) -> Image {
        let side = diameter + 4
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2)).fill()
            return true
        }
        image.isTemplate = false
        return Image(nsImage: image)
    }
}
