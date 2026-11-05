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
        .onOpenURL { url in
            Task { await flow.openPasswordResetLink(url) }
        }
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
        case .resetEmailSent(let email):
            ResetEmailSentView(email: email)
        case .newPassword:
            NewPasswordView()
        case .passwordResetComplete:
            PasswordResetCompleteView()
        }
    }
}

#Preview {
    AuthFlowView(service: MockAuthService()) { _ in }
}
