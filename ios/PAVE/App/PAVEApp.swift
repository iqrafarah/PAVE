import SwiftUI

@main
struct PAVEApp: App {
    @UIApplicationDelegateAdaptor(PaveAppDelegate.self) private var appDelegate
    @State private var appState = AppState(authService: AuthServiceFactory.make())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .commands { PaveCommands() }
    }
}
