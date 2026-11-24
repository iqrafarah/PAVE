import SwiftUI

/// The pixel blocks from Figma. While Ayla thinks they build up four slashes one by one;
/// when something goes wrong they tumble over in red.
struct AylaStatusIndicator: View {
    enum State: Equatable {
        case thinking
        case failed
    }

    let state: State
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Group {
                switch state {
                case .thinking: AylaThinkingBlocks()
                case .failed: AylaFallenBlocks()
                }
            }
            .accessibilityHidden(true)
            Text(message)
                .textStyle(.status)
                .foregroundStyle(state == .thinking ? Color.paveAccent : .criticalInk)
                .multilineTextAlignment(.center)
                // Thinking stays one line, so a longer status never moves the conversation.
                .lineLimit(state == .thinking ? 1 : nil)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: message)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 60) {
        AylaStatusIndicator(state: .thinking, message: "Ayla denkt na")
        AylaStatusIndicator(state: .failed, message: "Ayla kon nu geen antwoord geven.")
    }
}
