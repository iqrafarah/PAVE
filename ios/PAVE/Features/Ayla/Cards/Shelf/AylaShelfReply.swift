import SwiftUI

/// Ayla's answer while a page is open over the chat: a card on top of the page, so you read it without closing the
/// page. Tap it or drag it away, like her orb; the answer stays in the chat.
struct AylaShelfReply: View {
    /// Nil while she is still thinking.
    let text: String?
    var choices: [String] = []
    var onChoose: (String) -> Void = { _ in }
    let onDismiss: () -> Void

    @State private var drag = CGSize.zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                AylaLetter(color: .paveAccent)
                    .frame(width: 18, height: 18)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                Text(text ?? "Ayla denkt na…")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(text == nil ? Color.inkMuted : Color.ink)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(10)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 5)
                    .accessibilityHidden(true)
            }
            if !choices.isEmpty {
                HStack(spacing: 8) {
                    ForEach(choices, id: \.self) { choice in
                        Button(choice) { onChoose(choice) }
                            .textStyle(.gapChip)
                            .foregroundStyle(Color.paveAccent)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(Color.paveSurfaceTint, in: .capsule)
                            .buttonStyle(.pave)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(14)
        .background(Color.white, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder) }
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .contentShape(.rect(cornerRadius: 18))
        .offset(drag)
        .opacity(1 - min(1, Double(abs(drag.width) + abs(drag.height)) / 240))
        .onTapGesture(perform: onDismiss)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { drag = $0.translation }
                .onEnded { value in
                    let thrown = value.predictedEndTranslation
                    if abs(thrown.width) > 120 || abs(thrown.height) > 80 {
                        onDismiss()
                    } else {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.2)) { drag = .zero }
                    }
                }
        )
        .frame(maxWidth: 560)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Antwoord van Ayla")
        .accessibilityAction(named: "Sluiten", onDismiss)
    }
}

#Preview {
    AylaShelfReply(text: "Dat kun je hier aanpassen onder Uiterlijk.", choices: ["Ja", "Nee"]) {}
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.canvas)
}
