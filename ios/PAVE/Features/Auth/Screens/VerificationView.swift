import PAVECore
import SwiftUI

struct VerificationView: View {
    enum Purpose {
        case signIn
        case passwordReset
    }

    var purpose: Purpose = .signIn

    @Environment(AuthFlow.self) private var flow
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var error: AuthError?
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        AuthScreen {
            AuthIntro(
                emblem: .iconShieldCheck,
                eyebrow: purpose == .signIn ? "Tweestapsverificatie" : "Wachtwoord herstellen",
                title: "Bevestig dat jij het bent",
                message: purpose == .signIn
                    ? "Open je authenticator-app en vul de code van 6 cijfers voor je PAVE-account in."
                    : "Voor je account staat tweestapsverificatie aan. Vul de code uit je authenticator-app in. Daarna kies je een nieuw wachtwoord."
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                VerificationCodeField(code: $code, errorMessage: errorMessage, isFocused: $isCodeFocused)
                    .onChange(of: code) { error = nil }

                PavePrimaryButton(
                    title: error == nil ? "Bevestigen" : "Opnieuw proberen",
                    loadingTitle: "Bezig met controleren...",
                    isLoading: isSubmitting,
                    action: submit
                )

                PaveNotice(
                    title: "Gebruik je authenticator-app",
                    message: SupportText.sentence("Je code komt uit je authenticator-app, niet via e-mail of sms. Kun je niet bij de app? Neem contact op via ")
                )

                AuthReturnButton(action: flow.returnToLogin)
            }
        }
        .onAppear { isCodeFocused = true }
    }

    private var errorMessage: String? {
        error?.message
    }

    private func submit() {
        guard !isSubmitting else { return }
        isCodeFocused = false
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                switch purpose {
                case .signIn:
                    try await flow.verify(code: code)
                case .passwordReset:
                    try await flow.verifyForPasswordReset(code: code)
                }
            } catch {
                self.error = AuthError(error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        VerificationView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}
