import AVFoundation
import PAVECore

/// The microphone and the speaker for a voice conversation with Ayla, on one audio engine with voice processing.
/// Voice processing cancels Ayla's own voice from the microphone (echo cancellation), so the user can talk through her.
/// The audio threads call in here, so it is not tied to the main actor.
nonisolated final class VoiceAudio: @unchecked Sendable {
    let meter = VoiceMeter()

    private let engine = AVAudioEngine()
    private let speech = AVAudioPlayerNode()
    private let blips = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: PCM16Decoder.sampleRate, channels: 1)!
    private let lock = NSLock()

    private var onMicrophone: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private var isMuted = false
    private var isRunning = false
    /// Every answer gets a new number, so audio from an interrupted answer can never finish the next one.
    private var generation = 0
    private var scheduled = 0
    private var isComplete = false
    private var onFinished: (@Sendable () -> Void)?

    /// Starting, stopping and restarting the engine happen one after the other, on this queue.
    private let queue = DispatchQueue(label: "nl.fontys.pave.voice-audio")
    private var configurationObserver: (any NSObjectProtocol)?
    private var hasTaps = false
    private var onRestart: (@Sendable () -> Void)?

    /// Starts the microphone and speaker. `onMicrophone` gets every piece of microphone audio, on an audio thread.
    /// `onRestart` runs after iOS reconfigured the audio and the engine started again (see `restart()`).
    func start(
        onMicrophone: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
        onRestart: @escaping @Sendable () -> Void
    ) throws {
        try queue.sync {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
            try session.setActive(true)

            try? engine.inputNode.setVoiceProcessingEnabled(true)
            if speech.engine == nil { engine.attach(speech) }
            if blips.engine == nil { engine.attach(blips) }
            lock.withLock {
                self.onMicrophone = onMicrophone
                self.onRestart = onRestart
                self.isMuted = false
            }
            if configurationObserver == nil {
                configurationObserver = NotificationCenter.default.addObserver(
                    forName: .AVAudioEngineConfigurationChange,
                    object: engine,
                    queue: nil
                ) { [weak self] _ in
                    guard let self else { return }
                    queue.async { self.restart() }
                }
            }
            try run()
            lock.withLock { isRunning = true }
        }
    }

    func stop() {
        queue.sync {
            let wasRunning = lock.withLock {
                let wasRunning = isRunning
                isRunning = false
                onMicrophone = nil
                onRestart = nil
                return wasRunning
            }
            stopSpeech()
            guard wasRunning else { return }
            removeTaps()
            engine.stop()
            meter.reset()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// Connects and taps everything with the formats the engine has now, and starts it.
    private func run() throws {
        removeTaps()
        engine.connect(speech, to: engine.mainMixerNode, format: format)
        engine.connect(blips, to: engine.mainMixerNode, format: format)
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.heard(buffer)
        }
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.played(buffer)
        }
        hasTaps = true
        engine.prepare()
        try engine.start()
        speech.play()
        blips.play()
    }

    private func removeTaps() {
        guard hasTaps else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.mainMixerNode.removeTap(onBus: 0)
        hasTaps = false
    }

    /// iOS reconfigures the audio, for example right after voice processing is switched on for the first time, or
    /// when headphones come or go, and then stops the engine without a word. The microphone hears nothing and Ayla
    /// stays silent until the conversation is started again; that is why voice mode used to work only the second
    /// time after opening the app. So the engine starts again by itself here.
    private func restart() {
        guard lock.withLock({ isRunning }) else { return }
        stopSpeech()
        try? run()
        lock.withLock { onRestart }?()
    }

    func setMuted(_ muted: Bool) {
        lock.withLock { isMuted = muted }
        if muted { meter.update(microphone: 0) }
    }

    func play(_ blip: VoiceBlip) {
        guard lock.withLock({ isRunning }), let buffer = blip.buffer(format: format) else { return }
        blips.scheduleBuffer(buffer, completionHandler: nil)
    }

    // MARK: Ayla's voice

    /// Starts a new answer. Pieces from an earlier answer are dropped.
    func beginSpeech() {
        stopSpeech()
    }

    /// Plays the next piece of Ayla's voice right after the previous one.
    func play(_ samples: [Float]) {
        guard !samples.isEmpty, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            channel.update(from: source.baseAddress!, count: samples.count)
        }
        let current = lock.withLock {
            scheduled += 1
            return generation
        }
        speech.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.piecePlayed(generation: current)
        }
    }

    /// Waits until everything that was scheduled has been heard, or until the answer is interrupted.
    func finishSpeech() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let finishNow = lock.withLock {
                isComplete = true
                if scheduled == 0 { return true }
                onFinished = { continuation.resume() }
                return false
            }
            if finishNow { continuation.resume() }
        }
    }

    /// Stops Ayla mid-sentence, for example because the user started talking.
    func stopSpeech() {
        let finished = lock.withLock {
            generation += 1
            scheduled = 0
            isComplete = false
            let finished = onFinished
            onFinished = nil
            return finished
        }
        speech.stop()
        if lock.withLock({ isRunning }) { speech.play() }
        finished?()
    }

    private func piecePlayed(generation played: Int) {
        let finished: (@Sendable () -> Void)? = lock.withLock {
            guard played == generation else { return nil }
            scheduled = max(0, scheduled - 1)
            guard scheduled == 0, isComplete else { return nil }
            let finished = onFinished
            onFinished = nil
            return finished
        }
        finished?()
    }

    // MARK: Levels

    private func heard(_ buffer: AVAudioPCMBuffer) {
        let (handler, muted) = lock.withLock { (onMicrophone, isMuted) }
        guard !muted else { return }
        handler?(buffer)
        if let channel = buffer.floatChannelData?[0] {
            let count = Int(buffer.frameLength)
            meter.update(microphone: VoiceMeter.level(of: channel, count: count))
            meter.update(microphoneBands: VoiceMeter.bands(of: channel, count: count, sampleRate: buffer.format.sampleRate))
        }
    }

    private func played(_ buffer: AVAudioPCMBuffer) {
        if let channel = buffer.floatChannelData?[0] {
            let count = Int(buffer.frameLength)
            meter.update(speaker: VoiceMeter.level(of: channel, count: count))
            meter.update(speakerBands: VoiceMeter.bands(of: channel, count: count, sampleRate: buffer.format.sampleRate))
        }
    }
}
