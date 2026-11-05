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
            VStack(alignment: .leading, spacing: 24) {
                AuthIntro(
                    emblem: .iconMail,
                    eyebrow: "Password recovery",
                    title: "Forgot your password?",
                    message: "Enter your organization email and we’ll send you a link to reset your password."
                )

                PaveTextField(
                    label: "Email address",
                    placeholder: "Your organization email",
                    text: $email,
                    kind: .email,
                    focus: $focus,
                    field: .email,
                    errorMessage: error == nil ? nil : "We couldn’t send the link. Check your internet connection and try again."
                )
                .submitLabel(.send)
                .onSubmit(submit)
                .disabled(isSubmitting)

                PavePrimaryButton(title: "Send reset link", loadingTitle: "Sending…", isLoading: isSubmitting, action: submit)

                Text("Use the email linked to your organization-provided PAVE account.")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.inkMuted)

                AuthReturnButton(action: flow.returnToLogin)
            }
        }
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

struct ResetEmailSentView: View {
    let email: String

    @Environment(AuthFlow.self) private var flow
    @State private var isSubmitting = false
    @State private var error: AuthError?

    var body: some View {
        AuthScreen {
            VStack(alignment: .leading, spacing: 24) {
                AuthIntro(
                    emblem: .iconMailOpen,
                    eyebrow: "Password recovery",
                    title: "Check your inbox",
                    message: "If an account exists for \(email), we’ll send a password reset link."
                )

                if error == nil {
                    PaveNotice(
                        title: "Can’t find the email?",
                        message: "Allow a few minutes and check your spam or junk folder. If it still hasn’t arrived, request another link."
                    )
                } else {
                    PaveNotice(
                        title: "We couldn’t send a new link",
                        message: "Check your internet connection and try again.",
                        tone: .critical
                    )
                }

                PavePrimaryButton(title: "Resend reset link", loadingTitle: "Sending…", isLoading: isSubmitting, action: resend)

                Text("For your privacy, we don’t confirm whether an email address has a PAVE account.")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.inkMuted)

                AuthReturnButton(action: flow.returnToLogin)
            }
        }
    }

    private func resend() {
        guard !isSubmitting else { return }
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.requestPasswordReset(email: email)
                error = nil
            } catch {
                self.error = AuthError(error)
            }
        }
    }
}

#Preview("Forgot password") {
    NavigationStack {
        ForgotPasswordView()
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}

#Preview("Email sent") {
    NavigationStack {
        ResetEmailSentView(email: "ravi@student.example.edu")
    }
    .environment(AuthFlow(service: MockAuthService()) { _ in })
}
