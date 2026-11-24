import AVFAudio
import CoreMotion
import Foundation
import MediaPlayer
import Observation
import PAVECore
import UIKit

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

    /// The silence after which a question is sent depends on how the words end: see `AylaTurnEnd`.
    /// How long the server's speech model may take before the iPhone's own words are sent instead.
    static let transcriptionWait = Duration.seconds(5)
    /// The recording of a turn starts this long before the first words were recognized, which come in a bit late.
    static let recordingLead = 1.5
    /// Ayla only lets herself be interrupted after this long, and by at least two words, so a cough does not stop her.
    static let interruptAfter: TimeInterval = 0.8
    /// The voice says about this many characters per second; used to time the icons in the orb.
    static let charactersPerSecond = 15.0
    static let iconDuration: TimeInterval = 2
    /// How long Ayla's own voice may take to start before the iPhone's voice reads the answer instead.
    static let voiceWait = Duration.seconds(8)

    private(set) var state = State.off {
        didSet { publishStatus() }
    }
    private(set) var isMuted = false {
        didSet { publishStatus() }
    }
    /// The AirPods came out: Ayla stops talking and listening until they are back in.
    private(set) var isPaused = false {
        didSet { publishStatus() }
    }
    /// What Ayla heard so far in this turn.
    private(set) var heard = ""
    var problem: SpeechDictation.Problem?

    let meter: VoiceMeter

    private let model: AylaChatModel
    private let audio = VoiceAudio()
    private let recognizer = VoiceRecognizer()
    private let recorder = VoiceTurnRecorder()
    private let deviceVoice = DeviceVoice()
    private var silence: Task<Void, Never>?
    private var turn: Task<Void, Never>?
    private var speakingSince: Date?
    private var usesDeviceVoice = false
    private var cues: [AylaVoiceCue] = []
    private var answerLength = 0
    private var spokenText = ""
    /// Every start and stop counts, so a start that was stopped halfway does not carry on.
    private var attempt = 0
    /// Starting and stopping the audio takes a moment, so it runs off the main thread (the intro keeps moving),
    /// one step after the other.
    private var audioWork: Task<Bool, Never>?

    /// A spoken (or nodded) Ja: the screen may handle it itself, such as putting evidence in the vault. When it
    /// returns true the Ja does not go to Ayla; the screen tells her what happened.
    var onYes: ((String) -> Bool)?
    @ObservationIgnored private let liveActivity = AylaVoiceLiveActivity()
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    /// The answer that was cut off when the AirPods came out, said again from the start once they are back.
    @ObservationIgnored private var currentReply: AylaReply?
    @ObservationIgnored private var resumeReply: AylaReply?
    @ObservationIgnored private var nextTurnChecksYes = true
    /// Names the user may say right now (the vacancies on screen, the evidence in the vault), so the server's speech
    /// model writes them the way PAVE does.
    @ObservationIgnored var hints: (() -> [String])?
    /// Where the recording of this turn starts; nil until the first words were heard.
    @ObservationIgnored private var turnStart: Int?
    /// How many words were heard when the turn ended: more words while the question is still being written out
    /// means the user was not done, and the turn goes on.
    @ObservationIgnored private var wordsAtEnd = 0
    /// The question has gone to Ayla: from here on, talking interrupts instead of adding to it.
    @ObservationIgnored private var isSent = false
    /// Typed or sent by PAVE itself: there is no recording to write out.
    @ObservationIgnored private var isTyped = false

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
        let started = await queueAudio { [recognizer, recorder] audio in
            do {
                try audio.start(onMicrophone: { buffer in
                    recognizer.append(buffer)
                    recorder.append(buffer)
                }, onRestart: restarted)
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
        followHeadphones()
        liveActivity.start(status: currentStatus)
    }

    func stop() {
        guard state != .off else { return }
        attempt += 1
        stopFollowingHeadphones()
        headTimeout?.cancel()
        listensForHead = false
        isPaused = false
        resumeReply = nil
        currentReply = nil
        silence?.cancel()
        turn?.cancel()
        recognizer.end()
        deviceVoice.stop()
        queueAudio { $0.stop(); return true }
        state = .off
        isMuted = false
        heard = ""
        cues = []
        recorder.reset()
        liveActivity.end()
    }

    /// For a question for Ja or Nee the iPhone's microphone listens, so the AirPods are ordinary headphones and iOS
    /// passes on nods and head shakes; otherwise the AirPods' microphone, which hears you better with the phone in a
    /// pocket. The switch happens before Ayla starts to say the question, so a nod already counts while she says it.
    private(set) var listensForHead = false
    @ObservationIgnored private var headTimeout: Task<Void, Never>?
    /// The microphone switch that is busy; Ayla only starts talking once it is done.
    @ObservationIgnored private var micSwitch: Task<Bool, Never>?

    /// Waits until the microphone has switched (the engine starts again on the new route).
    private func listenForHead(_ on: Bool) async {
        headTimeout?.cancel()
        guard isActive, on != listensForHead else { return }
        if on {
            guard hasBluetoothHeadphones, ![.denied, .restricted].contains(CMHeadphoneMotionManager.authorizationStatus()) else { return }
        }
        listensForHead = on
        let work = queueAudio { audio in
            audio.useHeadsetMicrophone(!on)
            return true
        }
        micSwitch = work
        _ = await work.value
    }

    /// No answer a while after Ayla finished her question: the AirPods' microphone listens again.
    private func endHeadListeningLater() {
        headTimeout?.cancel()
        guard listensForHead else { return }
        headTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self, !Task.isCancelled, state == .listening, heard.isEmpty else { return }
            await listenForHead(false)
        }
    }

    /// A soft sound for what just happened, so you need not look at the screen.
    func play(_ blip: VoiceBlip) {
        audio.play(blip)
    }

    // MARK: AirPods

    /// Out of your ears: Ayla stops talking and listening. An answer she was giving is said again when they are back.
    func pause() {
        guard isActive, !isPaused else { return }
        isPaused = true
        silence?.cancel()
        heard = ""
        audio.setMuted(true)
        if state == .speaking {
            resumeReply = currentReply
            turn?.cancel()
            audio.stopSpeech()
            deviceVoice.stop()
            speakingSince = nil
            state = .listening
        }
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        audio.setMuted(isMuted)
        if let reply = resumeReply {
            resumeReply = nil
            state = .thinking
            turn = Task { [weak self] in await self?.speak(reply) }
        } else if state == .listening {
            audio.play(.listen)
        }
    }

    /// A press on the AirPods' stem: back from a pause; Ayla stops talking and listens; what you said is sent at
    /// once; or, while she waits for you, the microphone goes off or on again.
    func stemPressed() {
        if isPaused {
            resume()
            return
        }
        switch state {
        case .thinking, .speaking:
            tapOrb()
        case .listening where !heard.isEmpty:
            tapOrb()
        case .listening:
            toggleMute()
            audio.play(isMuted ? .end : .listen)
        default:
            break
        }
    }

    private func followHeadphones() {
        stopFollowingHeadphones()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            let previous = note.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
            let had = previous.map(Self.hasHeadphones) ?? false
            let has = Self.hasHeadphones(AVAudioSession.sharedInstance().currentRoute)
            MainActor.assumeIsolated {
                if reason == .oldDeviceUnavailable, had, !has { self?.pause() }
                if reason == .newDeviceAvailable, has { self?.resume() }
            }
        })
        observers.append(center.addObserver(forName: AVAudioApplication.inputMuteStateChangeNotification, object: nil, queue: .main) { [weak self] note in
            let muted = note.userInfo?[AVAudioApplication.muteStateKey] as? Bool
            MainActor.assumeIsolated {
                guard let self, let muted, muted != self.isMuted, !self.isPaused else { return }
                self.toggleMute()
            }
        })

        let commands = MPRemoteCommandCenter.shared()
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.stemPressed() }
            return .success
        }
        // One AirPod out pauses, back in plays: the same as taking both out.
        commands.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.pause() }
            return .success
        }
        commands.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.isPaused { self.resume() } else { self.stemPressed() }
            }
            return .success
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Gesprek met Ayla",
            MPMediaItemPropertyArtist: "PAVE",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
    }

    private func stopFollowingHeadphones() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        let commands = MPRemoteCommandCenter.shared()
        commands.togglePlayPauseCommand.removeTarget(nil)
        commands.pauseCommand.removeTarget(nil)
        commands.playCommand.removeTarget(nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Bluetooth headphones are where Ayla's voice goes now.
    var hasBluetoothHeadphones: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains { [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains($0.portType) }
    }

    nonisolated private static func hasHeadphones(_ route: AVAudioSessionRouteDescription) -> Bool {
        route.outputs.contains { [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .headphones].contains($0.portType) }
    }

    // MARK: Lock Screen

    private var currentStatus: AylaVoiceActivityAttributes.ContentState.Status {
        if isPaused { return .paused }
        if isMuted, state == .listening { return .muted }
        return switch state {
        case .thinking: .thinking
        case .speaking: .speaking
        default: .listening
        }
    }

    /// What Ayla is busy with in the app, for the Lock Screen and the Dynamic Island: words that say nothing about
    /// you, such as "Stap 2 van 3". Nil when she is not doing anything there.
    var doingNote: String? {
        didSet { if doingNote != oldValue { publishStatus() } }
    }

    private func publishStatus() {
        guard state != .off else { return }
        liveActivity.update(status: currentStatus, note: doingNote)
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

    /// A typed question during the conversation: Ayla answers it out loud, like a spoken one. `checksYes` off for
    /// what PAVE tells Ayla itself, such as that something went into the vault.
    func send(typed text: String, checksYes: Bool = true) {
        nextTurnChecksYes = checksYes
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isActive, state != .starting, !question.isEmpty else { return }
        turn?.cancel()
        silence?.cancel()
        audio.stopSpeech()
        deviceVoice.stop()
        heard = question
        isTyped = true
        state = .listening
        endTurn()
    }

    func toggleMute() {
        isMuted.toggle()
        audio.setMuted(isMuted || isPaused)
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

    /// The sentence Ayla is saying at `date`, for the captions.
    func spokenSentence(at date: Date) -> String? {
        guard state == .speaking, let speakingSince else { return nil }
        let position = Int(date.timeIntervalSince(speakingSince) * Self.charactersPerSecond)
        return AylaCaptions.sentence(in: spokenText, at: position)
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
        startTurn()
        state = .listening
        startRecognizing()
    }

    private func startTurn() {
        turnStart = nil
        isSent = false
        isTyped = false
    }

    /// The first words of a turn: the recording of it starts a little before them.
    private func markTurnStart() {
        guard turnStart == nil else { return }
        turnStart = max(0, recorder.position - Int(Self.recordingLead * Double(VoiceTurnRecorder.sampleRate)))
    }

    private static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
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
            markTurnStart()
            heard = text
            scheduleEndOfTurn()
        case .thinking where !isSent && !isTyped && Self.wordCount(text) > wordsAtEnd:
            // Still talking after a pause, while the question was being written out: it was not finished yet.
            turn?.cancel()
            state = .listening
            heard = text
            scheduleEndOfTurn()
        case .speaking:
            guard canBeInterrupted(by: text) else { return }
            turn?.cancel()
            audio.stopSpeech()
            silence?.cancel()
            speakingSince = nil
            startTurn()
            markTurnStart()
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
        let pause = AylaTurnEnd.pause(after: heard)
        silence = Task { [weak self] in
            try? await Task.sleep(for: pause)
            guard !Task.isCancelled else { return }
            self?.endTurn()
        }
    }

    private func endTurn() {
        let question = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state == .listening, !isPaused, !question.isEmpty else { return }
        silence?.cancel()
        let checksYes = nextTurnChecksYes
        nextTurnChecksYes = true
        if checksYes, AylaVaultOffer.isConfirmation(question), onYes?(question) == true {
            heard = ""
            recognizer.end()
            startTurn()
            startRecognizing()
            return
        }
        // The screen stopped the conversation for a form: Ayla still hears the answer, in writing.
        guard state == .listening else {
            model.send(question)
            return
        }
        // The recognizer keeps listening while the question is written out, so more words still count.
        wordsAtEnd = Self.wordCount(question)
        state = .thinking
        audio.play(.think)
        if listensForHead { Task { await listenForHead(false) } }
        turn = Task { [weak self] in
            guard let self else { return }
            let question = await writtenOut(question)
            guard !Task.isCancelled, state == .thinking else { return }
            isSent = true
            recognizer.end()
            heard = question
            guard let reply = await model.ask(question, input: .voice) else {
                stop()
                return
            }
            guard !Task.isCancelled, state == .thinking else { return }
            await speak(reply)
        }
    }

    /// The question as the server's speech model heard it: Voxtral knows Dutch and the names on screen better than the
    /// iPhone. What the iPhone heard is the fallback, also when the recording is gone or the server is slow.
    private func writtenOut(_ heardHere: String) async -> String {
        guard !isTyped, let turnStart, let wav = recorder.wav(from: turnStart), let service = model.service else { return heardHere }
        let hints = hints?() ?? []
        let transcription = Task { try await service.transcribe(wav, hints: hints) }
        let timeout = Task {
            try? await Task.sleep(for: Self.transcriptionWait)
            transcription.cancel()
        }
        defer { timeout.cancel() }
        let text = await withTaskCancellationHandler {
            (try? await transcription.value) ?? ""
        } onCancel: {
            transcription.cancel()
        }
        let written = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return written.isEmpty ? heardHere : written
    }

    /// The screen is off or PAVE is not in front, such as with the iPhone in a pocket: the buttons cannot be seen.
    private var isOutOfSight: Bool {
        UIApplication.shared.applicationState != .active || !UIApplication.shared.isProtectedDataAvailable
    }

    private func speak(_ reply: AylaReply) async {
        currentReply = reply
        if isPaused {
            resumeReply = reply
            state = .listening
            return
        }
        // A question for Ja or Nee: the iPhone's microphone before she says it, so a nod counts at once.
        if model.pendingYesNo { await listenForHead(true) }
        _ = await micSwitch?.value
        guard !Task.isCancelled, state == .thinking || state == .speaking else { return }
        var text = [reply.text, reply.question?.text]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        // Out of sight, the choices that are buttons on screen are said too.
        if isOutOfSight, let choices = model.pendingQuestion?.choices.map(\.label),
           let line = AylaSpokenReply.choicesLine(choices, canNod: listensForHead) {
            text += " " + line
        }
        heard = ""
        cues = AylaVoiceCue.cues(in: text)
        answerLength = text.count
        spokenText = text
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
        // Your turn: a soft sound, so you know without looking.
        audio.play(.listen)
        listen()
        endHeadListeningLater()
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
