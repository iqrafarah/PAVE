import SwiftUI
import TipKit

@main
struct PAVEApp: App {
    @UIApplicationDelegateAdaptor(PaveAppDelegate.self) private var appDelegate
    @State private var appState: AppState

    init() {
        let appState = AppState(authService: AuthServiceFactory.make())
        _appState = State(initialValue: appState)
        WatchBridge.shared.start(auth: appState.authService) { AppState.isSignedIn() }
        // Short tips the first time something new shows, such as the plan in the Dynamic Island.
        try? Tips.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                // The theme colour of the account, before it is loaded again.
                .onAppear { PaveAppearance.applyStored() }
        }
        .commands { PaveCommands() }
    }
}
