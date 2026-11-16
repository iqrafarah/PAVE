import SwiftUI

/// What a place in the menu shows: Ayla's pixel A, an icon, or the bell.
enum MainMenuIcon {
    case aylaLetter
    case image(ImageResource)
    case bell
}

/// One place in the menu, as in ChatGPT: an icon with its name. The open place is green on a light green row.
struct MainSidebarRow: View {
    let destination: MainDestination
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon
                    .paveIconFrame(24)
                Text(destination.title)
                    .textStyle(.listTitle)
            }
            .foregroundStyle(isSelected ? Color.paveAccent : .ink)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(isSelected ? Color.paveSurfaceTint : .clear, in: .rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
        .hoverEffect(.highlight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(destination.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var icon: some View {
        switch destination.icon {
        case .aylaLetter:
            AylaLetter(color: isSelected ? .paveAccent : .ink)
                .paveIconScale()
        case .image(let resource):
            Image(resource).renderingMode(.template).paveIconScale()
        case .bell:
            Image(.iconBell).paveIconScale()
        }
    }
}

#Preview {
    VStack(spacing: 4) {
        MainSidebarRow(destination: .ayla, isSelected: true) {}
        MainSidebarRow(destination: .vault, isSelected: false) {}
        MainSidebarRow(destination: .plan, isSelected: false) {}
    }
    .frame(width: 260)
    .padding()
}
