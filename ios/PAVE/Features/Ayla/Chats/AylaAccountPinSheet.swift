import PAVECore
import SwiftUI

/// The account PIN of the locked chats, changed or reset (web SettingsAccountPin and AylaPinRecover). It belongs to the
/// account, so it works the same from Instellingen and from Vergrendelde chats, and on every device.
/// - Wijzigen: the current PIN, then a new one twice. The database checks the current one.
/// - Resetten ("Pincode vergeten"): a code from the authenticator app, then a new PIN; the locked chats stay. Without
///   the authenticator app the only way out is deleting the locked chats.
struct AylaAccountPinSheet: View {
    enum Purpose: Identifiable {
        case change
        case recover

        var id: Self { self }
    }

    private enum Step: Equatable {
        case current
        case code
        case newPin
    }

    let purpose: Purpose
    let model: AylaChatModel
    /// What happened, to show after the sheet closed.
    let onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var step: Step
    @State private var currentPin = ""
    @State private var code = ""
    @State private var codeError: String?
    @State private var isChecking = false
    @State private var confirmsDeleteAll = false
    @State private var deleteProblem: String?
    @FocusState private var isCodeFocused: Bool

    init(purpose: Purpose, model: AylaChatModel, onDone: @escaping (String) -> Void) {
        self.purpose = purpose
        self.model = model
        self.onDone = onDone
        _step = State(initialValue: purpose == .change ? .current : .code)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .current:
                    // The current PIN is checked first, as on the web, so a wrong one is said at once and counts.
                    AylaChatPinView(mode: .enter, title: AylaMessages.accountPinCurrentTitle, subtitle: AylaMessages.accountPinCurrentBody) { pin in
                        if let problem = await model.verifyChatPin(pin) { return problem }
                        currentPin = pin
                        step = .newPin
                        return nil
                    } onForgot: {
                        step = .code
                    }
                case .code:
                    codeStep
                case .newPin:
                    AylaChatPinView(mode: .create, title: AylaMessages.accountPinNewTitle, subtitle: AylaMessages.accountPinNewBody) { pin in
                        await save(pin)
                    }
                }
            }
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(purpose == .change ? AylaMessages.accountPinChangeTitle : AylaMessages.accountPinResetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(.iconXMark).paveToolbarHitArea()
                    }
                    .accessibilityLabel("Sluiten")
                }
            }
            .animation(.snappy(duration: 0.25), value: step)
            .confirmationDialog(AylaMessages.pinResetQuestion, isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
                Button(AylaMessages.pinResetConfirm, role: .destructive) {
                    Task {
                        if await model.resetChatPin() {
                            finish(AylaMessages.accountPinDeleted)
                        } else {
                            model.chatsProblem = nil
                            deleteProblem = AylaMessages.pinCodeFailed
                        }
                    }
                }
            } message: {
                    Text(AylaMessages.accountPinDeleteBody)
            }
        }
        .tint(.paveAccent)
    }

    /// "Bevestig dat jij het bent": the same two-step code as at sign-in.
    private var codeStep: some View {
        ViewThatFits(in: .vertical) {
            codeContent
            ScrollView { codeContent }
                .scrollDismissesKeyboard(.interactively)
        }
        .onAppear { isCodeFocused = true }
    }

    private var codeContent: some View {
        VStack(spacing: 24) {
            Image(.iconLockClosedSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(28)
                .foregroundStyle(Color.paveAccent)
                .frame(width: 64, height: 64)
                .background(Color.paveSurfaceTint, in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(AylaMessages.accountPinVerifyTitle)
                    .textStyle(.emptyTitle)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(AylaMessages.accountPinVerifyBody)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VerificationCodeField(
                code: $code,
                title: AuthMessages.authenticatorCodeLabel,
                hint: AuthMessages.authenticatorCodeHint,
                errorMessage: codeError,
                isFocused: $isCodeFocused,
                onComplete: checkCode
            )
            .disabled(isChecking)
            .onChange(of: code) { if !code.isEmpty { codeError = nil } }
            VStack(spacing: 6) {
                Text(AylaMessages.accountPinDeleteAllHint)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(AylaMessages.accountPinDeleteAll, role: .destructive) {
                    confirmsDeleteAll = true
                }
                .textStyle(.link)
                .foregroundStyle(Color.critical)
                .frame(minHeight: 44)
                if let deleteProblem {
                    PaveInlineError(message: deleteProblem)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    private func checkCode() {
        guard !isChecking else { return }
        isChecking = true
        Task {
            defer { isChecking = false }
            do {
                try await appState.authService.verify(code: code)
                PaveHaptics.success()
                step = .newPin
            } catch {
                codeError = AuthError(error).message
                code = ""
                isCodeFocused = true
                PaveHaptics.error()
            }
        }
    }

    private func save(_ newPin: String) async -> String? {
        switch purpose == .change && step == .newPin && !currentPin.isEmpty {
        case true:
            guard let problem = await model.changeChatPin(from: currentPin, to: newPin) else {
                finish(AylaMessages.accountPinChanged)
                return nil
            }
            // The current PIN stopped working meanwhile (changed on another device): start again with it.
            if problem == AylaMessages.pinWrong || problem == AylaMessages.pinBlocked {
                currentPin = ""
                step = .current
            }
            return problem
        case false:
            guard let problem = await model.recoverChatPin(newPin) else {
                finish(AylaMessages.accountPinWasReset)
                return nil
            }
            if problem == AylaMessages.accountPinVerifyAgain {
                code = ""
                step = .code
            }
            return problem
        }
    }

    private func finish(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
        onDone(message)
        dismiss()
    }
}
