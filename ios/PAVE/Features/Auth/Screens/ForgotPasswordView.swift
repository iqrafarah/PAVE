import PAVECore
import SwiftUI

struct ForgotPasswordView: View {
    private enum Field {
        case email
    }

    @Environment(AuthFlow.self) private var flow
    @State private var email = ""
    @State private var isSubmitting = false
    @State private var error: AuthError?
    @FocusState private var focus: Field?

    var body: some View {
        AuthScreen {
            AuthIntro(
                emblem: .iconMail,
                title: "Wachtwoord vergeten?",
                message: AuthMessages.resetEmailInstruction,
                steps: AuthMessages.resetSteps,
                currentStep: 0
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                PaveTextField(
                    label: "E-mailadres",
                    placeholder: "E-mailadres",
                    text: $email,
                    kind: .email,
                    focus: $focus,
                    field: .email,
                    errorMessage: sendErrorMessage,
                    reservedErrors: AuthError.allMessages
                )
                .submitLabel(.send)
                .onSubmit(submit)
                .disabled(isSubmitting)

                PavePrimaryButton(title: "Code versturen", loadingTitle: "Bezig met versturen...", isLoading: isSubmitting, action: submit)

                AuthReturnButton(action: flow.returnToLogin)
            }
        }
    }

    private var sendErrorMessage: String? {
        error?.message
    }

    private func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            focus = .email
            return
        }
        guard !isSubmitting else { return }
        focus = nil
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.requestPasswordReset(email: trimmedEmail)
                error = nil
            } catch {
                self.error = AuthError(error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}
