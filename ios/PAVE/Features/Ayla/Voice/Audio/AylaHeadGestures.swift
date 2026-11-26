import AVFAudio
import CoreMotion
import Observation
import PAVECore

/// Ja and Nee by nodding or shaking the head with AirPods on, wherever Ayla asks for one of them. It only follows the
/// head while such a question is open, and asks for the motion permission only once AirPods or other Bluetooth
/// headphones are connected. Nothing of the motion leaves the device.
@MainActor
@Observable
final class AylaHeadGestures {
    /// The head's motion is coming in: AirPods that can follow it are in, so a nod works now.
    private(set) var isReceiving = false

    @ObservationIgnored private let manager = CMHeadphoneMotionManager()
    @ObservationIgnored private var detector = AylaHeadGestureDetector()
    @ObservationIgnored private var turns = AylaHeadTurnDetector()
    /// Also turning the head to a side, to go through cards.
    @ObservationIgnored private var followsTurns = false
    @ObservationIgnored private var onGesture: ((AylaHeadGesture) -> Void)?
    @ObservationIgnored private var lastSampleAt = Date.distantPast
    @ObservationIgnored private var watch: Task<Void, Never>?

    var isListening: Bool { onGesture != nil }

    func start(followsTurns: Bool = false, onGesture: @escaping (AylaHeadGesture) -> Void) {
        self.onGesture = onGesture
        if followsTurns != self.followsTurns { turns.reset() }
        self.followsTurns = followsTurns
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .denied, .restricted:
            return
        case .notDetermined:
            // The question for the permission makes sense only with headphones in.
            guard Self.hasBluetoothHeadphones else { return }
        default:
            break
        }
        detector.reset()
        turns.reset()
        // When the motion stops coming in (iOS gives none while the AirPods' microphone is in use), the hint goes away
        // instead of promising a nod that cannot be felt.
        watch?.cancel()
        watch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if isReceiving, Date.now.timeIntervalSince(lastSampleAt) > 1.5 { isReceiving = false }
            }
        }
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let time = motion.timestamp
            let pitch = motion.attitude.pitch
            let yaw = motion.attitude.yaw
            MainActor.assumeIsolated { self?.received(time: time, pitch: pitch, yaw: yaw) }
        }
    }

    func stop() {
        onGesture = nil
        isReceiving = false
        watch?.cancel()
        watch = nil
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }

    private func received(time: TimeInterval, pitch: Double, yaw: Double) {
        lastSampleAt = .now
        if !isReceiving { isReceiving = true }
        if followsTurns, let turn = turns.add(time: time, yaw: yaw) {
            onGesture?(turn == .left ? .turnLeft : .turnRight)
            return
        }
        guard let gesture = detector.add(time: time, pitch: pitch, yaw: yaw) else { return }
        onGesture?(gesture)
    }

    static var hasBluetoothHeadphones: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains { output in
            [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(output.portType)
        }
    }
}
