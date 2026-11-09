import SwiftUI

/// Notifications: the bell from the web sidebar (Figma 1726:149), with its own grey circle. Green ring when open.
/// Inside a glass capsule (`isPlain`) only the bell itself, so there is no circle within the glass.
struct MainBellButton: View {
    let isSelected: Bool
    var isPlain = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            bell
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(Color.brandGreen, lineWidth: 2)
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .hoverEffect(.highlight)
        .accessibilityLabel("Meldingen")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var bell: some View {
        if isPlain {
            Image(.iconBell)
                .renderingMode(.template)
                .foregroundStyle(isSelected ? Color.brandGreen : Color.ink)
                .frame(width: 44, height: 44)
        } else {
            Image(.iconBell)
        }
    }
}

#Preview {
    HStack {
        MainBellButton(isSelected: false) {}
        MainBellButton(isSelected: true) {}
    }
    .padding()
}
