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
            case .sessionEnded:
                SessionEndedView(onSignInAgain: appState.signInAgain)
            case .pinSetup:
                PinSetupView()
            case .locked:
                PinLockView()
            case .main:
                MainView(
                    service: AylaServiceFactory.make(auth: appState.authService),
                    vaultService: VaultServiceFactory.make(auth: appState.authService),
                    notificationsService: NotificationsServiceFactory.make(auth: appState.authService)
                )
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
        // While the app is open, check every minute whether the session still exists, so a password change on
        // another device sends you to sign in again straight away.
        .task(id: SessionCheck(isActive: scenePhase == .active, phase: appState.phase)) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await appState.checkSession()
                try? await Task.sleep(for: .seconds(60))
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

private struct SessionCheck: Equatable {
    let isActive: Bool
    let phase: AppPhase
}

#Preview {
    RootView()
        .environment(AppState())
}
