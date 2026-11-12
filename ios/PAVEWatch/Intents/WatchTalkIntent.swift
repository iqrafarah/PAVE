import AppIntents

/// "Praat met Ayla in PAVE" on the Watch, from Siri or Shortcuts: opens PAVE and the orb starts listening at once.
struct WatchTalkIntent: AppIntent {
    static let title: LocalizedStringResource = "Praat met Ayla"
    static let description = IntentDescription("Open PAVE op je Apple Watch en begin meteen te praten met Ayla.")
    static let supportedModes: IntentModes = .foreground

    func perform() async throws -> some IntentResult {
        await WatchLaunchRequest.listen()
        return .result()
    }
}

/// The same phrases as on the iPhone, so it works the same on both.
struct WatchAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WatchTalkIntent(),
            phrases: [
                "Praat met Ayla in \(.applicationName)",
                "Start een gesprek met Ayla in \(.applicationName)",
                "\(.applicationName) praat met Ayla",
            ],
            shortTitle: "Praat met Ayla",
            systemImageName: "waveform"
        )
    }
}

/// Carries "start listening" from Siri to the orb, also when the app still has to start.
@MainActor
enum WatchLaunchRequest {
    private(set) static var wantsToListen = false
    static var onListen: (() -> Void)?

    static func listen() {
        if let onListen {
            onListen()
        } else {
            wantsToListen = true
        }
    }

    /// Called by the screen once it is ready; true when Siri asked to listen before that.
    static func takePending() -> Bool {
        defer { wantsToListen = false }
        return wantsToListen
    }
}
