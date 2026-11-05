import PAVECore
import SwiftUI

struct VerificationSetupCompleteView: View {
    @Environment(AuthFlow.self) private var flow

    var body: some View {
        AuthScreen {
            VStack(alignment: .leading, spacing: 24) {
                AuthIntro(
                    emblem: .iconCheckCircle,
                    eyebrow: "Setup complete",
                    title: "You’re all set",
                    message: "Two-step verification is now enabled for your PAVE account."
                )
                PaveNotice(
                    title: "Your portfolio has extra protection",
                    message: "Next time you sign in, use your password and a code from your authenticator app. Keep the app on your phone."
                )
                PavePrimaryButton(title: "Continue to PAVE", action: flow.finishVerificationSetup)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

struct PasswordResetCompleteView: View {
    @Environment(AuthFlow.self) private var flow

    var body: some View {
        AuthScreen {
            VStack(alignment: .leading, spacing: 24) {
                AuthIntro(
                    emblem: .iconCheckCircle,
                    eyebrow: "Password recovery complete",
                    title: "Password updated",
                    message: "Your new password is saved. You can now sign in to PAVE with it."
                )
                PaveNotice(
                    title: "Two-step verification is still enabled",
                    message: "Resetting your password doesn’t change your extra protection. Keep your authenticator app ready when you sign in."
                )
                PavePrimaryButton(title: "Return to login", action: flow.returnToLogin)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

#Preview("Setup complete") {
    NavigationStack {
        VerificationSetupCompleteView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}

#Preview("Password updated") {
    NavigationStack {
        PasswordResetCompleteView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}
