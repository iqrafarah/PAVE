import PAVECore
import SwiftUI

struct ResetCodeView: View {
    let email: String

    @Environment(AuthFlow.self) private var flow
    @State private var code = ""
    @State private var isChecking = false
    @State private var isResending = false
    @State private var codeError: AuthError?
    private static let resentMessage = "We hebben een nieuwe code gestuurd."

    @State private var resendError: AuthError?
    @State private var resendMessage: String?
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        AuthScreen {
            AuthIntro(
                emblem: .iconMailOpen,
                eyebrow: "Wachtwoord herstellen",
                title: "Check je inbox",
                message: AuthMessages.resetRequested
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                VerificationCodeField(
                    code: $code,
                    hint: "Vul de code uit de e-mail in.",
                    errorMessage: codeErrorMessage,
                    isFocused: $isCodeFocused
                )
                .onChange(of: code) { codeError = nil }

                PavePrimaryButton(
                    title: codeError == nil ? "Code bevestigen" : "Opnieuw proberen",
                    loadingTitle: "Bezig met controleren...",
                    isLoading: isChecking,
                    action: check
                )

                PaveNotice(
                    title: "Geen e-mail gekregen?",
                    message: "Wacht een paar minuten en kijk ook in je map met spam of ongewenste e-mail. Nog steeds niets? Vraag een nieuwe code aan."
                )

                VStack(alignment: .leading, spacing: 4) {
                    Button(action: resend) {
                        Text(isResending ? "Bezig met versturen..." : "Nieuwe code versturen")
                            .textStyle(.link)
                            .foregroundStyle(Color.brandGreen)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isResending || isChecking)

                    MessageSlot(
                        message: resendError?.message ?? resendMessage,
                        reserving: [Self.resentMessage] + AuthError.allMessages
                    ) { text in
                        if text == Self.resentMessage {
                            Text(text)
                                .textStyle(.footnote)
                                .foregroundStyle(Color.brandGreen)
                        } else {
                            PaveInlineError(message: text)
                        }
                    }
                }

                Text("We laten nooit zien of een e-mailadres een PAVE-account heeft. Zo blijven je gegevens veilig.")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.inkMuted)

                AuthReturnButton(action: flow.returnToLogin)
            }
            .animation(.easeOut(duration: 0.2), value: resendMessage)
            .animation(.easeOut(duration: 0.2), value: resendError)
        }
        .onAppear { isCodeFocused = true }
    }

    private var codeErrorMessage: String? {
        codeError?.message
    }

    private func check() {
        guard !isChecking, code.count == VerificationCodeField.length else {
            isCodeFocused = true
            return
        }
        isCodeFocused = false
        Task {
            isChecking = true
            defer { isChecking = false }
            do {
                try await flow.verifyPasswordResetCode(email: email, code: code)
            } catch {
                codeError = AuthError(error)
            }
        }
    }

    private func resend() {
        guard !isResending else { return }
        resendMessage = nil
        resendError = nil
        Task {
            isResending = true
            defer { isResending = false }
            do {
                try await flow.requestPasswordReset(email: email)
                resendMessage = Self.resentMessage
                AccessibilityNotification.Announcement("We hebben een nieuwe code gestuurd.").post()
            } catch {
                resendError = AuthError(error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ResetCodeView(email: "ravi@student.example.edu")
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}
