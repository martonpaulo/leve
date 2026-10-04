import AppKit

/// A quiet, singing-bowl-like tone, made in code so Leve ships no audio file: a low note with
/// the bowl's inharmonic partials, a soft attack and a slow fade over six seconds.
enum BreakSound {
    private static let sound: NSSound? = NSSound(data: wave())

    /// `volume` keeps it in the background: the start of a break, and softer at its end.
    static func play(volume: Float) {
        guard let sound else { return }
        sound.stop()
        sound.volume = volume
        sound.play()
    }

    private static func wave() -> Data {
        let rate = 44_100
        let seconds = 6.0
        let count = Int(Double(rate) * seconds)
        // A singing bowl's partials sit near 1, 2.76 and 5.40 times the fundamental.
        let partials: [(ratio: Double, level: Double, decay: Double)] = [
            (1, 0.6, 1.1), (2.76, 0.25, 1.8), (5.40, 0.1, 2.6),
        ]
        let fundamental = 196.0
        var samples = [Int16](repeating: 0, count: count)
        for index in 0..<count {
            let time = Double(index) / Double(rate)
            let attack = min(1, time / 0.08)
            var value = 0.0
            for partial in partials {
                value += partial.level * exp(-partial.decay * time) * sin(2 * .pi * fundamental * partial.ratio * time)
            }
            samples[index] = Int16(max(-1, min(1, value * attack)) * Double(Int16.max) * 0.8)
        }
        return wav(samples, rate: rate)
    }

    /// A 16-bit mono PCM WAV file around `samples`.
    private static func wav(_ samples: [Int16], rate: Int) -> Data {
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
            append(sample)
        }
        return data
    }
}
