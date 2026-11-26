import SwiftUI

/// The mark in front of one step of Ayla's: an open circle while it waits, her block breathing while she is on it, a
/// tick once it is done, and a red mark when it did not work.
struct AylaStepMark: View {
    let state: AylaActionStep.State

    var body: some View {
        ZStack {
            switch state {
            case .waiting:
                Circle().strokeBorder(Color.inkMuted.opacity(0.45), lineWidth: 1.5)
            case .running:
                AylaStepBlocks(steps: [AylaActionStep(id: 0, title: "", state: .running)])
            case .done:
                Image(.iconCheck)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .padding(4.5)
                    .foregroundStyle(Color.white)
                    .background(Color.paveAccentFill, in: .circle)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            case .failed:
                Text("!")
                    .font(.custom("InterVariable-Bold", fixedSize: 11))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.criticalInk, in: .circle)
            }
        }
        .frame(width: 18, height: 18)
        .animation(.spring(duration: 0.3, bounce: 0.3), value: state)
        .accessibilityHidden(true)
    }
}
