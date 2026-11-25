import SwiftUI

/// Leaves a flow from its top right corner. The flow decides whether to ask first.
struct PaveCloseButton: View {
    var label = "Sluiten"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(.iconXMark)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(16)
                .foregroundStyle(Color.inkMuted)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel(label)
    }
}

#Preview {
    PaveCloseButton {}
}
