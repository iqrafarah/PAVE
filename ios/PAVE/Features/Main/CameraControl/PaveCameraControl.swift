import AVFoundation
import Observation
import SwiftUI

/// One menu next to the Camera Control button: the items you swipe through, what a swipe does at once (going to a
/// page) and what a full press does with the item it rests on.
struct CameraMenu {
    let id: String
    let title: String
    /// An SF Symbol, as iOS draws the menu.
    let symbol: String
    let items: [String]
    /// What each item is (a folder's or a chat's id), so the screen can show which one is chosen.
    var keys: [String] = []
    var selected = 0
    var onSwipe: ((Int) -> Void)?
    var onPress: ((Int) -> Void)?

    /// Only a change in what can be chosen rebuilds the menus; a rebuild in the middle of a swipe would close them.
    var signature: String { id + "|" + items.joined(separator: "\u{1F}") }

    /// Menus whose choice lights up on the screen itself; the others get a short label at the top.
    static let litOnScreen: Set<String> = ["folders", "items", "answer", "item-files"]
}

/// Demo: going through PAVE with the Camera Control button. iOS only sends the button to an app that is using the
/// camera, so while "knopmodus" is on PAVE keeps a small camera session running that records and keeps nothing; the
/// green dot of iOS shows it, and it is switched off in Instellingen › Ayla. It runs while PAVE is in front and
/// unlocked.
/// - Light press: the menus of the screen you are on (such as the folders and evidence in the vault, the chats,
///   Ayla's answer or her vacancies), then "Ga naar" (swiping opens that page at once) and "Ayla".
/// - Double light press: switch between those menus.
/// - Full press: what the menu you swiped rests on; otherwise what the screen does with the button (scanning
///   evidence in the vault, ending a spoken conversation), or a conversation with Ayla.
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
    /// Knopmodus stays chosen: it starts again whenever PAVE is open and unlocked.
    static let enabledKey = "cameraControlEnabled"

    /// The item a swipe rests on in a menu that waits for a full press, shown on the screen meanwhile.
    struct Highlight: Equatable {
        let menu: String
        let key: String
        let title: String
        let menuTitle: String
    }

    private(set) var isOn = false
    private(set) var isStarting = false
    private(set) var highlight: Highlight?
    /// The screen in front that brought its own menus: it shows the label of a choice.
    private(set) var topSource: String?
    /// iOS shows the menus next to the button: they are only rebuilt once it closes them, so a swipe that opens a
    /// large page (with menus of its own) never closes them under your finger.
    private(set) var isMenuOpen = false
    private(set) var problem: Problem?
    /// For a moment without the camera, such as while the document scanner of iOS uses it.
    var isSuspended = false
    /// Read by views so they update when the choice changes.
    private(set) var enabledChanged = 0

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            enabledChanged += 1
        }
    }

    @ObservationIgnored var onGoTo: (MainDestination) -> Void = { _ in }
    @ObservationIgnored var onAyla: (AylaAction) -> Void = { _ in }

    @ObservationIgnored let camera = CameraControlSession()
    @ObservationIgnored private var screens: [(source: String, menus: [CameraMenu], press: (() -> Void)?)] = []
    @ObservationIgnored private var applied: [CameraMenu] = []
    /// The menu last swiped and the item it rests on, until a full press uses it.
    @ObservationIgnored private var active: (menu: Int, item: Int)?
    @ObservationIgnored private var destination = MainDestination.ayla
    @ObservationIgnored private var pendingSwipe: Task<Void, Never>?
    @ObservationIgnored private var needsApply = false
    @ObservationIgnored private var highlightTimeout: Task<Void, Never>?

    func start(at destination: MainDestination) async {
        guard !isOn, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        problem = nil
        self.destination = destination
        guard await Self.cameraAllowed() else {
            problem = .notAllowed
            return
        }
        let visibility: @Sendable (Bool) -> Void = { [weak self] isOpen in
            Task { @MainActor in self?.menuVisibilityChanged(isOpen) }
        }
        switch await camera.start(onMenuVisibility: visibility) {
        case .started:
            isOn = true
            apply(force: true)
        case .noCamera:
            problem = .noCamera
        case .noButton:
            problem = .noButton
        }
    }

    func stop() {
        pendingSwipe?.cancel()
        active = nil
        clearHighlight()
        isMenuOpen = false
        needsApply = false
        guard isOn else { return }
        isOn = false
        camera.stop()
    }

    /// The menus of the screen that is in front; the newest screen wins until it goes away.
    func setMenus(_ menus: [CameraMenu], press: (() -> Void)?, source: String) {
        screens.removeAll { $0.source == source }
        screens.append((source, menus, press))
        if topSource != source { topSource = source }
        apply()
    }

    func clearMenus(source: String) {
        screens.removeAll { $0.source == source }
        if topSource != screens.last?.source { topSource = screens.last?.source }
        apply()
    }

    /// A full press (or a volume button, which iOS treats the same while the camera is in use).
    func fullPress() {
        guard isOn else { return }
        defer {
            active = nil
            clearHighlight()
        }
        if let active, applied.indices.contains(active.menu), let onPress = applied[active.menu].onPress {
            onPress(active.item)
        } else if let press = screens.last?.press {
            press()
        } else {
            onAyla(.talk)
        }
    }

    /// The page changed by a tap: "Ga naar" shows it the next time.
    func show(_ destination: MainDestination) {
        self.destination = destination
        guard isOn, let menu = applied.firstIndex(where: { $0.id == "goTo" }), let item = Self.destinations.firstIndex(of: destination) else { return }
        applied[menu].selected = item
        camera.select(menu: menu, item: item)
    }

    private var allMenus: [CameraMenu] {
        var menus = (screens.last?.menus ?? []).filter { !$0.items.isEmpty }
        menus.append(CameraMenu(
            id: "goTo", title: "Ga naar", symbol: "arrow.triangle.turn.up.right.circle",
            items: Self.destinations.map(\.title), selected: Self.destinations.firstIndex(of: destination) ?? 0,
            onSwipe: { [weak self] item in self?.onGoTo(Self.destinations[item]) }
        ))
        menus.append(CameraMenu(
            id: "ayla", title: "Ayla", symbol: "waveform", items: AylaAction.allCases.map(\.title), keys: AylaAction.allCases.map { String($0.rawValue) },
            onPress: { [weak self] item in
                guard let action = AylaAction(rawValue: item) else { return }
                self?.onAyla(action)
            }
        ))
        return Array(menus.prefix(camera.maximumMenus))
    }

    private func apply(force: Bool = false) {
        guard isOn else { return }
        if isMenuOpen, !force {
            needsApply = true
            return
        }
        let menus = allMenus
        let changed = force || menus.map(\.signature) != applied.map(\.signature)
        applied = menus
        guard changed else { return }
        active = nil
        clearHighlight()
        camera.apply(menus.map { .init(title: $0.title, symbol: $0.symbol, items: $0.items, selected: $0.selected) }) { [weak self] menu, item in
            Task { @MainActor in self?.swiped(menu: menu, item: item) }
        }
    }

    private func swiped(menu: Int, item: Int) {
        guard isOn, applied.indices.contains(menu), applied[menu].items.indices.contains(item) else { return }
        active = (menu, item)
        applied[menu].selected = item
        guard let onSwipe = applied[menu].onSwipe else {
            let chosen = applied[menu]
            highlight = Highlight(
                menu: chosen.id,
                key: chosen.keys.indices.contains(item) ? chosen.keys[item] : String(item),
                title: chosen.items[item],
                menuTitle: chosen.title
            )
            // A choice nobody pressed for fades away after a while.
            highlightTimeout?.cancel()
            highlightTimeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                self?.highlight = nil
                self?.active = nil
            }
            return
        }
        clearHighlight()
        // While swiping through a menu, only the item it rests on happens.
        pendingSwipe?.cancel()
        pendingSwipe = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            onSwipe(item)
        }
    }

    private func menuVisibilityChanged(_ isOpen: Bool) {
        isMenuOpen = isOpen
        guard !isOpen, needsApply else { return }
        needsApply = false
        apply()
    }

    private func clearHighlight() {
        highlightTimeout?.cancel()
        highlight = nil
    }

    private static func cameraAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }
}

