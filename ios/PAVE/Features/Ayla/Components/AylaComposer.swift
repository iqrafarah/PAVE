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

struct AylaChoiceBar: View {
    let choices: [AylaChoice]
    let onChoose: (AylaChoice) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(choices) { choice in
                Button {
                    onChoose(choice)
                } label: {
                    Text(choice.label)
                        .textStyle(.choice)
                        .foregroundStyle(Color.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 53)
                        .background(Color.white, in: .rect(cornerRadius: 25))
                        .contentShape(.rect(cornerRadius: 25))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.surfaceTint, in: .rect(cornerRadius: 35))
    }
}

struct AylaChoice: Identifiable, Equatable {
    let id: String
    let label: String
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var focused: Bool
    VStack(spacing: 24) {
        AylaComposer(text: $text, isFocused: $focused) {}
        AylaChoiceBar(choices: [.init(id: "y", label: "Ja"), .init(id: "n", label: "Nee")]) { _ in }
    }
    .padding(24)
    .background(Color.canvas)
}
