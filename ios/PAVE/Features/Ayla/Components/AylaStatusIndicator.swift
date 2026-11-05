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
        VStack(spacing: 14) {
            Group {
                switch state {
                case .thinking: AylaThinkingBlocks()
                case .failed: AylaFallenBlocks()
                }
            }
            .accessibilityHidden(true)
            Text(message)
                .textStyle(.status)
                .foregroundStyle(state == .thinking ? Color.brandGreen : .criticalInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
