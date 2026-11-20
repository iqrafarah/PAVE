import PAVECore
import SwiftUI

struct VerificationCodeField: View {
    static let length = 6

    @Binding var code: String
    var title = "Code van 6 cijfers"
    var hint: String? = "Vul de code in die je authenticator-app nu laat zien."
    var errorMessage: String?
    var reservedErrors = AuthError.allMessages
    var isFocused: FocusState<Bool>.Binding
    /// Runs as soon as the last digit is in, also when the code is pasted or filled in by iOS, so there is no button to tap.
    var onComplete: (() -> Void)?

    private var isInvalid: Bool { errorMessage != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .textStyle(.label)
                .foregroundStyle(Color.ink)

            ZStack {
                HStack(spacing: 10) {
                    ForEach(0..<Self.length, id: \.self) { index in
                        box(at: index)
                    }
                }
                .accessibilityHidden(true)
                // One real field lies invisibly over the boxes, as on the web: typing, pasting, the number pad and the
                // code iOS fills in from a message all work, and VoiceOver hears one field with its label.
                TextField("", text: $code, prompt: Text(""))
                    .labelsHidden()
                    .accessibilityLabel(title)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused(isFocused)
                    .foregroundStyle(.clear)
                    .tint(.clear)
                    .autocorrectionDisabled()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                    .contentShape(.rect)
                    .onChange(of: code) { oldValue, newValue in
                        let digits = String(newValue.filter(\.isNumber).prefix(Self.length))
                        if digits != newValue {
                            code = digits
                        }
                        if digits.count == Self.length, oldValue.count < Self.length {
                            onComplete?()
                        }
                    }
            }
            .frame(height: 56)
            .animation(.easeOut(duration: 0.15), value: code.count)
            .animation(.easeOut(duration: 0.15), value: isFocused.wrappedValue)

            MessageSlot(message: errorMessage ?? hint, reserving: [hint].compactMap { $0 } + reservedErrors) { text in
                Text(text)
                    .textStyle(.footnote)
                    .foregroundStyle(isInvalid ? Color.critical : .inkMuted)
            }
        }
    }

    private var activeIndex: Int { min(code.count, Self.length - 1) }

    private func box(at index: Int) -> some View {
        let isActive = isFocused.wrappedValue && index == activeIndex
        let digits = Array(code)
        return ZStack {
            if index < digits.count {
                Text(String(digits[index]))
                    .textStyle(.code)
                    .foregroundStyle(Color.ink)
            } else if isActive {
                Capsule()
                    .fill(Color.ink)
                    .frame(width: 1.5, height: 24)
                    .modifier(BlinkingCursor())
            }
        }
        .frame(maxWidth: 56, minHeight: 56, maxHeight: 56)
        .frame(maxWidth: .infinity)
        .background(Color.panel, in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor(active: isActive), lineWidth: isInvalid || isActive ? 2 : 1)
        }
        .background {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.paveFocusRing, lineWidth: 6)
                .opacity(isActive && !isInvalid ? 1 : 0)
        }
    }

    private func borderColor(active: Bool) -> Color {
        if isInvalid { return .critical }
        if active { return .paveAccent }
        return .hairline
    }
}

private struct BlinkingCursor: ViewModifier {
    @Environment(\.paveReduceMotion) private var reduceMotion
    @State private var isDim = false

    func body(content: Content) -> some View {
        content
            .opacity(isDim ? 0.15 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { isDim = true }
            }
    }
}

#Preview {
    @Previewable @State var code = ""
    @Previewable @FocusState var isFocused: Bool
    VerificationCodeField(code: $code, isFocused: $isFocused)
        .padding(32)
        .background(Color.canvas)
}
