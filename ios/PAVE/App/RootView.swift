import CoreSpotlight
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

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
                    // Back after being away too long: the PIN screen over the app, which stays as it was.
                    .overlay {
                        if appState.isRelocked {
                            PinLockView()
                                .transition(.opacity)
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.phase)
        .animation(.easeOut(duration: 0.2), value: appState.isRelocked)
        // In the app switcher and under Control Center only the logo shows.
        .overlay {
            if scenePhase != .active, appState.isOpen {
                PavePrivacyCover()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: appState.didEnterBackground()
            case .active: appState.didBecomeActive()
            default: break
            }
        }
        // Also while the app is locked: the chat opens once it is unlocked.
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            appState.conversationToOpen = AylaSpotlight.conversationID(in: activity)
        }
        .onContinueUserActivity(AylaHandoff.activityType) { activity in
            appState.conversationToOpen = AylaHandoff.conversationID(in: activity)
        }
        .onOpenURL { url in
            appState.link = PaveLink(url: url)
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
