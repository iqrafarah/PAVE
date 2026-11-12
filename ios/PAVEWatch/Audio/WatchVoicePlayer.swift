import AVFoundation
import PAVECore

/// Plays Ayla's answer in her own voice (pcm16, 24 kHz, mono, streamed from `ayla-voice`) through the Watch speaker.
/// Without her voice it uses the Watch's Dutch voice, so an answer is always heard.
nonisolated final class WatchVoicePlayer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: PCM16Decoder.sampleRate, channels: 1)!
    private let synthesizer = AVSpeechSynthesizer()
    /// Ayla's voice moves the orb while she speaks.
    let meter: VoiceMeter

    init(meter: VoiceMeter) {
        self.meter = meter
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [meter] buffer, _ in
            guard let samples = buffer.floatChannelData?[0] else { return }
            meter.update(speaker: VoiceMeter.level(of: samples, count: Int(buffer.frameLength)))
        }
    }

    /// Plays until the end or until the task is cancelled.
    func speak(_ text: String, service: any AylaService) async {
        let played = await play(service.speech(for: text))
        if !played, !Task.isCancelled {
            await speakWithDeviceVoice(text)
        }
    }

    func stop() {
        node.stop()
        if engine.isRunning { engine.stop() }
        synthesizer.stopSpeaking(at: .immediate)
        meter.reset()
    }

    private func play(_ stream: AsyncThrowingStream<Data, any Error>) async -> Bool {
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
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                node.scheduleBuffer(end, completionCallbackType: .dataPlayedBack) { _ in continuation.resume() }
            }
        }
        stop()
        return true
    }

    private func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio)
        try session.setActive(true)
        try engine.start()
        node.play()
    }

    private func buffer(with samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        return buffer
    }

    private func speakWithDeviceVoice(_ text: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "nl-NL")
        let delegate = SpeechEnd()
        synthesizer.delegate = delegate
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            delegate.onEnd = { continuation.resume() }
            synthesizer.speak(utterance)
        }
        synthesizer.delegate = nil
    }

    private final class SpeechEnd: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
        var onEnd: (() -> Void)?

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            onEnd?()
            onEnd = nil
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            onEnd?()
            onEnd = nil
        }
    }
}
