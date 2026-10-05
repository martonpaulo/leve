import CoreAudio
import Foundation
import LeveKit

/// Which processes play sound now, read from Core Audio's process objects (#13). It needs no
/// permission and sends no Apple Event: `kAudioProcessPropertyIsRunningOutput` is 1 while a
/// process runs IO with at least one active output stream (CoreAudio/AudioHardware.h).
enum AudioActivity {
    /// Whether a process other than Leve plays sound; false when Core Audio cannot be read.
    static var isOtherAudioPlaying: Bool {
        MediaPause.isOtherAudioPlaying(processes(), ownPID: ProcessInfo.processInfo.processIdentifier)
    }

    private static func processes() -> [AudioProcess] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &objects) == noErr else { return [] }
        return objects.compactMap { object in
            guard
                let pid = value(object, kAudioProcessPropertyPID, as: pid_t.self),
                let running = value(object, kAudioProcessPropertyIsRunningOutput, as: UInt32.self)
            else { return nil }
            return AudioProcess(pid: pid, isRunningOutput: running != 0)
        }
    }

    private static func value<T: BitwiseCopyable>(
        _ object: AudioObjectID, _ selector: AudioObjectPropertySelector, as type: T.Type
    ) -> T? {
        var address = address(selector)
        var size = UInt32(MemoryLayout<T>.size)
        let pointer = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<T>.size, alignment: MemoryLayout<T>.alignment)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.load(as: T.self)
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
}
