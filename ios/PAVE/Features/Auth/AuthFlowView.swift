import PAVECore
import SwiftUI

struct AuthFlowView: View {
    @State private var flow: AuthFlow

    init(service: any AuthService, onSignedIn: @escaping (String?) -> Void) {
        _flow = State(initialValue: AuthFlow(service: service, onSignedIn: onSignedIn))
    }

    var body: some View {
        NavigationStack(path: $flow.path) {
            SignInView()
                .navigationDestination(for: AuthRoute.self, destination: screen)
        }
        .environment(flow)
        // Signing in goes with eduID: its blue on the controls, as on the web. RootView turns it off as soon as the
        // app leaves signing in, so the PIN screen after it never shows eduID.
        .onAppear { PaveThemeStore.shared.usesEduID = true }
    }

    @ViewBuilder
    private func screen(for route: AuthRoute) -> some View {
        switch route {
        case .verification:
            VerificationView()
        case .verificationSetup:
            VerificationSetupView()
        case .verificationSetupComplete:
            VerificationSetupCompleteView()
        case .forgotPassword:
            ForgotPasswordView()
        case .resetCode(let email):
            ResetCodeView(email: email)
        case .resetVerification:
            VerificationView(purpose: .passwordReset)
        case .newPassword:
            NewPasswordView()
        case .passwordResetComplete:
            PasswordResetCompleteView()
        case .register:
            RegisterView()
        case .registerCode(let email):
            RegisterCodeView(email: email)
        }
    }
}

#Preview {
    AuthFlowView(service: MockAuthService()) { _ in }
}
