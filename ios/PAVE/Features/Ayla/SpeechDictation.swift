import AVFoundation
import Observation
import Speech

/// Turns speech into text on the device, in Dutch. Only the text goes to Ayla.
@Observable
final class SpeechDictation {
    enum Problem: Equatable {
        case notAllowed
        case unavailable
    }

    private(set) var isListening = false
    var problem: Problem?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "nl-NL"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Starts listening. `onText` gets the full text heard so far, every time it changes.
    func start(onText: @escaping @MainActor @Sendable (String) -> Void) async {
        guard !isListening else { return }
        guard await Self.speechAllowed(), await AVAudioApplication.requestRecordPermission() else {
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
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            Self.installTap(on: engine.inputNode, feeding: request)
            engine.prepare()
            try engine.start()

            self.request = request
            isListening = true
            task = Self.recognize(with: recognizer, request: request, onText: onText) { [weak self] in
                Task { @MainActor in self?.stop() }
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func speechAllowed() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    // The audio tap and the recognition callback run on background threads, so they are built outside the main actor.
    nonisolated private static func installTap(on node: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func recognize(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onText: @escaping @MainActor @Sendable (String) -> Void,
        onEnd: @escaping @Sendable () -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            if let text = result?.bestTranscription.formattedString {
                Task { @MainActor in onText(text) }
            }
            if error != nil || result?.isFinal == true {
                onEnd()
            }
        }
    }
}
