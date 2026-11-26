import SwiftUI

/// One step back in a flow with steps: the same chevron as the system's back button in the chats and every other
/// pushed page, so going back always looks the same.
struct PaveBackButton: View {
    var label = "Terug"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PaveBackChevron()
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel(label)
    }
}

/// The system's back chevron, for back buttons drawn by the app itself.
struct PaveBackChevron: View {
    var size: CGFloat = 17

    var body: some View {
        Image(systemName: "chevron.backward")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Color.ink)
            .accessibilityHidden(true)
    }
}

#Preview {
    PaveBackButton {}
}
