import AVFoundation
import Observation

/// Demo: going through PAVE with the Camera Control button. iOS only sends the button to an app that is using the
/// camera, so while this "knopmodus" is on PAVE keeps a small camera session running that records and keeps nothing;
/// the green dot shows it, and so does the badge in PAVE with Stop. It switches itself off after a few minutes
/// without the button, and when PAVE leaves the screen.
/// - Light press: the menu "Ga naar" next to the button; swiping moves to that screen at once.
/// - Double light press: the other menu, "Ayla" (talk, new chat, chats).
/// - Full press: what was chosen in "Ayla"; without a choice, a conversation with Ayla.
@MainActor
@Observable
final class PaveCameraControl {
    enum Problem: Equatable {
        case notAllowed
        case noCamera
        /// This iPhone has no Camera Control.
        case noButton
    }

    enum AylaAction: Int, CaseIterable {
        case talk
        case newConversation
        case chats

        var title: String {
            switch self {
            case .talk: "Praat met Ayla"
            case .newConversation: "Nieuw gesprek"
            case .chats: "Chats"
            }
        }
    }

    static let destinations: [MainDestination] = [.ayla, .vault, .plan, .profile, .notifications, .settings]
    static let idleTime = Duration.seconds(180)

    private(set) var isOn = false
    private(set) var isStarting = false
    private(set) var problem: Problem?

    @ObservationIgnored var onGoTo: (MainDestination) -> Void = { _ in }
    @ObservationIgnored var onAyla: (AylaAction) -> Void = { _ in }

    @ObservationIgnored private let camera = CameraControlSession()
    @ObservationIgnored private var aylaChoice: AylaAction?
    @ObservationIgnored private var pendingGoTo: Task<Void, Never>?
    @ObservationIgnored private var idle: Task<Void, Never>?

    func start(at destination: MainDestination) async {
        guard !isOn, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        problem = nil
        guard await Self.cameraAllowed() else {
            problem = .notAllowed
            return
        }
        let selected = Self.destinations.firstIndex(of: destination) ?? 0
        let result = await camera.start(
            goTo: Self.destinations.map(\.title),
            selected: selected,
            ayla: AylaAction.allCases.map(\.title),
            onGoTo: { [weak self] index in Task { @MainActor in self?.choseScreen(index) } },
            onAyla: { [weak self] index in Task { @MainActor in self?.choseAyla(index) } }
        )
        switch result {
        case .started:
            isOn = true
            touched()
        case .noCamera:
            problem = .noCamera
        case .noButton:
            problem = .noButton
        }
    }

    func stop() {
        idle?.cancel()
        pendingGoTo?.cancel()
        aylaChoice = nil
        guard isOn else { return }
        isOn = false
        camera.stop()
    }

    /// A full press (or a volume button, which iOS treats the same while the camera is in use).
    func fullPress() {
        guard isOn else { return }
        touched()
        onAyla(aylaChoice ?? .talk)
        aylaChoice = nil
    }

    /// The screen changed by a tap: the menu shows it the next time.
    func show(_ destination: MainDestination) {
        guard isOn, let index = Self.destinations.firstIndex(of: destination) else { return }
        camera.select(goTo: index)
    }

    private func choseScreen(_ index: Int) {
        guard isOn, Self.destinations.indices.contains(index) else { return }
        touched()
        // While swiping through the menu, only the screen it rests on opens.
        pendingGoTo?.cancel()
        pendingGoTo = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            onGoTo(Self.destinations[index])
        }
    }

    private func choseAyla(_ index: Int) {
        guard isOn else { return }
        touched()
        aylaChoice = AylaAction(rawValue: index)
    }

    private func touched() {
        idle?.cancel()
        idle = Task { [weak self] in
            try? await Task.sleep(for: Self.idleTime)
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    private static func cameraAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }
}


/// The camera session behind the button: the back camera at the lowest quality, frames dropped at once, and the two
/// menus. Everything runs on its own queue, as AVFoundation wants.
nonisolated final class CameraControlSession: NSObject, AVCaptureSessionControlsDelegate, @unchecked Sendable {
    enum StartResult {
        case started
        case noCamera
        case noButton
    }

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "nl.fontys.pave.camera-control")
    private var goToPicker: AVCaptureIndexPicker?

    func start(
        goTo: [String], selected: Int, ayla: [String],
        onGoTo: @escaping @Sendable (Int) -> Void, onAyla: @escaping @Sendable (Int) -> Void
    ) async -> StartResult {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                let result = configure(goTo: goTo, selected: selected, ayla: ayla, onGoTo: onGoTo, onAyla: onAyla)
                if result == .started { session.startRunning() }
                continuation.resume(returning: result)
            }
        }
    }

    private func configure(
        goTo: [String], selected: Int, ayla: [String],
        onGoTo: @escaping @Sendable (Int) -> Void, onAyla: @escaping @Sendable (Int) -> Void
    ) -> StartResult {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .low
        if session.inputs.isEmpty {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return .noCamera }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(output) { session.addOutput(output) }
        }
        guard session.supportsControls else { return .noButton }
        session.setControlsDelegate(self, queue: queue)
        session.controls.forEach(session.removeControl)

        let goToPicker = AVCaptureIndexPicker("Ga naar", symbolName: "arrow.triangle.turn.up.right.circle", localizedIndexTitles: goTo)
        goToPicker.selectedIndex = selected
        goToPicker.setActionQueue(queue) { index in onGoTo(index) }
        let aylaPicker = AVCaptureIndexPicker("Ayla", symbolName: "waveform", localizedIndexTitles: ayla)
        aylaPicker.setActionQueue(queue) { index in onAyla(index) }
        for control in [goToPicker, aylaPicker] where session.canAddControl(control) {
            session.addControl(control)
        }
        self.goToPicker = goToPicker
        return .started
    }

    func select(goTo index: Int) {
        queue.async { [self] in
            guard let goToPicker, goToPicker.selectedIndex != index else { return }
            goToPicker.selectedIndex = index
        }
    }

    func stop() {
        queue.async { [self] in
            session.stopRunning()
        }
    }

    // The menus show and hide by themselves; PAVE needs nothing from these moments.
    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {}
    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {}
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {}
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {}
}
