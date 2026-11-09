import AVFoundation
import Observation
import Speech

/// Dictation: turns speech into Dutch text in the text field (on the device when it can, otherwise through Apple).
/// Only the text goes to Ayla.
@Observable
final class SpeechDictation {
    enum Problem: Equatable {
        case notAllowed
        case unavailable
    }

    private(set) var isListening = false
    /// When the current recording started, for the timer in the recording bar.
    private(set) var startedAt: Date?
    var problem: Problem?
    /// How loud the user is, for the pixel wave in the recording bar.
    let meter = VoiceMeter()

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "nl-NL"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Starts listening. `onText` gets the full text heard so far, every time it changes.
    func start(onText: @escaping @MainActor @Sendable (String) -> Void) async {
        guard !isListening else { return }
        // Asked outside the main actor: iOS answers on a background thread, and a main-actor callback there crashes the app.
        guard await VoiceRecognizer.requestPermission() else {
            problem = .notAllowed
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            problem = .unavailable
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            request.contextualStrings = VoiceRecognizer.hints
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            Self.installTap(on: engine.inputNode, feeding: request, meter: meter)
            engine.prepare()
            try engine.start()

            self.request = request
            startedAt = .now
            isListening = true
            task = Self.recognize(with: recognizer, request: request, onText: onText) { [weak self] failedBeforeText in
                Task { @MainActor in
                    guard let self, self.isListening else { return }
                    self.stop()
                    // Say so instead of silently doing nothing, for example without a network or speech model.
                    if failedBeforeText { self.problem = .unavailable }
                }
            }
        } catch {
            stop()
            problem = .unavailable
        }
    }

    func stop() {
        guard isListening || request != nil else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isListening = false
        startedAt = nil
        meter.reset()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // The audio tap and the recognition callback run on background threads, so they are built outside the main actor.
    nonisolated private static func installTap(on node: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest, meter: VoiceMeter) {
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            if let channel = buffer.floatChannelData?[0] {
                meter.update(microphone: VoiceMeter.level(of: channel, count: Int(buffer.frameLength)))
            }
        }
    }

    nonisolated private static func recognize(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onText: @escaping @MainActor @Sendable (String) -> Void,
        onEnd: @escaping @Sendable (_ failedBeforeText: Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        let heard = HeardText()
        return recognizer.recognitionTask(with: request) { result, error in
            if let text = result?.bestTranscription.formattedString, !text.isEmpty {
                heard.mark()
                Task { @MainActor in onText(text) }
            }
            if error != nil || result?.isFinal == true {
                // "No speech detected" (1110) just means silence, not a failure.
                let failed = error.map { ($0 as NSError).code != 1110 } ?? false
                onEnd(failed && !heard.value)
            }
        }
    }
}

/// Whether any text was heard yet, written from the recognition callback.
nonisolated private final class HeardText: @unchecked Sendable {
    private let lock = NSLock()
    private var heard = false

    var value: Bool { lock.withLock { heard } }

    func mark() {
        lock.withLock { heard = true }
    }
}
