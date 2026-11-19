import PAVECore
import SwiftUI

/// Instellingen › Archief: the chats and the evidence you archived. They are out of sight but kept; from here you put
/// them back or delete them for good.
struct ArchiveScreen: View {
    private enum Kind: String, CaseIterable, Identifiable {
        case chats = "Chats"
        case evidence = "Bewijsstukken"

        var id: Self { self }
    }

    @Environment(AylaChatModel.self) private var chats: AylaChatModel?
    @Environment(VaultModel.self) private var vault: VaultModel?
    @State private var kind = Kind.chats
    @State private var chatToDelete: AylaConversation?
    @State private var itemToDelete: VaultItem?

    private var archivedChats: [AylaConversation] { chats?.conversationList.archived ?? [] }
    private var archivedItems: [VaultItem] { vault?.archived ?? [] }

    var body: some View {
        SettingsPage(title: RetentionMessages.archiveTitle) {
            Picker("Soort", selection: $kind) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(RetentionMessages.archiveHint)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 8)
                .fixedSize(horizontal: false, vertical: true)
            switch kind {
            case .chats:
                if archivedChats.isEmpty {
                    empty("Je hebt geen chats in je archief", "Houd een chat ingedrukt en kies Archiveren om hem hier te bewaren.")
                } else {
                    SettingsGroup {
                        ForEach(archivedChats) { chat in
                            row(title: chat.title, subtitle: archivedOn(chat.archivedAt), icon: .iconChatBubbleLeftEllipsisSolid) {
                                chats?.setArchived(false, [chat])
                            } onDelete: {
                                chatToDelete = chat
                            }
                        }
                    }
                }
            case .evidence:
                if archivedItems.isEmpty {
                    empty("Je hebt geen bewijsstukken in je archief", "Houd een bewijsstuk in je kluis ingedrukt en kies Archiveren om het hier te bewaren.")
                } else {
                    SettingsGroup {
                        ForEach(archivedItems) { item in
                            row(title: item.title, subtitle: archivedOn(item.archivedAt), icon: .iconFolderSolid) {
                                Task { await vault?.setArchived(false, item) }
                            } onDelete: {
                                itemToDelete = item
                            }
                        }
                    }
                }
            }
        }
        .task {
            await chats?.refreshConversations()
            if let vault, vault.state != .ready { await vault.load() }
        }
        .confirmationDialog("Chat verwijderen?", isPresented: isPresented($chatToDelete), titleVisibility: .visible, presenting: chatToDelete) { chat in
            Button("Verwijderen", role: .destructive) {
                PaveHaptics.tap(.heavy)
                chats?.delete([chat])
            }
        } message: { _ in
            Text(RetentionMessages.deleteChatMessage)
        }
        .confirmationDialog("Uit je kluis verwijderen?", isPresented: isPresented($itemToDelete), titleVisibility: .visible, presenting: itemToDelete) { item in
            Button("Verwijderen", role: .destructive) {
                PaveHaptics.tap(.heavy)
                Task { await vault?.delete(item) }
            }
        } message: { _ in
            Text(VaultMessages.deleteItemMessage)
        }
    }

    private func row(title: String, subtitle: String?, icon: ImageResource, onRestore: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(17)
                .foregroundStyle(Color.white)
                .paveIconFrame(32)
                .background(Color.paveAccent, in: .rect(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Menu {
                Button(action: onRestore) {
                    Label { Text(RetentionMessages.restore) } icon: { Image(systemName: "arrow.uturn.backward.circle.fill") }
                }
                Button(role: .destructive, action: onDelete) {
                    Label { Text("Verwijderen") } icon: { Image(.iconTrash) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Meer voor \(title)")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .frame(minHeight: 60)
    }

    private func empty(_ title: String, _ message: String) -> some View {
        PaveEmptyState(icon: .iconArchiveBoxSolid, title: title, message: message)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
    }

    private func archivedOn(_ date: Date?) -> String? {
        date.map { "Gearchiveerd op \($0.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "nl_NL"))))" }
    }

    private func isPresented<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}
