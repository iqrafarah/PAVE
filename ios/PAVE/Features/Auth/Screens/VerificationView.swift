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
            AuthIntro(
                emblem: .iconShieldCheck,
                eyebrow: "Tweestapsverificatie",
                title: "Bevestig dat jij het bent",
                message: "Open je authenticator-app en vul de code van 6 cijfers voor je PAVE-account in."
            )
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                VerificationCodeField(code: $code, errorMessage: errorMessage, isFocused: $isCodeFocused)
                    .onChange(of: code) { error = nil }

                PavePrimaryButton(
                    title: error == nil ? "Bevestigen" : "Opnieuw proberen",
                    loadingTitle: "Controleren…",
                    isLoading: isSubmitting,
                    action: submit
                )

                PaveNotice(
                    title: "Gebruik je authenticator-app",
                    message: "Je code komt uit je authenticator-app, niet via e-mail of sms. Kun je niet bij de app? Neem contact op met de IT-support."
                )

                AuthReturnButton(action: flow.returnToLogin)
            }
        }
        .onAppear { isCodeFocused = true }
    }

    private var errorMessage: String? {
        switch error {
        case nil: nil
        case .invalidCode: "Deze code klopt niet of is verlopen. Gebruik de nieuwste code uit je authenticator-app en probeer het opnieuw."
        default: "We konden je code niet controleren. Controleer je internetverbinding en probeer het opnieuw."
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
