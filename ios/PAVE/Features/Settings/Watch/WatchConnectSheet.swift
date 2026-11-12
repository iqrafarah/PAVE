import SwiftUI

/// "Apple Watch koppelen", told like unboxing a new card: the lid of a PAVE box swings open, a real Apple Watch rises
/// out showing the PAVE Watch app as it is now ("Koppel je Watch") and the box sinks away. Koppelen streams pixels from
/// the iPhone into the Watch inside a spinning ring; once the Watch has access the ring closes and the Watch shows Ayla,
/// ready to listen. Already connected, it shows that and can disconnect.
struct WatchConnectSheet: View {
    @Environment(WatchConnectionModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Stage: Equatable {
        case boxed
        case ready
        case connecting
        case connected
    }

    @State private var stage = Stage.boxed
    @State private var lidOpen = false
    @State private var watchOut = false
    @State private var boxGone = false
    @State private var problem: String?
    @State private var confirmsDisconnect = false

    private var canConnect: Bool { model.availability == .ready }
    /// The scene is 340 high with the box front centred 90 below the middle and 120 high.
    private static let sceneHeight: CGFloat = 340
    private static let frontCenter: CGFloat = 90
    private static let boxBottom: CGFloat = sceneHeight / 2 + frontCenter + WatchGiftBox.frontHeight / 2

    private var screenContent: WatchScreenPreview.Content {
        switch stage {
        case .boxed, .ready: .notConnected
        case .connecting: .connecting
        case .connected: .ready
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            scene
                .frame(height: Self.sceneHeight)
                .frame(maxWidth: .infinity)
                .clipped()
            VStack(spacing: 10) {
                Text(title)
                    .textStyle(.emptyTitle)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                if let problem {
                    PaveInlineError(message: problem)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 440)
            Spacer(minLength: 16)
            Spacer(minLength: 0)
            buttons
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
                .frame(maxWidth: 480)
        }
        .animation(.snappy(duration: 0.35), value: stage)
        .animation(.snappy(duration: 0.35), value: problem)
        .background(Color.canvas.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(stage == .connecting)
        .task { await start() }
        .confirmationDialog(WatchConnectMessages.disconnectQuestion, isPresented: $confirmsDisconnect, titleVisibility: .visible) {
            Button("Ontkoppelen", role: .destructive) {
                Task {
                    await model.disconnect()
                    dismiss()
                }
            }
        } message: {
            Text(WatchConnectMessages.disconnectMessage)
        }
    }

    // MARK: The scene

    private var scene: some View {
        ZStack {
            RadialGradient(colors: [.orbShade3.opacity(0.32), .orbShade3.opacity(0.12), .clear], center: .center, startRadius: 20, endRadius: 200)
                .scaleEffect(stage == .connecting ? 1.15 : 1)
                .opacity(watchOut ? 1 : 0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(), value: stage == .connecting)
            if stage == .connecting {
                WatchPixelStream(target: Self.sceneHeight / 2)
                    .transition(.opacity)
            }
            if stage == .connecting || stage == .connected {
                WatchConnectRing(isDone: stage == .connected, size: 290)
                    .offset(y: -8)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            // The Watch rests on the surface: a soft shadow under it once it is out.
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 120, height: 16)
                .blur(radius: 10)
                .offset(y: 132)
                .opacity(boxGone ? 1 : 0)
            ZStack {
                WatchGiftBox.Back()
                    .offset(y: Self.frontCenter - 16)
                    .opacity(boxGone ? 0 : 1)
                // Hidden while the lid is closed, so nothing of it shows above the box.
                floatingWatch
                    .opacity(lidOpen ? 1 : 0)
                    .offset(y: watchOut ? -8 : 134)
                    .scaleEffect(watchOut ? 1 : 0.86)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Nothing of the Watch shows below the box while it is still inside.
                    .mask(alignment: .top) {
                        Rectangle().frame(height: boxGone ? 1000 : Self.boxBottom)
                    }
                ZStack {
                    WatchGiftBox.Front()
                        .offset(y: Self.frontCenter)
                    WatchGiftBox.Lid(isOpen: lidOpen)
                        .offset(y: Self.frontCenter - WatchGiftBox.frontHeight / 2 - WatchGiftBox.lidHeight / 2)
                }
                .offset(y: boxGone ? 120 : 0)
                .scaleEffect(boxGone ? 0.85 : 1)
                .opacity(boxGone ? 0 : 1)
                .blur(radius: boxGone ? 8 : 0)
            }
            .saturation(canConnect || stage == .connected ? 1 : 0.2)
        }
        .accessibilityHidden(true)
    }

    private var floatingWatch: some View {
        TimelineView(.animation(paused: reduceMotion || !watchOut)) { context in
            WatchIllustration(width: 150) {
                WatchScreenPreview(content: screenContent)
            }
            .offset(y: reduceMotion ? 0 : sin(context.date.timeIntervalSinceReferenceDate * 1.5) * 3)
        }
    }

    // MARK: Text and buttons

    private var title: String {
        switch stage {
        case .connected: WatchConnectMessages.connectedTitle
        case .connecting: WatchConnectMessages.connectingTitle
        case .boxed, .ready:
            switch model.availability {
            case .noWatch: WatchConnectMessages.noWatchTitle
            case .appMissing: WatchConnectMessages.appMissingTitle
            case .ready: WatchConnectMessages.title
            }
        }
    }

    private var message: String {
        switch stage {
        case .connected: WatchConnectMessages.connectedMessage(since: model.connection?.connectedAt)
        case .connecting: WatchConnectMessages.connectingMessage
        case .boxed, .ready:
            switch model.availability {
            case .noWatch: WatchConnectMessages.noWatchMessage
            case .appMissing: WatchConnectMessages.appMissingMessage
            case .ready: WatchConnectMessages.message
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: 10) {
            switch stage {
            case .boxed, .ready:
                if canConnect {
                    PavePrimaryButton(title: "Koppelen") { Task { await connect() } }
                        .disabled(stage == .boxed)
                } else {
                    PaveSecondaryButton(title: "Opnieuw kijken", icon: .iconArrowPath) { Task { await model.refresh() } }
                }
            case .connecting:
                PavePrimaryButton(title: "Koppelen", loadingTitle: "Koppelen…", isLoading: true) {}
            case .connected:
                PavePrimaryButton(title: "Klaar") { dismiss() }
                Button("Ontkoppelen") { confirmsDisconnect = true }
                    .textStyle(.button)
                    .foregroundStyle(Color.critical)
                    .frame(minHeight: 44)
            }
        }
    }

    // MARK: Steps

    private func start() async {
        await model.refresh()
        if model.isConnected {
            lidOpen = true
            watchOut = true
            boxGone = true
            stage = .connected
            return
        }
        guard !reduceMotion else {
            lidOpen = true
            withAnimation(.easeInOut(duration: 0.4)) {
                watchOut = true
                boxGone = true
                stage = .ready
            }
            return
        }
        try? await Task.sleep(for: .milliseconds(450))
        PaveHaptics.tap(.light)
        withAnimation(.spring(duration: 0.7, bounce: 0.25)) { lidOpen = true }
        try? await Task.sleep(for: .milliseconds(380))
        PaveHaptics.tap(.soft)
        withAnimation(.spring(duration: 0.95, bounce: 0.32)) { watchOut = true }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeOut(duration: 0.7)) { boxGone = true }
        stage = .ready
    }

    private func connect() async {
        problem = nil
        stage = .connecting
        PaveHaptics.tap(.medium)
        async let pause: Void = Task.sleep(for: .milliseconds(reduceMotion ? 400 : 1900))
        let connected = await model.connect()
        try? await pause
        if connected {
            PaveHaptics.success()
            stage = .connected
        } else {
            PaveHaptics.error()
            problem = WatchConnectMessages.signInFirst
            stage = .ready
        }
    }
}

#Preview("Koppelen") {
    Color.canvas.sheet(isPresented: .constant(true)) {
        WatchConnectSheet()
            .environment(WatchConnectionModel(previewAvailability: .ready))
    }
}

#Preview("Gekoppeld") {
    Color.canvas.sheet(isPresented: .constant(true)) {
        WatchConnectSheet()
            .environment(WatchConnectionModel(previewAvailability: .ready, connection: WatchConnection(connectedAt: .now, lastActiveAt: nil)))
    }
}
