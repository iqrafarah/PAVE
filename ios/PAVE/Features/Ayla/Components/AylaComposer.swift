import SwiftUI

/// The glass text field at the bottom: plus (quick questions), Ayla's mark, the text, microphone and send.
struct AylaComposer: View {
    @Binding var text: String
    var isEnabled = true
    var isListening = false
    var placeholderColor = Color.inkMuted.opacity(0.41)
    /// Over the white panel the field is almost white (Figma), elsewhere it is clear glass.
    var isOverPanel = false
    var isFocused: FocusState<Bool>.Binding
    let onQuickAction: (AylaQuickAction) -> Void
    let onMicrophone: () -> Void
    let onSend: () -> Void

    private var canSend: Bool {
        isEnabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                ForEach(AylaQuickAction.allCases) { action in
                    Button(action.title) { onQuickAction(action) }
                }
            } label: {
                Image(.iconPlus)
                    .frame(width: 44, height: 53)
                    .contentShape(.rect)
            }
            .disabled(!isEnabled)
            .accessibilityLabel("Snelle vragen")

            AylaMark()
                .padding(.leading, 1.5)
                .padding(.trailing, 9.4)

            TextField("Vraag het aan Ayla", text: $text, prompt: Text("Vraag het aan Ayla").foregroundStyle(placeholderColor), axis: .vertical)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
                .tint(.brandGreen)
                .lineLimit(1...5)
                .submitLabel(.send)
                .focused(isFocused)
                .onSubmit(send)
                .disabled(!isEnabled)
                .padding(.vertical, 16)

            Button(action: onMicrophone) {
                Image(.iconMicrophone)
                    .renderingMode(.template)
                    .foregroundStyle(isListening ? Color.brandGreen : .ink)
                    .frame(width: 28, height: 53)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .accessibilityLabel(isListening ? "Stop met inspreken" : "Inspreken")
            .padding(.trailing, 5.5)

            Button(action: send) {
                Image(.iconSend)
                    .frame(width: 30, height: 30)
                    .background(Color.brandGreen, in: .circle)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .frame(width: 30, height: 53)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Versturen")
        }
        .padding(.leading, 4.5)
        .padding(.trailing, 11)
        .frame(minHeight: 53)
        .glassEffect(isOverPanel ? .regular.tint(.white.opacity(0.8)) : .clear, in: .rect(cornerRadius: 25))
    }

    private func send() {
        guard canSend else { return }
        onSend()
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var focused: Bool
    AylaComposer(text: $text, isFocused: $focused, onQuickAction: { _ in }, onMicrophone: {}, onSend: {})
        .padding(.leading, 33)
        .padding(.trailing, 31)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color.canvas)
}
