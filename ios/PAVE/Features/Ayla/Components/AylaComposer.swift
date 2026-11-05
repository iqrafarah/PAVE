import SwiftUI

struct AylaComposer: View {
    @Binding var text: String
    var isEnabled = true
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    private var canSend: Bool {
        isEnabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                AylaMark()
                TextField("Vraag het aan Ayla", text: $text, prompt: Text("Vraag het aan Ayla").foregroundStyle(Color.ink.opacity(0.41)), axis: .vertical)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .tint(.brandGreen)
                    .lineLimit(1...5)
                    .submitLabel(.send)
                    .focused(isFocused)
                    .onSubmit(send)
                    .disabled(!isEnabled)
            }
            .padding(.vertical, 8)

            Button(action: send) {
                Image(.iconSend)
                    .frame(width: 30, height: 30)
                    .background(Color.brandGreen, in: .circle)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .opacity(canSend ? 1 : 0.45)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Versturen")
        }
        .padding(.leading, 22)
        .padding(.trailing, 4)
        .frame(minHeight: 53)
        .background(Color.white.opacity(0.85), in: .rect(cornerRadius: 25))
        .overlay {
            RoundedRectangle(cornerRadius: 25)
                .strokeBorder(Color.composerBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 10, y: 2)
    }

    private func send() {
        guard canSend else { return }
        onSend()
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var focused: Bool
    AylaComposer(text: $text, isFocused: $focused) {}
        .padding(24)
    .background(Color.canvas)
}
