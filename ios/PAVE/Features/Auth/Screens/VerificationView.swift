import PAVECore
import SwiftUI

struct VerificationView: View {
    @Environment(AuthFlow.self) private var flow
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var error: AuthError?
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        AuthScreen {
            VStack(alignment: .leading, spacing: 24) {
                AuthIntro(
                    emblem: .iconShieldCheck,
                    eyebrow: "Two-step verification",
                    title: "Verify your identity",
                    message: "Open your authenticator app and enter the 6-digit code for your PAVE account."
                )

                VerificationCodeField(code: $code, errorMessage: errorMessage, isFocused: $isCodeFocused)
                    .onChange(of: code) { error = nil }

                PavePrimaryButton(
                    title: error == nil ? "Verify" : "Try again",
                    loadingTitle: "Verifying…",
                    isLoading: isSubmitting,
                    action: submit
                )

                PaveNotice(
                    title: "Use your authenticator app",
                    message: "Your code comes from your authenticator app, not by email or SMS. Can’t access the app? Contact IT support."
                )

                AuthReturnButton(action: flow.returnToLogin)
            }
        }
        .onAppear { isCodeFocused = true }
    }

    private var errorMessage: String? {
        switch error {
        case nil: nil
        case .invalidCode: "This code is invalid or has expired. Use the latest code in your authenticator app and try again."
        default: "We couldn’t check your code. Check your internet connection and try again."
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isCodeFocused = false
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                try await flow.verify(code: code)
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
