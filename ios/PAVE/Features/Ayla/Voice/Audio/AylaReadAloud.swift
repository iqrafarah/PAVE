import AVFoundation
import Observation
import PAVECore

/// Reads one of Ayla's answers out loud in her own voice, from the menu on a message. Without her voice it uses the
/// iPhone's Dutch voice, so the button always does something.
@Observable
final class AylaReadAloud {
    /// The message being read out loud.
    private(set) var playingID: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let player = ReadAloudPlayer()
    @ObservationIgnored private let deviceVoice = DeviceVoice()

    func toggle(id: String, text: String, service: (any AylaService)?) {
        guard playingID != id else {
            stop()
            return
        }
        stop()
        playingID = id
        let player = player
        let deviceVoice = deviceVoice
        task = Task {
            let stream = service?.speech(for: text) ?? AsyncThrowingStream { $0.finish(throwing: AylaError.unavailable) }
            let played = await player.play(stream)
            if !played, !Task.isCancelled {
                await deviceVoice.speak(text)
            }
            if !Task.isCancelled { playingID = nil }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        player.stop()
        deviceVoice.stop()
        playingID = nil
    }
}

/// Plays Ayla's streamed voice (pcm16, 24 kHz, mono) through the speaker, without the microphone.
nonisolated final class ReadAloudPlayer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: PCM16Decoder.sampleRate, channels: 1)!

    init() {
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    /// Plays the voice until it ends or the task is cancelled. False when no audio came in at all.
    func play(_ stream: AsyncThrowingStream<Data, any Error>) async -> Bool {
        var decoder = PCM16Decoder()
        var started = false
        do {
            for try await piece in stream {
                guard !Task.isCancelled else { break }
                guard let buffer = buffer(with: decoder.samples(from: piece)) else { continue }
                if !started {
                    try start()
                    started = true
                }
                node.scheduleBuffer(buffer, completionHandler: nil)
            }
        } catch {}
        guard started else { return false }
        if !Task.isCancelled, let end = buffer(with: [0]) {
            // Stopping the player also calls this, so cancelling never leaves it waiting.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                node.scheduleBuffer(end, completionCallbackType: .dataPlayedBack) { _ in continuation.resume() }
            }
        }
        stop()
        return true
    }

    func stop() {
        node.stop()
        guard engine.isRunning else { return }
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
        engine.prepare()
        try engine.start()
        node.play()
    }

    private func buffer(with samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        return buffer
    }
}
