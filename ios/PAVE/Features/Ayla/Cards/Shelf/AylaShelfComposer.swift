import SwiftUI

/// At the bottom of a page that opened over the chat: ask Ayla something about it without closing it. The answer shows
/// in the chat above the panel.
struct AylaShelfComposer: View {
    @Binding var text: String
    let place: String
    let isAnswering: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    private var canSend: Bool { !isAnswering && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        HStack(spacing: 10) {
            AylaLetter(color: .paveAccent)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            TextField("", text: $text, prompt: Text("Vraag Ayla iets over \(place.lowercased())").foregroundStyle(Color.inkMuted), axis: .vertical)
                .lineLimit(1...4)
                .textStyle(.input)
                .foregroundStyle(Color.ink)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: send) {
                Image(.iconSend)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(16)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(canSend ? Color.paveAccent : Color.paveAccent.opacity(0.35), in: .circle)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.pave)
            .disabled(!canSend)
            .accessibilityLabel("Versturen")
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .frame(minHeight: 52)
        .background(Color.white, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.cardBorder) }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func send() {
        guard canSend else { return }
        isFocused = false
        onSend()
    }
}
