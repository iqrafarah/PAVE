import PAVECore
import SwiftUI

struct ResetCodeView: View {
    let email: String

    @Environment(AuthFlow.self) private var flow
    @State private var code = ""
    @State private var isChecking = false
    @State private var isResending = false
    @State private var codeError: AuthError?
    /// As on the web: a new code can be asked for 60 seconds after the last one was sent.
    @State private var resendAvailableAt = Date.now.addingTimeInterval(Self.resendWait)
    private static let resendWait: TimeInterval = 60

    @State private var resendError: AuthError?
    @State private var resendMessage: String?
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        AuthScreen {
            AuthIntro(
                emblem: .iconMailOpen,
                title: "Check je inbox",
                message: AuthMessages.resetCodeInstruction,
                steps: AuthMessages.resetSteps,
                currentStep: 1
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AuthMessages.resetCodeSent(to: EmailMask.masked(email)))
                        .textStyle(.footnote)
                        .foregroundStyle(Color.inkMuted)
                    HStack(spacing: 4) {
                        Text(AuthMessages.wrongEmailPrompt)
                            .textStyle(.footnote)
                            .foregroundStyle(Color.inkMuted)
                        Button(action: flow.returnToResetEmail) {
                            Text(AuthMessages.wrongEmailLink)
                                .textStyle(.link)
                                .underline()
                                .foregroundStyle(Color.brandGreen)
                                .frame(minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.pave)
                        .accessibilityLabel("Terug naar je e-mailadres")
                    }
                }

                VerificationCodeField(
                    code: $code,
                    title: AuthMessages.emailCodeLabel,
                    hint: nil,
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
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let secondsLeft = secondsUntilResend(at: context.date)
                        Button(action: resend) {
                            Text(resendLabel(secondsLeft: secondsLeft))
                                .textStyle(.link)
                                .foregroundStyle(secondsLeft > 0 ? Color.inkMuted : .brandGreen)
                                .frame(minHeight: 44, alignment: .leading)
                                .contentTransition(.numericText(countsDown: true))
                        }
                        .buttonStyle(.pave)
                        .disabled(isResending || isChecking || secondsLeft > 0)
                    }

                    MessageSlot(
                        message: resendError?.message ?? resendMessage,
                        reserving: [AuthMessages.emailCodeResent] + AuthError.allMessages
                    ) { text in
                        if text == AuthMessages.emailCodeResent {
                            Text(text)
                                .textStyle(.footnote)
                                .foregroundStyle(Color.brandGreen)
                        } else {
                            PaveInlineError(message: text)
                        }
                    }
                }

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

    private func secondsUntilResend(at date: Date) -> Int {
        max(0, Int(resendAvailableAt.timeIntervalSince(date).rounded(.up)))
    }

    private func resendLabel(secondsLeft: Int) -> String {
        if isResending { return "Bezig met versturen..." }
        return secondsLeft > 0 ? AuthMessages.resendCountdown(secondsLeft: secondsLeft) : AuthMessages.resendEmailCodeLabel
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
                PaveHaptics.success()
            } catch {
                codeError = AuthError(error)
                PaveHaptics.error()
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
                resendAvailableAt = .now.addingTimeInterval(Self.resendWait)
                resendMessage = AuthMessages.emailCodeResent
                PaveHaptics.success()
                AccessibilityNotification.Announcement(AuthMessages.emailCodeResent).post()
            } catch {
                resendError = AuthError(error)
                PaveHaptics.error()
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
