import PAVECore
import SwiftUI

/// The top of an open folder, as on the web: its badge, its name, how much is in it, and its menu.
struct VaultFolderHeader: View {
    @Environment(VaultModel.self) private var model
    let folder: VaultFolder
    let count: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let style = model.style(of: folder)
        HStack(spacing: 12) {
            Image(.vaultFolder)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 38)
                .foregroundStyle(style.color.color)
                .overlay {
                    Image(style.icon.image)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(style.color.foreground)
                        .frame(width: 18, height: 18)
                        .offset(y: 2)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .textStyle(.emptyTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                Text(VaultMessages.itemCount(count))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button(action: onEdit) {
                    Label { Text("Map aanpassen") } icon: { Image(.iconPencil) }
                }
                Button(role: .destructive, action: onDelete) {
                    Label { Text("Map verwijderen") } icon: { Image(.iconTrash) }
                }
            } label: {
                Image(.iconEllipsis)
                    .renderingMode(.template)
                    .foregroundStyle(Color.ink)
                    .paveIconFrame(44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Acties voor \(folder.name)")
        }
    }
}
