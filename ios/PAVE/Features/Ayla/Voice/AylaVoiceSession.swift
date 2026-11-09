import Foundation
import Observation
import PAVECore

/// A spoken conversation with Ayla, like voice mode in ChatGPT and Claude: Ayla listens, sends the question after
/// a short silence, reads her answer out loud and then listens again, until the user stops. The user can talk
/// through Ayla to interrupt her. The questions and answers appear in the chat as usual.
@Observable
final class AylaVoiceSession {
    enum State: Equatable {
        case off
        case starting
        case listening
        case thinking
        case speaking
    }

    /// Silence after which a question is sent, as in the voice demo: a short pause halfway does not cut it off.
    static let endOfTurn = Duration.milliseconds(1200)
    /// Ayla only lets herself be interrupted after this long, and by at least two words, so a cough does not stop her.
    static let interruptAfter: TimeInterval = 0.8
    /// The voice says about this many characters per second; used to time the icons in the orb.
    static let charactersPerSecond = 15.0
    static let iconDuration: TimeInterval = 2
    /// How long Ayla's own voice may take to start before the iPhone's voice reads the answer instead.
    static let voiceWait = Duration.seconds(8)

    private(set) var state = State.off
    private(set) var isMuted = false
    /// What Ayla heard so far in this turn.
    private(set) var heard = ""
    var problem: SpeechDictation.Problem?

    let meter: VoiceMeter

    private let model: AylaChatModel
    private let audio = VoiceAudio()
    private let recognizer = VoiceRecognizer()
    private let deviceVoice = DeviceVoice()
    private var silence: Task<Void, Never>?
    private var turn: Task<Void, Never>?
    private var speakingSince: Date?
    private var usesDeviceVoice = false
    private var cues: [AylaVoiceCue] = []
    private var answerLength = 0
    /// Every start and stop counts, so a start that was stopped halfway does not carry on.
    private var attempt = 0
    /// Starting and stopping the audio takes a moment, so it runs off the main thread (the intro keeps moving),
    /// one step after the other.
    private var audioWork: Task<Bool, Never>?

    init(model: AylaChatModel) {
        self.model = model
        meter = audio.meter
    }

    var isActive: Bool { state != .off }

