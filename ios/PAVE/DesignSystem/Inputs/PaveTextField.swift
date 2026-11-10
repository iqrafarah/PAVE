import PAVECore
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
    var reservedErrors: [String] = []
    /// How far the password is: an orange edge while it is not good yet, a green one when it is, as on the web.
    var progress: Progress?
    /// A line under the field with a check when the progress is `.valid`, such as "De wachtwoorden zijn hetzelfde."
    var status: String?
    var reservedStatuses: [String] = []
    var hint: String?

    enum Progress {
        case incomplete
        case valid
    }

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
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(ringColor, lineWidth: 6)
                    .opacity(isInvalid || isFocused ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: shownProgress)
            }
            .contentShape(.rect)
            .onTapGesture { focus.wrappedValue = field }
            .animation(.easeOut(duration: 0.15), value: isFocused)

            if errorMessage != nil || !reservedErrors.isEmpty || !reservedStatuses.isEmpty {
                MessageSlot(message: errorMessage ?? visibleStatus, reserving: reservedErrors + reservedStatuses) { text in
                    if text == errorMessage || reservedErrors.contains(text) {
                        PaveInlineError(message: text)
                    } else {
                        statusLine(text)
                    }
                }
            }

            if let hint {
                Text(hint)
                    .textStyle(.footnote)
                    .foregroundStyle(Color.inkMuted)
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
            .onChange(of: text) { _, newValue in
                let cleaned = PasswordInput.cleaned(newValue)
                if cleaned != newValue { text = cleaned }
            }
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
                Text(isRevealed ? "Verbergen" : "Tonen")
                    .textStyle(.eyebrow)
                    .foregroundStyle(Color.brandGreen)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(isRevealed ? "Wachtwoord verbergen" : "Wachtwoord tonen")
    }

    private var visibleStatus: String? {
        text.isEmpty ? nil : status
    }

    private var shownProgress: Progress? {
        text.isEmpty ? nil : progress
    }

    private func statusLine(_ text: String) -> some View {
        let isMet = shownProgress == .valid
        return HStack(spacing: 8) {
            Image(isMet ? .iconCheck : .iconRequirementBullet)
                .resizable()
                .frame(width: isMet ? 16 : 4, height: isMet ? 16 : 4)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(text)
                .textStyle(.footnote)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var borderColor: Color {
        if isInvalid { return .critical }
        switch shownProgress {
        case .incomplete: return .warning
        case .valid: return .brandGreen
        case nil: return isFocused ? .brandGreen : .hairline
        }
    }

    private var borderWidth: CGFloat {
        isInvalid || isFocused || shownProgress != nil ? 2 : 1
    }

    private var ringColor: Color {
        if isInvalid { return Color.critical.opacity(0.13) }
        if shownProgress == .incomplete { return Color.warning.opacity(0.13) }
        return .focusRing
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
        PaveTextField(label: "E-mailadres", placeholder: "E-mailadres", text: $email, kind: .email, focus: $focus, field: 0)
        PaveTextField(label: "Wachtwoord", placeholder: "Vul je wachtwoord in", text: $password, kind: .password, focus: $focus, field: 1, errorMessage: "De wachtwoorden zijn niet hetzelfde. Vul je nieuwe wachtwoord opnieuw in.")
    }
    .padding(32)
    .background(Color.canvas)
}
