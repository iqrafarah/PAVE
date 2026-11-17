import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// What is being dragged in the vault: a card or a folder. Carried as text, such as "pave-folder:<id>".
enum VaultDrag: Equatable {
    case item(String)
    case folder(String)

    private static let itemPrefix = "pave-item:"
    private static let folderPrefix = "pave-folder:"

    var payload: String {
        switch self {
        case .item(let id): Self.itemPrefix + id
        case .folder(let id): Self.folderPrefix + id
        }
    }

    init?(payload: String) {
        if payload.hasPrefix(Self.itemPrefix) {
            self = .item(String(payload.dropFirst(Self.itemPrefix.count)))
        } else if payload.hasPrefix(Self.folderPrefix) {
            self = .folder(String(payload.dropFirst(Self.folderPrefix.count)))
        } else {
            return nil
        }
    }
}

/// A swap that just happened, so the next one waits a moment: the layout animates under the finger, and without this
/// the tile that moved away would be entered again at once and swap back.
struct VaultSwap: Equatable {
    let target: String
    let at: Date

    static let settleTime: TimeInterval = 0.3

    func blocks(_ target: String, now: Date = .now) -> Bool {
        self.target == target && now.timeIntervalSince(at) < Self.settleTime
    }
}

/// Everything in the vault is moved, never copied, so iOS shows no plus and no no-entry sign on the dragged tile.
private let moving = DropProposal(operation: .move)

/// The whole folder row while a folder is dragged along it: a still layer over the sliding tiles, so the finger's place
/// is measured against something that never moves. Its x is the place in the row's content, scrolled or not.
struct VaultFolderRowDropDelegate: DropDelegate {
    @Binding var fingerX: CGFloat?
    let onDrop: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        fingerX = info.location.x
        return moving
    }

    func performDrop(info: DropInfo) -> Bool {
        onDrop()
        return true
    }
}

/// A folder while a card is dragged over it: it lights up, and the card goes into it when you let go.
struct VaultFolderDropDelegate: DropDelegate {
    let folderID: String
    let drag: VaultDrag?
    @Binding var target: String?
    let onDropItem: (String) -> Void
    let onDropFolder: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        drag != nil
    }

    func dropEntered(info: DropInfo) {
        guard case .item = drag else { return }
        target = folderID
        PaveHaptics.selection()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if case .item = drag, target != folderID { target = folderID }
        return moving
    }

    func dropExited(info: DropInfo) {
        if target == folderID { target = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        target = nil
        switch drag {
        case .item(let id):
            onDropItem(id)
            return true
        case .folder:
            onDropFolder()
            return true
        case nil:
            return false
        }
    }
}

/// A card while another card is dragged over it: the dragged card takes its place at once, in the grid or the list.
struct VaultItemDropDelegate: DropDelegate {
    let itemID: String
    let drag: VaultDrag?
    @Binding var order: [String]?
    @Binding var lastSwap: VaultSwap?
    let onDrop: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        if case .item = drag { true } else { false }
    }

    func dropEntered(info: DropInfo) {
        guard case .item(let id) = drag, id != itemID, lastSwap?.blocks(itemID) != true, var current = order,
              let from = current.firstIndex(of: id), let to = current.firstIndex(of: itemID) else { return }
        current.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        lastSwap = VaultSwap(target: itemID, at: .now)
        withAnimation(.snappy(duration: 0.28)) { order = current }
        PaveHaptics.selection()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        moving
    }

    func performDrop(info: DropInfo) -> Bool {
        onDrop()
        return true
    }
}

extension View {
    /// The folders or the cards as one group you can drag from. Everything in it is moved, never copied, so iOS shows no
    /// plus and no no-entry sign; the dragged tile itself is the picture under your finger. The page hears when the drag
    /// really moves and when it ends, wherever it is let go. Before iOS 27 there is no dragging in the vault: the menus
    /// ("Verplaatsen naar", "Naar voren") do the same.
    @ViewBuilder
    func vaultDragContainer(
        in namespace: Namespace.ID,
        onStart: @escaping (VaultDrag) -> Void,
        onActive: @escaping () -> Void,
        onEnd: @escaping () -> Void
    ) -> some View {
        if #available(iOS 27.0, *) {
            dragContainer(for: String.self, itemID: \.self, in: namespace) { (payload: String) -> [String] in
                if let drag = VaultDrag(payload: payload) { onStart(drag) }
                return [payload]
            }
            .dragConfiguration(DragConfiguration(allowMove: true))
            .onDragSessionUpdated { session in
                switch session.phase {
                case .active: onActive()
                case .ended, .dataTransferCompleted: onEnd()
                default: break
                }
            }
        } else {
            self
        }
    }

    /// One tile or card of such a group.
    @ViewBuilder
    func vaultDraggable(_ drag: VaultDrag, in namespace: Namespace.ID) -> some View {
        if #available(iOS 27.0, *) {
            draggable(containerItemID: drag.payload, containerNamespace: namespace)
        } else {
            self
        }
    }
}
