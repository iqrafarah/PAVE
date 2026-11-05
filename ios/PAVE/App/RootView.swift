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
                ContentUnavailableView {
                    Label("Home", systemImage: "house")
                } description: {
                    Text("Volgt in week 2.")
                } actions: {
                    Button("Uitloggen") {
                        appState.signOut()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.phase)
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
