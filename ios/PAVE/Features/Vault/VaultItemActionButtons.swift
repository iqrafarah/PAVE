import PAVECore
import SwiftUI

/// Aanpassen, Verplaatsen naar map and Verwijderen, for the menu on the item page and the long press on a card.
struct VaultItemActionButtons: View {
    @Environment(VaultModel.self) private var model
    let item: VaultItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if item.isEditable {
            Button(action: onEdit) {
                SwiftUI.Label { Text("Aanpassen") } icon: { Image(.iconPencil) }
            }
        }
        if !model.folders.isEmpty {
            Menu {
                Picker("Map", selection: Binding(
                    get: { item.folderID },
                    set: { folderID in Task { await model.move(item, to: folderID) } }
                )) {
                    Text("Geen map").tag(String?.none)
                    ForEach(model.folders) { folder in
                        Text(folder.name).tag(Optional(folder.id))
                    }
                }
            } label: {
                SwiftUI.Label { Text("Verplaatsen naar map") } icon: { Image(.iconFolderArrowDownSolid) }
            }
        }
        Button(role: .destructive, action: onDelete) {
            SwiftUI.Label { Text("Verwijderen") } icon: { Image(.iconTrash) }
        }
    }
}
