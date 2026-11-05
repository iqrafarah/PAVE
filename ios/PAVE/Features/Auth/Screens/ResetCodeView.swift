import PAVECore
import SwiftUI

struct ResetCodeView: View {
    let email: String

    @Environment(AuthFlow.self) private var flow
    @State private var code = ""
    @State private var isChecking = false
    @State private var isResending = false
    @State private var codeError: AuthError?
    @State private var resendError: AuthError?
    @State private var resendMessage: String?
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        AuthScreen {
            AuthIntro(
                emblem: .iconMailOpen,
                eyebrow: "Wachtwoord herstellen",
                title: "Kijk in je inbox",
                message: "Als er een account bestaat voor \(email), hebben we een code gestuurd om je wachtwoord te herstellen."
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                VerificationCodeField(
                    code: $code,
                    title: "Code van 6 cijfers",
                    hint: "Vul de code uit de e-mail in.",
                    errorMessage: codeErrorMessage,
                    isFocused: $isCodeFocused
                )
                .onChange(of: code) { codeError = nil }

                PavePrimaryButton(
                    title: codeError == nil ? "Code controleren" : "Opnieuw proberen",
                    loadingTitle: "Controleren…",
                    isLoading: isChecking,
                    action: check
                )

                PaveNotice(
                    title: "Geen e-mail ontvangen?",
                    message: "Wacht een paar minuten en kijk in je map met spam of ongewenste e-mail. Nog niets? Vraag een nieuwe code aan."
                )

                VStack(alignment: .leading, spacing: 4) {
                    Button(action: resend) {
                        Text(isResending ? "Versturen…" : "Nieuwe code versturen")
                            .textStyle(.link)
                            .foregroundStyle(Color.brandGreen)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isResending || isChecking)

                    if let resendMessage {
                        Text(resendMessage)
                            .textStyle(.footnote)
                            .foregroundStyle(Color.brandGreen)
                    }
                    if let resendError {
                        PaveInlineError(message: resendErrorMessage(for: resendError))
                    }
                }

                Text("Voor je privacy laten we niet weten of een e-mailadres een PAVE-account heeft.")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.inkMuted)

                AuthReturnButton(action: flow.returnToLogin)
            }
            .animation(.easeOut(duration: 0.2), value: resendMessage)
        }
        .onAppear { isCodeFocused = true }
    }

    private var codeErrorMessage: String? {
        switch codeError {
        case nil: nil
        case .invalidCode: "Deze code klopt niet of is verlopen. Controleer de code of vraag een nieuwe aan."
        case .rateLimited: "Je hebt te vaak geprobeerd. Wacht even en probeer het opnieuw."
        default: "We konden de code niet controleren. Controleer je internetverbinding en probeer het opnieuw."
        }
    }

    private func resendErrorMessage(for error: AuthError) -> String {
        error == .rateLimited
            ? "Je hebt net al een code aangevraagd. Wacht 60 seconden en probeer het opnieuw."
            : "We konden de code niet versturen. Probeer het later opnieuw of neem contact op met de IT-support."
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
                resendMessage = "We hebben een nieuwe code gestuurd."
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
