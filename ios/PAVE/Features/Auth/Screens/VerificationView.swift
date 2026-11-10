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
                emblem: .iconDevicePhoneMobile,
                eyebrow: purpose == .signIn ? "Tweestapsverificatie" : "Wachtwoord herstellen",
                title: "Vul de code uit je authenticator-app in",
                message: purpose == .signIn
                    ? "Open je authenticator-app en neem de code van 6 cijfers voor PAVE over. Je krijgt hem niet per mail."
                    : "Voor je account staat tweestapsverificatie aan. Neem de code over uit je authenticator-app, niet uit je mail. Daarna kies je een nieuw wachtwoord."
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
                    title: "Kun je niet bij de app?",
                    message: SupportText.sentence("Neem contact op via ")
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
