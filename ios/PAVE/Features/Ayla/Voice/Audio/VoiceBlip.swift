import AVFoundation

/// Soft 8-bit "blips" that go with the pixel orb, as in the voice demo: square waves with a quick fade,
/// on a friendly pentatonic scale and very quiet, so they never drown out Ayla.
nonisolated enum VoiceBlip {
    /// Ayla starts listening: two rising notes.
    case listen
    /// Ayla starts thinking: a soft three-note trill.
    case think
    /// The conversation ends: two falling notes.
    case end
    /// Something went into the vault, or a Ja was understood: three rising notes.
    case saved
    /// A Nee was understood: one soft low note.
    case no
    /// The next card, while going through them with the head: one short tick.
    case tick

    private struct Note {
        let frequency: Double
        var at: Double = 0
        var length: Double = 0.07
        var volume: Double = 1
    }

    private var notes: [Note] {
        switch self {
        case .listen: [Note(frequency: 659), Note(frequency: 988, at: 0.08)]
        case .think: [Note(frequency: 784, volume: 0.7), Note(frequency: 659, at: 0.07, volume: 0.6), Note(frequency: 784, at: 0.14, volume: 0.5)]
        case .end: [Note(frequency: 523), Note(frequency: 392, at: 0.1, length: 0.12)]
        case .saved: [Note(frequency: 659), Note(frequency: 784, at: 0.08), Note(frequency: 1047, at: 0.16, length: 0.14)]
        case .no: [Note(frequency: 392, length: 0.12, volume: 0.8)]
        case .tick: [Note(frequency: 1175, length: 0.035, volume: 0.6)]
        }
    }

    private static let volume = 0.05

    /// The blip as one audio buffer in `format` (mono).
    func buffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let duration = notes.map { $0.at + $0.length + 0.02 }.max() ?? 0
        let frames = AVAudioFrameCount(duration * rate)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for index in 0..<Int(frames) { channel[index] = 0 }
        for note in notes {
            let start = Int(note.at * rate)
            let count = Int(note.length * rate)
            let peak = Self.volume * note.volume
            for offset in 0..<count where start + offset < Int(frames) {
                let time = Double(offset) / rate
                let attack = min(1, time / 0.008)
                let decay = exp(-5 * time / note.length)
                let square: Double = sin(2 * .pi * note.frequency * time) >= 0 ? 1 : -1
                channel[start + offset] += Float(square * peak * attack * decay)
            }
        }
        return buffer
    }
}
