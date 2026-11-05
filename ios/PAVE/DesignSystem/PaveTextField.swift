import SwiftUI

struct PaveTextField<Field: Hashable>: View {
    enum Kind {
        case email
        case password
        case newPassword
    }

    let label: String
    let placeholder: String
    @Binding var text: String
    let kind: Kind
    var focus: FocusState<Field?>.Binding
    let field: Field
    var errorMessage: String?

    @Environment(\.isEnabled) private var isEnabled
    @State private var isRevealed = false

    private var isFocused: Bool { focus.wrappedValue == field }
    private var isInvalid: Bool { errorMessage != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .textStyle(.label)
                .foregroundStyle(Color.ink)

            HStack(spacing: 8) {
                input
                    .textStyle(.input)
                    .foregroundStyle(Color.ink)
                    .tint(.brandGreen)
                    .focused(focus, equals: field)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if kind != .email {
                    visibilityToggle
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .frame(minHeight: 52)
            .background(isEnabled ? Color.white : .fieldDisabled, in: .rect(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(borderColor, lineWidth: isInvalid || isFocused ? 2 : 1)
            }
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(ringColor, lineWidth: 6)
                    .opacity(isInvalid || isFocused ? 1 : 0)
            }
            .contentShape(.rect)
            .onTapGesture { focus.wrappedValue = field }
            .animation(.easeOut(duration: 0.15), value: isFocused)

            if let errorMessage {
                PaveInlineError(message: errorMessage)
            }
        }
    }

    @ViewBuilder
    private var input: some View {
        let prompt = Text(placeholder).foregroundStyle(Color.inkMuted)
        switch kind {
        case .email:
            TextField(label, text: $text, prompt: prompt)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        case .password, .newPassword:
            Group {
                if isRevealed {
                    TextField(label, text: $text, prompt: prompt)
                } else {
                    SecureField(label, text: $text, prompt: prompt)
                }
            }
            .textContentType(kind == .password ? .password : .newPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
    }

    private var visibilityToggle: some View {
        Button {
            isRevealed.toggle()
            if isFocused {
                focus.wrappedValue = field
            }
        } label: {
            HStack(spacing: 6) {
                Image(isRevealed ? .iconEyeOff : .iconEye)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text(isRevealed ? "Hide" : "Show")
                    .textStyle(.eyebrow)
                    .foregroundStyle(Color.brandGreen)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
    }

    private var borderColor: Color {
        if isInvalid { return .critical }
        if isFocused { return .brandGreen }
        return .hairline
    }

    private var ringColor: Color {
        isInvalid ? Color.critical.opacity(0.13) : .focusRing
    }
}

struct PaveInlineError: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(.iconExclamationCircle)
                .resizable()
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            Text(message)
                .textStyle(.footnote)
                .foregroundStyle(Color.critical)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @State var password = "BrightFuture!2026"
    @Previewable @FocusState var focus: Int?

    VStack(spacing: 20) {
        PaveTextField(label: "Email address", placeholder: "Your organization email", text: $email, kind: .email, focus: $focus, field: 0)
        PaveTextField(label: "Password", placeholder: "Enter your password", text: $password, kind: .password, focus: $focus, field: 1, errorMessage: "Passwords don’t match. Re-enter your new password.")
    }
    .padding(32)
    .background(Color.canvas)
}
