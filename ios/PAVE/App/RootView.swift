import CoreSpotlight
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.phase {
            case .loading:
                LoadingView()
            case .signedOut:
                AuthFlowView(service: appState.authService, onSignedIn: appState.signIn(accountID:))
            case .pinSetup:
                PinSetupView()
            case .locked:
                PinLockView()
            case .main:
                MainView(service: AylaServiceFactory.make(auth: appState.authService))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.phase)
        // Also while the app is locked: the chat opens once it is unlocked.
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            appState.conversationToOpen = AylaSpotlight.conversationID(in: activity)
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
