import SwiftUI

@main
struct PAVEApp: App {
    @UIApplicationDelegateAdaptor(PaveAppDelegate.self) private var appDelegate
    @State private var appState: AppState

    init() {
        let appState = AppState(authService: AuthServiceFactory.make())
        _appState = State(initialValue: appState)
        WatchBridge.shared.start(auth: appState.authService) { AppState.isSignedIn() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .commands { PaveCommands() }
    }
}
