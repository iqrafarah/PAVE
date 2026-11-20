import SwiftUI

/// A folder above the vault list. Tapping it opens the folder; something dragged over it lights it up.
struct VaultFolderTile: View {
    let title: String
    let icon: ImageResource
    var color: Color = .paveAccent
    var surface: Color = .paveSurfaceTint
    var iconColor: Color = .white
    var isPinned = false
    let count: Int
    let isSelected: Bool
    var isDropTarget = false
    /// When choosing items (for Ayla): whether everything in the folder is chosen.
    var checkbox: Bool?
    let action: () -> Void

    static let width: CGFloat = 140

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                surface
                    .frame(height: 50)
                    .overlay(alignment: .bottomLeading) {
                        Image(.vaultFolder)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 46, height: 38)
                            .foregroundStyle(color)
                            .overlay {
                                Image(icon)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(iconColor)
                                    .frame(width: 18, height: 18)
                                    .offset(y: 2)
                            }
                            .padding(.leading, 13)
                            .offset(y: 7)
                    }
                    .zIndex(1)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(title)
                            .textStyle(.tileTitle)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.inkMuted)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(VaultMessages.itemCount(count))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.horizontal, 13)
                .padding(.top, 13)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.panel)
            }
            .frame(width: Self.width)
            .clipShape(.rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    // Held over with a card, it shows the same outline as a chosen folder.
                    .strokeBorder(isSelected || isDropTarget ? color : Color.cardBorder, lineWidth: isSelected || isDropTarget ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if let checkbox {
                    PaveCheckbox(isOn: checkbox, size: 18)
                        .padding(10)
                }
            }
            .contentShape(.rect(cornerRadius: 16))
            .animation(.easeOut(duration: 0.15), value: isDropTarget)
        }
        .buttonStyle(.pave)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isPinned ? "vastgezet, " : "")\(VaultMessages.itemCount(count))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "" : "Opent de map")
    }
}

#Preview {
    HStack {
        VaultFolderTile(title: "Certificaten", icon: .iconCheckBadgeOutline, count: 1, isSelected: true) {}
        VaultFolderTile(title: "Mijn stage", icon: .iconFolderOutline, count: 4, isSelected: false) {}
    }
    .padding()
    .background(Color.canvas)
}
