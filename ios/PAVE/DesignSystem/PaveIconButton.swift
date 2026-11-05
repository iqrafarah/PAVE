import SwiftUI

/// A round white button with an icon, as in the Ayla header.
struct PaveIconButton: View {
    let icon: ImageResource
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .frame(width: 37, height: 37)
                .background(Color.white, in: .circle)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 1)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    HStack {
        PaveIconButton(icon: .iconMenu, label: "Gesprekken") {}
        PaveIconButton(icon: .iconChat, label: "Nieuw gesprek") {}
    }
    .padding()
    .background(Color.canvas)
}
