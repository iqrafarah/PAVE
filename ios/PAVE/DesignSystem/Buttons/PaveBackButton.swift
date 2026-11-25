import SwiftUI

/// One step back in a flow with steps, at the top left: the same arrow as the studio and the sign-in.
struct PaveBackButton: View {
    var label = "Terug"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(.iconArrowLeftSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(18)
                .foregroundStyle(Color.ink)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel(label)
    }
}

#Preview {
    PaveBackButton {}
}
