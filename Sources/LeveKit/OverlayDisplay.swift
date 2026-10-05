import Foundation

/// Which display shows the full-screen alert or the break; the others only blur (#11).
public enum OverlayDisplay {
    /// The display that held the content while it is still connected, so a resolution change does
    /// not move it; otherwise the one with the pointer; otherwise the first connected one.
    public static func content(connected: [UInt32], previous: UInt32?, pointer: UInt32?) -> UInt32? {
        if let previous, connected.contains(previous) { return previous }
        if let pointer, connected.contains(pointer) { return pointer }
        return connected.first
    }
}
