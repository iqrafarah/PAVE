import PAVECore
import SwiftUI

/// The PIN of the locked chats (web AylaPinDialog): four digits, chosen twice the first time, typed once after that. It is
/// checked in the database only; this view never keeps it.
struct AylaChatPinView: View {
    enum Mode { case create, enter }

    let mode: Mode
    /// Returns nil when it worked, otherwise what to say.
    let onPin: (String) async -> String?
    var onForgot: (() -> Void)?

    @State private var digits = ""
    @State private var firstChoice: String?
    @State private var problem: String?
    @State private var isChecking = false

    private static let length = 4

    private var title: String {
        switch mode {
        case .create: firstChoice == nil ? AylaMessages.pinCreateTitle : AylaMessages.pinConfirmTitle
        case .enter: AylaMessages.pinEnterTitle
        }
    }

    private var message: String {
        switch mode {
        case .create: firstChoice == nil ? AylaMessages.pinCreateBody : AylaMessages.pinConfirmBody
        case .enter: AylaMessages.pinEnterBody
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
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
                Text(title)
                    .textStyle(.emptyTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(problem ?? message)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(problem == nil ? Color.inkMuted : Color.critical)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 44, alignment: .top)
            }
            PinPad(digits: $digits, length: Self.length, isError: problem != nil, keySize: 68) { pin in
                submit(pin)
            }
            .disabled(isChecking)
            .opacity(isChecking ? 0.5 : 1)
            if mode == .enter, let onForgot {
                Button(AylaMessages.pinForgot, action: onForgot)
                    .textStyle(.link)
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.2), value: firstChoice)
    }

    private func submit(_ pin: String) {
        problem = nil
        if mode == .create, firstChoice == nil {
            firstChoice = pin
            digits = ""
            return
        }
        if mode == .create, pin != firstChoice {
            firstChoice = nil
            digits = ""
            problem = AylaMessages.pinMismatch
            PaveHaptics.error()
            return
        }
        isChecking = true
        Task {
            let failure = await onPin(pin)
            isChecking = false
            digits = ""
            if let failure {
                problem = failure
                if mode == .create { firstChoice = nil }
                PaveHaptics.error()
            } else {
                PaveHaptics.success()
            }
        }
    }
}

#Preview {
    AylaChatPinView(mode: .create) { _ in nil }
}
