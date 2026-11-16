import AVFoundation

/// The iPhone's own Dutch voice, used only when Ayla's server voice is not available, so she never goes silent.
nonisolated final class DeviceVoice: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private let lock = NSLock()
    private var onDone: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Reads `text` and returns when it is done or stopped.
    func speak(_ text: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.withLock { onDone = { continuation.resume() } }
            let utterance = AVSpeechUtterance(string: text.replacing(/\b(?i:pav[eé])(?![a-zà-ÿ])/, with: "Peiv"))
            utterance.voice = AVSpeechSynthesisVoice(language: "nl-NL")
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        finish()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finish()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish()
    }

    private func finish() {
        let done = lock.withLock {
            defer { onDone = nil }
            return onDone
        }
        done?()
    }
}
