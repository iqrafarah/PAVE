import PAVECore
import SwiftUI

struct NewPasswordView: View {
    private enum Field {
        case password
        case confirmation
    }

    @Environment(AuthFlow.self) private var flow
    @State private var password = ""
    @State private var confirmation = ""
    @State private var passwordError: String?
    @State private var confirmationError: String?
    @State private var isSubmitting = false
    @State private var hasLeftConfirmation = false
    @FocusState private var focus: Field?

    var body: some View {
        AuthScreen {
            AuthIntro(
                eyebrow: "Wachtwoord",
                title: "Kies een nieuw wachtwoord",
                message: AuthMessages.newPasswordInstruction,
                steps: flow.resetSteps,
                currentStep: flow.resetSteps.count - 1
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                PaveTextField(
                    label: "Nieuw wachtwoord",
                    placeholder: "Vul een nieuw wachtwoord in",
                    text: $password,
                    kind: .newPassword,
                    focus: $focus,
                    field: .password,
                    errorMessage: passwordError,
                    reservedErrors: [AuthMessages.passwordRulesNotMet] + AuthError.allMessages,
                    progress: isPasswordStrong ? .valid : .incomplete
                )
                .submitLabel(.next)
                .onSubmit { focus = .confirmation }
                .onChange(of: password) { passwordError = nil }

                PasswordRequirementsList(password: password)

                PaveTextField(
                    label: "Herhaal je nieuwe wachtwoord",
                    placeholder: "Vul je nieuwe wachtwoord nog een keer in",
                    text: $confirmation,
                    kind: .newPassword,
                    focus: $focus,
                    field: .confirmation,
                    errorMessage: confirmationError,
                    reservedErrors: [AuthMessages.passwordsDiffer],
                    progress: doPasswordsMatch ? .valid : .incomplete,
                    status: confirmationStatus,
                    reservedStatuses: [AuthMessages.passwordsMatch, AuthMessages.passwordsNotEqual],
                    hint: AuthMessages.repeatPasswordHint
                )
                .submitLabel(.done)
                .onSubmit(submit)
                .onChange(of: confirmation) { confirmationError = nil }

                PavePrimaryButton(title: "Wachtwoord opslaan", loadingTitle: "Bezig met opslaan...", isLoading: isSubmitting, action: submit)
                    .disabled(!canSubmit && !isSubmitting)

                AuthReturnButton(action: flow.returnToLogin)
            }
            .disabled(isSubmitting)
        }
        // A light tap the moment the two passwords become the same, as the check appears.
        .sensoryFeedback(.impact(weight: .light), trigger: doPasswordsMatch && !confirmation.isEmpty) { _, isNow in isNow }
        .onChange(of: focus) { previous, _ in
            if previous == .confirmation { hasLeftConfirmation = true }
        }
    }

    private var isPasswordStrong: Bool {
        PasswordRequirement.allMet(by: password)
    }

    private var doPasswordsMatch: Bool {
        password == confirmation
    }

    private var canSubmit: Bool {
        isPasswordStrong && doPasswordsMatch
    }

    /// As on the web: "hetzelfde" as soon as they match, "niet gelijk" only after you left the repeat field.
    private var confirmationStatus: String? {
        if doPasswordsMatch { return AuthMessages.passwordsMatch }
        if hasLeftConfirmation, !password.isEmpty, !confirmation.isEmpty { return AuthMessages.passwordsNotEqual }
        return nil
    }

    private func submit() {
        guard !isSubmitting else { return }
        guard PasswordRequirement.allMet(by: password) else {
            passwordError = AuthMessages.passwordRulesNotMet
            PaveHaptics.error()
            focus = .password
            return
        }
        guard password == confirmation else {
            confirmationError = AuthMessages.passwordsDiffer
            PaveHaptics.error()
            focus = .confirmation
            return
        }
        focus = nil
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.updatePassword(password)
                PaveHaptics.success()
            } catch {
                passwordError = AuthError(error).message
                PaveHaptics.error()
            }
        }
    }
}

#Preview {
    NavigationStack {
        NewPasswordView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}
