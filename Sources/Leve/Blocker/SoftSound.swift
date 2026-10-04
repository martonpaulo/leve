import AppKit

/// Leve's two quiet sounds, made in code so it ships no audio file. Each is rendered once, on first
/// use, into a small WAV in memory (under 600 KB) and played by NSSound, which costs nothing between
/// plays.
enum SoftSound {
    /// A singing-bowl tone that fades over six seconds: the event's full screen.
    case bowl
    /// A short music-box phrase of seven notes: the break.
    case melody

    private static let bowlSound = NSSound(data: wav(bowlSamples()))
    private static let melodySound = NSSound(data: wav(melodySamples()))

    /// `volume` keeps it in the background, well under the system volume.
    func play(volume: Float) {
        let sound = self == .bowl ? Self.bowlSound : Self.melodySound
        guard let sound else { return }
        sound.stop()
        sound.volume = volume
        sound.play()
    }

    private static let rate = 44_100

    /// A low note with a bowl's inharmonic partials (1, 2.76 and 5.40 times the fundamental), a soft
    /// attack and a slow fade.
    private static func bowlSamples() -> [Double] {
        let partials: [(ratio: Double, level: Double, decay: Double)] = [
            (1, 0.6, 1.1), (2.76, 0.25, 1.8), (5.40, 0.1, 2.6),
        ]
        return (0..<Int(Double(rate) * 6)).map { index in
            let time = Double(index) / Double(rate)
            let attack = min(1, time / 0.08)
            let value = partials.reduce(0.0) { sum, partial in
                sum + partial.level * exp(-partial.decay * time) * sin(2 * .pi * 196 * partial.ratio * time)
            }
            return value * attack
        }
    }

    /// E G A G E D C on a pentatonic scale, each note a plucked sine with a faint octave, ringing
    /// into the next: calm, and over in four seconds.
    private static func melodySamples() -> [Double] {
        let notes: [(frequency: Double, start: Double)] = [
            (659.3, 0), (784.0, 0.42), (880.0, 0.84), (784.0, 1.26), (659.3, 1.68), (587.3, 2.1), (523.3, 2.6),
        ]
        var samples = [Double](repeating: 0, count: Int(Double(rate) * 4.2))
        for note in notes {
            let first = Int(note.start * Double(rate))
            for index in first..<samples.count {
                let time = Double(index - first) / Double(rate)
                let envelope = min(1, time / 0.012) * exp(-2.4 * time)
                let tone = sin(2 * .pi * note.frequency * time) + 0.18 * sin(4 * .pi * note.frequency * time)
                samples[index] += 0.32 * envelope * tone
            }
        }
        return samples
    }

    /// A 16-bit mono PCM WAV file around `samples`, which are clipped to -1...1.
    private static func wav(_ samples: [Double]) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let bytes = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + bytes))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(rate))
        append(UInt32(rate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(bytes))
        for sample in samples {
            append(Int16(max(-1, min(1, sample)) * Double(Int16.max) * 0.8))
        }
        return data
    }
}
