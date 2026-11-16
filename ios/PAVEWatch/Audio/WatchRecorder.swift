import AVFoundation
import Foundation

/// Records what you say as 16 kHz mono WAV and stops by itself after a short silence, so you do not have to tap twice.
/// The recording only lives in a temporary file and is deleted as soon as it has been read.
final class WatchRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var heardSpeech = false
    private var quietSince: Date?
    private var startedAt = Date.now
    private var meter: VoiceMeter?
    private var onFinish: ((Data?) -> Void)?

    static let maximumDuration: TimeInterval = 30
    /// Stops when you have been quiet this long after speaking.
    static let silenceAfterSpeech: TimeInterval = 1.4
    /// Stops when nothing was said at all.
    static let silenceBeforeSpeech: TimeInterval = 6
    /// The first moment tells how loud the room is; speech is clearly louder than that.
    private static let calibration: TimeInterval = 0.4
    private static let speechAboveRoom: Float = 12
    private static let silenceAboveRoom: Float = 6
    private static let quietestRoom: Float = -60
    private static let loudestRoom: Float = -45
    private var roomLevel: Float = -60

    private var fileURL: URL {
        FileManager.default.temporaryDirectory.appending(path: "ayla-question.wav")
    }

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// Your voice moves the orb through `meter`. `onFinish` gets the recording, or nil when nothing was said.
    func start(meter: VoiceMeter, onFinish: @escaping (Data?) -> Void) throws {
        stopTimer()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record(forDuration: Self.maximumDuration) else { throw CocoaError(.fileWriteUnknown) }
        self.recorder = recorder
        self.meter = meter
        self.onFinish = onFinish
        heardSpeech = false
        quietSince = nil
        roomLevel = Self.quietestRoom
        startedAt = .now
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    /// Stop now and use what was said (the button was tapped).
    func finish() {
        complete(useRecording: true)
    }

    /// Stop and throw the recording away, without reporting back (leaving the app, a new conversation).
    func cancel() {
        complete(useRecording: false, report: false)
    }

    private func tick() {
        guard let recorder else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        meter?.update(microphone: max(0, min(1, (power + 50) / 40)))
        let now = Date.now
        if now.timeIntervalSince(startedAt) < Self.calibration {
            roomLevel = max(roomLevel, min(power, Self.loudestRoom))
            return
        }
        if power > roomLevel + Self.speechAboveRoom {
            heardSpeech = true
            quietSince = nil
        } else if power < roomLevel + Self.silenceAboveRoom {
            quietSince = quietSince ?? now
        }
        if heardSpeech, let quietSince, now.timeIntervalSince(quietSince) >= Self.silenceAfterSpeech {
            complete(useRecording: true)
        } else if !heardSpeech, now.timeIntervalSince(startedAt) >= Self.silenceBeforeSpeech {
            complete(useRecording: false)
        } else if now.timeIntervalSince(startedAt) >= Self.maximumDuration {
            complete(useRecording: true)
        }
    }

    private func complete(useRecording: Bool, report: Bool = true) {
        guard let recorder else { return }
        stopTimer()
        recorder.stop()
        self.recorder = nil
        let data = useRecording && heardSpeech ? try? Data(contentsOf: fileURL) : nil
        try? FileManager.default.removeItem(at: fileURL)
        meter?.reset()
        meter = nil
        let onFinish = onFinish
        self.onFinish = nil
        if report { onFinish?(data) }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
