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
                eyebrow: "Tweestapsverificatie",
                title: AuthMessages.authenticatorHeading,
                message: AuthMessages.authenticatorInstruction,
                steps: purpose == .passwordReset ? AuthMessages.resetSteps : nil,
                currentStep: 2
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                VerificationCodeField(
                    code: $code,
                    title: AuthMessages.authenticatorCodeLabel,
                    hint: AuthMessages.authenticatorCodeHint,
                    errorMessage: errorMessage,
                    isFocused: $isCodeFocused,
                    onComplete: submit
                )
                .onChange(of: code) { if !code.isEmpty { error = nil } }

                PavePrimaryButton(
                    title: error == nil ? "Bevestigen" : "Opnieuw proberen",
                    loadingTitle: "Bezig met controleren...",
                    isLoading: isSubmitting,
                    action: submit
                )

                PaveNotice(
                    title: "Kun je niet bij je authenticator-app?",
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
                PaveHaptics.success()
            } catch {
                self.error = AuthError(error)
                PaveHaptics.error()
                // As on the web: a wrong code empties the field and puts the cursor back for the next try.
                code = ""
                isCodeFocused = true
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
