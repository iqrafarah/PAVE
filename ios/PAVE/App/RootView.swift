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
                AylaRootView(service: AylaServiceFactory.make(auth: appState.authService))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.phase)
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
