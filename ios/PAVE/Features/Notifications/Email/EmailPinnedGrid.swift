import SwiftUI

/// Pinned conversations at the top of Meldingen, as in Messages: big photos with the name under them, a dot while
/// there is something new. Hold one to unpin it.
struct EmailPinnedGrid: View {
    let threads: [EmailThread]
    let onOpen: (String) -> Void
    let onUnpin: (String) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 3), spacing: 16) {
            // No Buttons here: several in one List row all react to a tap, and a hold could unpin the wrong one. Each
            // tile has its own tap and its own menu, with the menu's preview cut to that tile.
            ForEach(threads) { thread in
                let id = thread.id
                tile(thread)
                    .contentShape(.contextMenuPreview, .rect(cornerRadius: 16))
                    .onTapGesture { onOpen(id) }
                    .contextMenu {
                        Button { onUnpin(id) } label: { Label("Losmaken", tinted: .iconBookmarkSolid) }
                        Button(role: .destructive) { onDelete(id) } label: { Label("Verwijderen", tinted: .iconTrash) }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("\(thread.participantNames), \(thread.subject)\(thread.isUnread ? ", ongelezen" : "")")
                    .accessibilityHint("Vastgezet gesprek")
                    .accessibilityAction { onOpen(id) }
                    .accessibilityActions {
                        Button("Losmaken") { onUnpin(id) }
                        Button("Verwijderen") { onDelete(id) }
                    }
            }
        }
        .padding(.vertical, 6)
    }

    private func tile(_ thread: EmailThread) -> some View {
        VStack(spacing: 6) {
            EmailAvatarStack(people: Array(thread.participants.prefix(2)), size: 64)
                .overlay(alignment: .topLeading) {
                    if thread.isUnread {
                        Circle()
                            .fill(Color.paveAccent)
                            .frame(width: 14, height: 14)
                            .overlay { Circle().strokeBorder(Color.canvas, lineWidth: 2) }
                            .offset(x: -2, y: -2)
                    }
                }
            Text(thread.participantNames)
                .textStyle(thread.isUnread ? .listTitle : .meta)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
            if !thread.subject.isEmpty {
                Text(thread.subject)
                    .textStyle(.meta)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .contentShape(.rect(cornerRadius: 16))
    }
}