    func start() async {
        guard state == .off, model.isAvailable else { return }
        attempt += 1
        let current = attempt
        state = .starting
        problem = nil
        if let service = model.service { Task { await service.warmUp() } }
        guard await VoiceRecognizer.requestPermission() else {
            if attempt == current {
                problem = .notAllowed
                state = .off
            }
            return
        }
        guard attempt == current else { return }
        guard recognizer.isAvailable else {
            problem = .unavailable
            state = .off
            return
        }
        let restarted: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.audioRestarted() }
        }
        let started = await queueAudio { [recognizer] audio in
            do {
                try audio.start(onMicrophone: { buffer in recognizer.append(buffer) }, onRestart: restarted)
                return true
            } catch {
                audio.stop()
                return false
            }
        }.value
        // Stopped while the audio was starting: stop() has already queued the audio to stop.
        guard attempt == current else { return }
        guard started else {
            problem = .unavailable
            state = .off
            return
        }
        audio.play(.listen)
        listen()
    }

    func stop() {
        guard state != .off else { return }
        attempt += 1
        silence?.cancel()
        turn?.cancel()
        recognizer.end()
        deviceVoice.stop()
        queueAudio { $0.stop(); return true }
        state = .off
        isMuted = false
        heard = ""
        cues = []
    }

    @discardableResult
    private func queueAudio(_ step: @escaping @Sendable (VoiceAudio) -> Bool) -> Task<Bool, Never> {
        let audio = audio
        let previous = audioWork
        let work = Task.detached {
            _ = await previous?.value
            return step(audio)
        }
        audioWork = work
        return work
    }

    /// A typed question during the conversation: Ayla answers it out loud, like a spoken one.
    func send(typed text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isActive, state != .starting, !question.isEmpty else { return }
        turn?.cancel()
        silence?.cancel()
        audio.stopSpeech()
        deviceVoice.stop()
        heard = question
        state = .listening
        endTurn()
    }

    func toggleMute() {
        isMuted.toggle()
        audio.setMuted(isMuted)
        if isMuted { silence?.cancel() }
    }

    /// Tapping the orb: while Ayla thinks or talks it stops her and listens; while listening it sends at once.
    func tapOrb() {
        switch state {
        case .listening where !heard.isEmpty:
            endTurn()
        case .thinking, .speaking:
            turn?.cancel()
            audio.stopSpeech()
            deviceVoice.stop()
            listen()
        default:
            break
        }
    }

    /// The icon the orb shows at `date`, while Ayla talks about a part of PAVE.
    func icon(at date: Date) -> AylaVoiceIcon? {
        guard state == .speaking, let speakingSince else { return nil }
        let elapsed = date.timeIntervalSince(speakingSince)
        let duration = max(1, Double(answerLength) / Self.charactersPerSecond)
        return cues.last { cue in
            let shownAt = cue.at * duration
            return elapsed >= shownAt && elapsed < shownAt + Self.iconDuration
        }?.icon
    }

    // MARK: Turns

    private func listen() {
        silence?.cancel()
        heard = ""
        speakingSince = nil
        state = .listening
        startRecognizing()
    }

    /// Starting the recognizer takes a moment, so it starts off the main thread (the orb keeps moving).
    private func startRecognizing() {
        let recognizer = recognizer
        let turn = recognizer.reserve()
        let onText: @Sendable (String) -> Void = { [weak self] text in
            Task { @MainActor in self?.recognized(text) }
        }
        let onEnd: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.recognizerStopped() }
        }
        Task.detached { recognizer.begin(turn, onText: onText, onEnd: onEnd) }
    }

    private func recognized(_ text: String) {
        switch state {
        case .listening:
            heard = text
            scheduleEndOfTurn()
        case .speaking:
            guard canBeInterrupted(by: text) else { return }
            turn?.cancel()
            audio.stopSpeech()
            silence?.cancel()
            speakingSince = nil
            state = .listening
            heard = text
            scheduleEndOfTurn()
        default:
            break
        }
    }

    /// The recognizer stops by itself after a while: send what was heard, or simply keep listening.
    private func recognizerStopped() {
        switch state {
        case .listening:
            if heard.isEmpty { startRecognizing() } else { endTurn() }
        case .speaking:
            startRecognizing()
        default:
            break
        }
    }

    private func canBeInterrupted(by text: String) -> Bool {
        guard !usesDeviceVoice, let speakingSince, Date.now.timeIntervalSince(speakingSince) > Self.interruptAfter else { return false }
        return text.split(whereSeparator: \.isWhitespace).count >= 2
    }

    private func scheduleEndOfTurn() {
        silence?.cancel()
        guard !isMuted else { return }
        silence = Task { [weak self] in
            try? await Task.sleep(for: Self.endOfTurn)
            guard !Task.isCancelled else { return }
            self?.endTurn()
        }
    }

    private func endTurn() {
        let question = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state == .listening, !question.isEmpty else { return }
        silence?.cancel()
        recognizer.end()
        state = .thinking
        audio.play(.think)
        turn = Task { [weak self] in
            guard let self else { return }
            guard let reply = await model.ask(question, input: .voice) else {
                stop()
                return
            }
            guard !Task.isCancelled, state == .thinking else { return }
            await speak(reply)
        }
    }

    private func speak(_ reply: AylaReply) async {
        let text = [reply.text, reply.question?.text]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        heard = ""
        cues = AylaVoiceCue.cues(in: text)
        answerLength = text.count
        usesDeviceVoice = false
        audio.beginSpeech()

        // Ayla keeps thinking until her voice is really there, as in ChatGPT: the first answer after opening the
        // app can take a moment while the server starts.
        let voice = model.service?.speech(for: text) ?? AsyncThrowingStream(unfolding: { throw AylaError.unavailable })
        let streaming = Task { () -> Bool in
            var decoder = PCM16Decoder()
            var heardAnyAudio = false
            do {
                for try await piece in voice {
                    guard !Task.isCancelled, state == .thinking || state == .speaking else { return heardAnyAudio }
                    if !heardAnyAudio {
                        heardAnyAudio = true
                        beginSpeaking()
                    }
                    audio.play(decoder.samples(from: piece))
                }
            } catch {}
            if heardAnyAudio, !Task.isCancelled { await audio.finishSpeech() }
            return heardAnyAudio
        }
        let watchdog = Task {
            try? await Task.sleep(for: Self.voiceWait)
            if !Task.isCancelled, state == .thinking { streaming.cancel() }
        }
        let heardAnyAudio = await withTaskCancellationHandler {
            await streaming.value
        } onCancel: {
            streaming.cancel()
        }
        watchdog.cancel()

        guard !Task.isCancelled, state == .thinking || state == .speaking else { return }
        if !heardAnyAudio {
            usesDeviceVoice = true
            beginSpeaking()
            await deviceVoice.speak(text)
        }
        guard !Task.isCancelled, state == .speaking else { return }
        listen()
    }

    /// The audio started again after iOS reconfigured it, so the microphone's format may have changed: listening
    /// starts afresh. An answer that was playing was cut off, after which Ayla listens again by herself.
    private func audioRestarted() {
        guard state == .listening else { return }
        startRecognizing()
    }

    private func beginSpeaking() {
        state = .speaking
        speakingSince = .now
        startRecognizing()
    }
}
