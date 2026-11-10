import AVFoundation
import Speech

/// Turns the user's speech into Dutch text: on the device when its Dutch speech model is installed, otherwise
/// through Apple (the iOS permission prompt says so). Only the text goes to Ayla.
/// One recognition runs per turn; the microphone audio is handed in from the audio thread.
nonisolated final class VoiceRecognizer: @unchecked Sendable {
    /// Words that come up a lot in PAVE, so the recognizer expects them (as in the voice demo).
    static let hints = ["Ayla", "PAVE", "kluis", "cv", "vacature", "stage", "plan", "profiel", "diploma", "certificaat"]

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "nl-NL"))
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var generation = 0

    var isAvailable: Bool { recognizer?.isAvailable == true }

    /// Asks for speech recognition and the microphone. This must stay outside the main actor: iOS answers on a
    /// background thread, and a main-actor callback there stops the app (Swift 6 checks it at run time).
    static func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Reserves the next turn. Call it where the turn is decided, then `begin(_:onText:onEnd:)` (which takes a
    /// moment, so it can run off the main thread). An `end()` in between cancels the reserved turn.
    func reserve() -> Int {
        lock.withLock {
            generation += 1
            return generation
        }
    }

    /// Starts the reserved turn. `onText` gets everything heard so far in this turn; `onEnd` runs when the
    /// recognizer stops by itself (it does after about a minute), so the conversation can start a new turn.
    func begin(_ turn: Int, onText: @escaping @Sendable (String) -> Void, onEnd: @escaping @Sendable () -> Void) {
        let previous = lock.withLock {
            defer {
                request = nil
                task = nil
            }
            return (request, task)
        }
        previous.0?.endAudio()
        previous.1?.cancel()
        guard let recognizer, isCurrent(turn) else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.contextualStrings = Self.hints
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        guard lock.withLock({ () -> Bool in
            guard generation == turn else { return false }
            self.request = request
            return true
        }) else { return }
        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self, self.isCurrent(turn) else { return }
            if let text = result?.bestTranscription.formattedString, !text.isEmpty { onText(text) }
            if error != nil || result?.isFinal == true { onEnd() }
        }
        let isKept = lock.withLock { () -> Bool in
            guard generation == turn else { return false }
            self.task = task
            return true
        }
        if !isKept {
            request.endAudio()
            task.cancel()
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.withLock { request }?.append(buffer)
    }

    func end() {
        let (request, task) = lock.withLock {
            generation += 1
            defer {
                self.request = nil
                self.task = nil
            }
            return (self.request, self.task)
        }
        request?.endAudio()
        task?.cancel()
    }

    private func isCurrent(_ value: Int) -> Bool {
        lock.withLock { generation == value }
    }
}
