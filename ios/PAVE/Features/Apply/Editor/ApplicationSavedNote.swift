import SwiftUI

/// A short note over the page after each change is written to the device, then it fades away.
struct ApplicationSavedNote: View {
    let savedAt: Date?

    @State private var isShown = false
    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isShown {
                HStack(spacing: 6) {
                    Image(.iconCheckBadgeSolid)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(13)
                        .foregroundStyle(Color.paveAccent)
                        .accessibilityHidden(true)
                    Text(ApplyMessages.saved)
                        .textStyle(.caption)
                        .foregroundStyle(Color.ink)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 30)
                .background(Color.panel, in: .capsule)
                .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: 1) }
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isShown)
        .allowsHitTesting(false)
        .task(id: savedAt) {
            guard savedAt != nil else { return }
            isShown = true
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            isShown = false
        }
    }
}

#Preview {
    ApplicationSavedNote(savedAt: .now)
}
