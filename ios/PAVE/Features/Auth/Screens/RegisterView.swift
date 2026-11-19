import PAVECore
import SwiftUI

/// "Maak je eduID aan" (web register): e-mail, first and last name and a password chosen twice. A code is mailed next;
/// after it, two-step verification is set up as after a first sign-in.
struct RegisterView: View {
    private enum Field: Hashable {
        case email, firstName, lastName, password, confirmation
    }

    @Environment(AuthFlow.self) private var flow
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var hasLeftConfirmation = false
    @State private var isSubmitting = false
    @State private var error: AuthError?
    @FocusState private var focus: Field?

    private static let errors = [AuthMessages.signupDisabled, AuthMessages.emailAlreadyRegistered, AuthMessages.invalidEmail] + AuthError.allMessages

    var body: some View {
        AuthScreen {
            AuthIntro(title: "Maak je eduID aan", message: "Vul je gegevens in om een account aan te maken.")
        } content: {
            VStack(alignment: .leading, spacing: 20) {
                PaveTextField(label: "E-mailadres", placeholder: "E-mailadres", text: $email, kind: .email, focus: $focus, field: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .firstName }

                // Next to each other where there is room, under each other where there is not.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) { nameFields }
                    VStack(alignment: .leading, spacing: 20) { nameFields }
                }

                PaveTextField(
                    label: "Wachtwoord",
                    placeholder: "Kies een wachtwoord",
                    text: $password,
                    kind: .newPassword,
                    focus: $focus,
                    field: .password,
                    progress: isPasswordStrong ? .valid : .incomplete
                )
                .submitLabel(.next)
                .onSubmit { focus = .confirmation }

                PasswordRequirementsList(password: password)

                PaveTextField(
                    label: "Herhaal je wachtwoord",
                    placeholder: "Vul je wachtwoord nog een keer in",
                    text: $confirmation,
                    kind: .newPassword,
                    focus: $focus,
                    field: .confirmation,
                    progress: doPasswordsMatch ? .valid : .incomplete,
                    status: confirmationStatus,
                    reservedStatuses: [AuthMessages.passwordsMatch, AuthMessages.passwordsNotEqual],
                    hint: AuthMessages.repeatPasswordHint
                )
                .submitLabel(.done)
                .onSubmit(submit)

                MessageSlot(message: error?.message, reserving: Self.errors) { PaveNotice(message: $0, tone: .critical) }

                PavePrimaryButton(title: "Account aanmaken", loadingTitle: "Bezig met aanmaken...", isLoading: isSubmitting, action: submit)
                    .disabled(!canSubmit && !isSubmitting)

                HStack(spacing: 4) {
                    Text("Heb je al een eduID?")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.inkMuted)
                    Button(action: flow.returnToLogin) {
                        Text("Inloggen")
                            .textStyle(.link)
                            .underline()
                            .foregroundStyle(Color.paveAccent)
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.pave)
                }
            }
            .disabled(isSubmitting)
            .onChange(of: [email, firstName, lastName, password, confirmation]) { error = nil }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: doPasswordsMatch && !confirmation.isEmpty) { _, isNow in isNow }
        .onChange(of: focus) { previous, _ in
            if previous == .confirmation { hasLeftConfirmation = true }
        }
        .onAppear { focus = .email }
    }

    @ViewBuilder
    private var nameFields: some View {
        PaveTextField(label: "Voornaam", placeholder: "Voornaam", text: $firstName, kind: .name(.givenName), focus: $focus, field: .firstName)
            .submitLabel(.next)
            .onSubmit { focus = .lastName }
        PaveTextField(label: "Achternaam", placeholder: "Achternaam", text: $lastName, kind: .name(.familyName), focus: $focus, field: .lastName)
            .submitLabel(.next)
            .onSubmit { focus = .password }
    }

    private var isPasswordStrong: Bool { PasswordRequirement.allMet(by: password) }
    private var doPasswordsMatch: Bool { password == confirmation }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && isPasswordStrong && doPasswordsMatch
    }

    private var confirmationStatus: String? {
        if doPasswordsMatch, !confirmation.isEmpty { return AuthMessages.passwordsMatch }
        guard !password.isEmpty, !confirmation.isEmpty else { return nil }
        if hasLeftConfirmation || confirmation.count >= password.count { return AuthMessages.passwordsNotEqual }
        return nil
    }

    private func submit() {
        guard !isSubmitting, canSubmit else { return }
        focus = nil
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
                PaveHaptics.success()
            } catch {
                self.error = AuthError(error)
                PaveHaptics.error()
            }
        }
    }
}

/// The code from the e-mail after "Account aanmaken": it confirms the address and signs you in.
struct RegisterCodeView: View {
    let email: String

    @Environment(AuthFlow.self) private var flow
    @State private var code = ""
    @State private var isChecking = false
    @State private var isResending = false
    @State private var codeError: AuthError?
    @State private var resendMessage: String?
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        AuthScreen {
            AuthIntro(emblem: .iconMailOpen, title: "Check je inbox", message: AuthMessages.resetCodeSent(to: EmailMask.masked(email)))
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                VerificationCodeField(
                    code: $code,
                    title: AuthMessages.emailCodeLabel,
                    hint: nil,
                    errorMessage: codeError?.message,
                    isFocused: $isCodeFocused,
                    onComplete: check
                )
                .onChange(of: code) { codeError = nil }

                PavePrimaryButton(title: "Code bevestigen", loadingTitle: "Bezig met controleren...", isLoading: isChecking, action: check)

                PaveNotice(
                    title: "Geen e-mail gekregen?",
                    message: "Kijk ook in je map met spam of ongewenste e-mail. Nog steeds niets? Vraag een nieuwe code aan."
                )

                VStack(alignment: .leading, spacing: 4) {
                    Button(action: resend) {
                        Text(isResending ? "Bezig met versturen..." : AuthMessages.resendEmailCodeLabel)
                            .textStyle(.link)
                            .underline()
                            .foregroundStyle(Color.paveAccent)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.pave)
                    .disabled(isResending || isChecking)
                    MessageSlot(message: resendMessage, reserving: [AuthMessages.emailCodeResent] + AuthError.allMessages) { text in
                        Text(text)
                            .textStyle(.footnote)
                            .foregroundStyle(text == AuthMessages.emailCodeResent ? Color.paveAccent : .critical)
                    }
                }

                AuthReturnButton(action: flow.returnToLogin)
            }
        }
        .onAppear { isCodeFocused = true }
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
                try await flow.verifySignUpCode(email: email, code: code)
                PaveHaptics.success()
            } catch {
                codeError = AuthError(error)
                code = ""
                isCodeFocused = true
                PaveHaptics.error()
            }
        }
    }

    private func resend() {
        resendMessage = nil
        Task {
            isResending = true
            defer { isResending = false }
            do {
                try await flow.resendSignUpCode(email: email)
                resendMessage = AuthMessages.emailCodeResent
                AccessibilityNotification.Announcement(AuthMessages.emailCodeResent).post()
            } catch {
                resendMessage = AuthError(error).message
                PaveHaptics.error()
            }
        }
    }
}

#Preview {
    NavigationStack { RegisterView() }
        .environment(AuthFlow(service: MockAuthService()) { _ in })
}
