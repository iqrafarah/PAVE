import AVFoundation
import PAVECore

/// Keeps what the microphone heard as 16 kHz mono, so a spoken question can go to `ayla-listen` (Voxtral), which
/// hears Dutch and names better than the recognizer on the iPhone. Only the newest minute is kept, and only in
/// memory; it is gone once the turn has been sent. The audio thread appends, the main actor reads.
nonisolated final class VoiceTurnRecorder: @unchecked Sendable {
    static let sampleRate = 16_000
    /// What `ayla-listen` accepts, with room for the WAV header.
    static let maximumSamples = (SupabaseAylaListenService.maximumBytes - 44) / 2

    private let lock = NSLock()
    private let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(sampleRate), channels: 1, interleaved: true)!
    private var converter: AVAudioConverter?
    private var samples: [Int16] = []
    /// How many samples were dropped from the front, so a mark stays valid while the oldest audio goes.
    private var dropped = 0

    /// Where the recording stands now; `wav(from:)` returns what came after it.
    var position: Int {
        lock.withLock { dropped + samples.count }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let converted = convert(buffer), let channel = converted.int16ChannelData?[0] else { return }
        let count = Int(converted.frameLength)
        lock.withLock {
            samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: count))
            let excess = samples.count - Self.maximumSamples
            if excess > 0 {
                samples.removeFirst(excess)
                dropped += excess
            }
        }
    }

    /// The recording from `start` on, as WAV; nil when there is nothing of it left.
    func wav(from start: Int) -> Data? {
        let piece = lock.withLock { () -> [Int16] in
            let from = max(0, start - dropped)
            return from < samples.count ? Array(samples[from...]) : []
        }
        return piece.isEmpty ? nil : AylaWAV.data(samples: piece, sampleRate: Self.sampleRate)
    }

    func reset() {
        lock.withLock {
            dropped += samples.count
            samples.removeAll(keepingCapacity: true)
        }
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let converter = lock.withLock { () -> AVAudioConverter? in
            if self.converter?.inputFormat != buffer.format { self.converter = AVAudioConverter(from: buffer.format, to: target) }
            return self.converter
        }
        guard let converter else { return nil }
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
        var given = false
        let status = converter.convert(to: output, error: nil) { _, inputStatus in
            if given {
                inputStatus.pointee = .noDataNow
                return nil
            }
            given = true
            inputStatus.pointee = .haveData
            return buffer
        }
        return status == .error ? nil : output
    }
}
