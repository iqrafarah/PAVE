import PAVECore
import SwiftUI

/// Aanpassen, Bevestiging aanvragen, In mappen and Verwijderen, for the menu on the item page and the long press on a card.
/// In an open folder also Verplaatsen naar: out of this folder into another one, like dragging it.
struct VaultItemActionButtons: View {
    @Environment(VaultModel.self) private var model
    let item: VaultItem
    var movesFrom: VaultFolder?
    let onEdit: () -> Void
    let onRequestConfirmation: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onEdit) {
            SwiftUI.Label { Text("Aanpassen") } icon: { Image(.iconPencilSolid).renderingMode(.template) }
        }
        if item.status != .verified, !item.isAwaitingReview {
            Button(action: onRequestConfirmation) {
                SwiftUI.Label {
                    Text(item.status == .rejected ? VaultMessages.requestAgainAction : VaultMessages.requestAction)
                } icon: { Image(.iconCheckBadgeSolid).renderingMode(.template) }
            }
        }
        if let movesFrom, model.folders.count > 1 {
            Menu {
                ForEach(model.folders.filter { $0.id != movesFrom.id }) { folder in
                    Button(folder.name) {
                        Task { await model.move(item, to: folder, from: movesFrom.id) }
                    }
                }
            } label: {
                SwiftUI.Label { Text("Verplaatsen naar") } icon: { Image(.iconArrowRightSolid).renderingMode(.template) }
            }
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
                SwiftUI.Label { Text("In mappen") } icon: { Image(.iconFolderArrowDownSolid).renderingMode(.template) }
            }
            .menuActionDismissBehavior(.disabled)
        }
        if model.canArchive {
            Button {
                Task { await model.setArchived(true, item) }
            } label: {
                SwiftUI.Label { Text(RetentionMessages.archive) } icon: { Image(.iconArchiveBoxSolid).renderingMode(.template) }
            }
        }
        Button(role: .destructive, action: onDelete) {
            SwiftUI.Label { Text("Verwijderen") } icon: { Image(.iconTrashSolid).renderingMode(.template) }
        }
    }
}