/// The camera session behind the button: the back camera at the lowest quality, frames dropped at once, and the
/// menus. Everything runs on its own queue, as AVFoundation wants.
nonisolated final class CameraControlSession: NSObject, AVCaptureSessionControlsDelegate, @unchecked Sendable {
    enum StartResult {
        case started
        case noCamera
        case noButton
    }

    struct Menu: Sendable {
        let title: String
        let symbol: String
        let items: [String]
        let selected: Int
    }

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "nl.fontys.pave.camera-control")
    private var pickers: [AVCaptureIndexPicker] = []
    private let lock = NSLock()
    private var maximum = 7
    private var onMenuVisibility: (@Sendable (Bool) -> Void)?

    var maximumMenus: Int { lock.withLock { maximum } }

    func start(onMenuVisibility: @escaping @Sendable (Bool) -> Void) async -> StartResult {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                self.onMenuVisibility = onMenuVisibility
                let result = configure()
                if result == .started { session.startRunning() }
                continuation.resume(returning: result)
            }
        }
    }

    private func configure() -> StartResult {
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
        lock.withLock { maximum = session.maxControlsCount }
        session.setControlsDelegate(self, queue: queue)
        return .started
    }

    /// Puts these menus next to the button, in this order. `onSwipe` hears which menu and item a swipe rests on.
    func apply(_ menus: [Menu], onSwipe: @escaping @Sendable (Int, Int) -> Void) {
        queue.async { [self] in
            session.beginConfiguration()
            session.controls.forEach(session.removeControl)
            pickers = []
            for (index, menu) in menus.enumerated() where !menu.items.isEmpty {
                let picker = AVCaptureIndexPicker(menu.title, symbolName: menu.symbol, localizedIndexTitles: menu.items)
                picker.selectedIndex = min(max(menu.selected, 0), menu.items.count - 1)
                picker.setActionQueue(queue) { item in onSwipe(index, item) }
                guard session.canAddControl(picker) else { continue }
                session.addControl(picker)
                pickers.append(picker)
            }
            session.commitConfiguration()
        }
    }

    /// The item a menu shows, when it changed elsewhere (a page opened by a tap).
    func select(menu: Int, item: Int) {
        queue.async { [self] in
            guard pickers.indices.contains(menu), pickers[menu].selectedIndex != item,
                  pickers[menu].localizedIndexTitles.indices.contains(item) else { return }
            pickers[menu].selectedIndex = item
        }
    }

    /// The camera's picture, for the layer behind PAVE's screen: iOS only treats an app as a camera app (and sends
    /// it the button) when it shows what the camera sees.
    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    func stop() {
        queue.async { [self] in
            session.stopRunning()
        }
    }

    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) { onMenuVisibility?(true) }
    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {}
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {}
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) { onMenuVisibility?(false) }
}

