import SwiftUI

/// Ayla has questions that would make the CV stronger: one line over the page, which opens them.
struct ApplicationQuestionsPill: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AylaLetter(color: .paveAccent)
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
                Text(ApplyMessages.aylaAsks(count))
                    .textStyle(.chip)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .contentShape(.capsule)
        }
        .buttonStyle(.pave)
        .glassEffect(.regular.tint(Color.panel.opacity(0.78)), in: .capsule)
    }
}
