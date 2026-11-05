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
    @FocusState private var focus: Field?

    var body: some View {
        AuthScreen {
            VStack(alignment: .leading, spacing: 24) {
                AuthIntro(
                    eyebrow: "Password recovery",
                    title: "Create a new password",
                    message: "Choose a strong password that you don’t use for other accounts."
                )

                PaveTextField(
                    label: "New password",
                    placeholder: "Enter a new password",
                    text: $password,
                    kind: .newPassword,
                    focus: $focus,
                    field: .password,
                    errorMessage: passwordError
                )
                .submitLabel(.next)
                .onSubmit { focus = .confirmation }
                .onChange(of: password) { passwordError = nil }

                PasswordRequirementsList(password: password)

                PaveTextField(
                    label: "Confirm new password",
                    placeholder: "Re-enter your new password",
                    text: $confirmation,
                    kind: .newPassword,
                    focus: $focus,
                    field: .confirmation,
                    errorMessage: confirmationError
                )
                .submitLabel(.done)
                .onSubmit(submit)
                .onChange(of: confirmation) { confirmationError = nil }

                PavePrimaryButton(title: "Save new password", loadingTitle: "Saving…", isLoading: isSubmitting, action: submit)

                AuthReturnButton(action: flow.returnToLogin)
            }
            .disabled(isSubmitting)
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        guard PasswordRequirement.allMet(by: password) else {
            passwordError = "Your password doesn’t meet all the requirements yet."
            focus = .password
            return
        }
        guard password == confirmation else {
            confirmationError = "Passwords don’t match. Re-enter your new password."
            focus = .confirmation
            return
        }
        focus = nil
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.updatePassword(password)
            } catch {
                passwordError = switch AuthError(error) {
                case .weakPassword: "Your password doesn’t meet all the requirements yet."
                case .invalidResetLink: "This reset link has expired. Go back to login and request a new one."
                default: "We couldn’t save your password. Check your internet connection and try again."
                }
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
