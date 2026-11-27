import SwiftUI

/// Ayla's answer while a page is open over the chat: her chat bubble floating at the top, over the page or over the
/// chat above it, so you read it without closing the page and nothing on the page moves. Tap it or drag it away, like
/// her orb; the answer stays in the chat.
struct AylaShelfReply: View {
    /// Nil while she is still thinking.
    let text: String?
    /// What shows while she thinks.
    var thinking = AylaMessages.thinking
    var choices: [String] = []
    /// Room above it: past the grabber on a page, close under the status bar over the chat.
    var topPadding: CGFloat = 26
    var lineLimit = 6
    var onChoose: (String) -> Void = { _ in }
    let onDismiss: () -> Void

    @State private var drag = CGSize.zero
    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                AylaLetter(color: .paveAccent)
                    .frame(width: 18, height: 18)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                Text(text ?? thinking)
                    .textStyle(.bubble)
                    .foregroundStyle(Color.paveAccent.opacity(text == nil ? 0.6 : 1))
                    .lineLimit(lineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(10)
                    .foregroundStyle(Color.paveAccent)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
            if !choices.isEmpty {
                // Onto a second line when three do not fit, so no answer is cut off on a narrow screen.
                FlowLayout(spacing: 8) {
                    ForEach(choices, id: \.self) { choice in
                        Button(choice) { onChoose(choice) }
                            .textStyle(.gapChip)
                            .foregroundStyle(Color.paveAccent)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(Color.panel, in: .capsule)
                            .buttonStyle(.pave)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
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
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, 4)
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
