import CoreAudio
import CoreGraphics

/// Reads, without any permission, how long the owner has been away from the keyboard and pointer,
/// and whether a call holds a microphone, so calls that are not in Calendar (FaceTime, WhatsApp,
/// a Meet link opened by hand) still count as a meeting.
enum ActivityMonitor {
    /// Seconds since the last keyboard, pointer or trackpad input.
    static var idleSeconds: Double {
        // ~0 asks for any input event type:
        // https://developer.apple.com/documentation/coregraphics/cgeventsource/secondssincelasteventtype(_:eventtype:)
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    /// True when some app records from a microphone. It asks each audio process, not each device:
    /// a headset playing music is a running device with a microphone, but not a call.
    /// https://developer.apple.com/documentation/coreaudio/kaudioprocesspropertyisrunninginput
    static var isMicrophoneInUse: Bool {
        processIDs().contains { isRunningInput($0) }
    }

    private static func processIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func isRunningInput(_ process: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningInput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(process, &address, 0, nil, &size, &running) == noErr && running != 0
    }
}
