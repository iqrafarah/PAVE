import SwiftUI

/// The light panel behind the header once a conversation has started, with round bottom corners.
/// It blurs messages that scroll underneath.
struct AylaHeaderPanel: View {
    var body: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40, style: .continuous)
        shape
            .fill(Color.white.opacity(0.2))
            .background(Color.canvas.opacity(0.88), in: shape)
            .background(.ultraThinMaterial, in: shape)
            .shadow(color: .black.opacity(0.06), radius: 7, y: 1)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack {
        AylaHeaderPanel()
            .frame(height: 134)
        Spacer()
    }
    .ignoresSafeArea()
    .background(Color.canvas)
}
