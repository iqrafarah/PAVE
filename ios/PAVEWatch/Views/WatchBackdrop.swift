import SwiftUI

/// The glow behind Ayla, like on the iPhone: PAVE green that comes up from below and grows while she listens or
/// speaks, the thinking glow while she thinks and the error glow when something went wrong. Black when the screen
/// is dimmed, so the always-on display stays calm.
struct WatchBackdrop: View {
    let phase: WatchAylaModel.Phase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        LinearGradient(
            stops: [.init(color: .black, location: start), .init(color: glow, location: 1)],
            startPoint: .top,
            endPoint: .bottom
        )
        .animation(.easeInOut(duration: 0.6), value: phase)
        .animation(.easeInOut(duration: 0.3), value: isLuminanceReduced)
    }

    private var glow: Color {
        if isLuminanceReduced { return .black }
        return switch phase {
        case .ready, .answer: .brandGreen.opacity(0.7)
        case .listening, .speaking: .brandGreen
        case .understanding, .thinking: .thinkingGlow
        case .failed: .errorGlow
        }
    }

    private var start: Double {
        switch phase {
        case .listening, .speaking: 0.25
        default: 0.4
        }
    }
}

#Preview {
    WatchBackdrop(phase: .listening)
}
