import PAVECore
import SwiftUI

struct VerificationCodeField: View {
    static let length = 6

    @Binding var code: String
    var title = "Code van 6 cijfers"
    var hint = "Vul de code in die je authenticator-app nu laat zien."
    var errorMessage: String?
    var reservedErrors = AuthError.allMessages
    var isFocused: FocusState<Bool>.Binding

    private var isInvalid: Bool { errorMessage != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .textStyle(.label)
                .foregroundStyle(Color.ink)

            TextField(title, text: $code, prompt: Text("000000").foregroundStyle(Color.inkMuted))
                .textStyle(.code)
                .tracking(8)
                .foregroundStyle(Color.ink)
                .tint(.brandGreen)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused(isFocused)
                .padding(16)
                .frame(minHeight: 60)
                .background(Color.white, in: .rect(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(borderColor, lineWidth: isInvalid || isFocused.wrappedValue ? 2 : 1)
                }
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.focusRing, lineWidth: 6)
                        .opacity(isFocused.wrappedValue && !isInvalid ? 1 : 0)
                }
                .onChange(of: code) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(Self.length))
                    if digits != newValue {
                        code = digits
                    }
                }
                .animation(.easeOut(duration: 0.15), value: isFocused.wrappedValue)

            MessageSlot(message: errorMessage ?? hint, reserving: [hint] + reservedErrors) { text in
                Text(text)
                    .textStyle(.footnote)
                    .foregroundStyle(isInvalid ? Color.critical : .inkMuted)
            }
        }
    }

    private var borderColor: Color {
        if isInvalid { return .critical }
        if isFocused.wrappedValue { return .brandGreen }
        return .hairline
    }
}

#Preview {
    @Previewable @State var code = ""
    @Previewable @FocusState var isFocused: Bool
    VerificationCodeField(code: $code, isFocused: $isFocused)
        .padding(32)
        .background(Color.canvas)
}
