import SwiftUI

/// Where you are in the steps: one bar per step, the ones done filled.
struct ShareStepBar: View {
    let step: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.paveAccentFill : Color.tileFill)
                    .frame(height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Stap \(step + 1) van \(count)")
        .animation(.easeOut(duration: 0.2), value: step)
    }
}