extension View {
    /// The Camera Control menus of this screen while it is in front, and what a full press does here.
    func cameraControlMenus(_ source: String, menus: [CameraMenu], press: (() -> Void)? = nil) -> some View {
        modifier(CameraControlMenus(source: source, menus: menus, press: press))
    }
}

private struct CameraControlMenus: ViewModifier {
    let source: String
    let menus: [CameraMenu]
    let press: (() -> Void)?
    @Environment(PaveCameraControl.self) private var control: PaveCameraControl?

    func body(content: Content) -> some View {
        content
            // What the button rests on, when it does not light up on the screen itself.
            .overlay(alignment: .top) {
                if let control, control.topSource == source, let highlight = control.highlight, !CameraMenu.litOnScreen.contains(highlight.menu) {
                    AylaHeadHint(text: "\(highlight.menuTitle): \(highlight.title)", isAnswer: true)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.spring(duration: 0.3, bounce: 0.2), value: control?.highlight)
            .onChange(of: menus.map(\.signature) + [press == nil ? "" : "press"], initial: true) {
                control?.setMenus(menus, press: press, source: source)
            }
            // The newest closures each time the screen updates, without rebuilding the menus.
            .onChange(of: control?.isOn) { control?.setMenus(menus, press: press, source: source) }
            .onDisappear { control?.clearMenus(source: source) }
    }
}
