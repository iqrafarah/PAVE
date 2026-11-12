import PAVECore
import SwiftUI

/// Aanpassen, Verplaatsen naar map and Verwijderen, for the menu on the item page and the long press on a card.
struct VaultItemActionButtons: View {
    @Environment(VaultModel.self) private var model
    let item: VaultItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onEdit) {
            SwiftUI.Label { Text("Aanpassen") } icon: { Image(.iconPencil) }
        }
        if !model.folders.isEmpty {
            // An item can be in several folders: each one is ticked on or off, and the menu stays open meanwhile.
            Menu {
                ForEach(model.folders) { folder in
                    Toggle(isOn: Binding(
                        get: { item.folderIDs.contains(folder.id) },
                        set: { _ in Task { await model.toggle(folder, for: item) } }
                    )) {
                        Text(folder.name)
                    }
                }
            } label: {
                SwiftUI.Label { Text("In mappen") } icon: { Image(.iconFolderArrowDownSolid) }
            }
            .menuActionDismissBehavior(.disabled)
        }
        Button(role: .destructive, action: onDelete) {
            SwiftUI.Label { Text("Verwijderen") } icon: { Image(.iconTrash) }
        }
    }
}
