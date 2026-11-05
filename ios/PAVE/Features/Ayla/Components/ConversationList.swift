import PAVECore
import SwiftUI

struct ConversationList: View {
    let conversations: [AylaConversation]
    let currentID: String?
    let onNew: () -> Void
    let onOpen: (AylaConversation) -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Gesprekken")
                .textStyle(.title)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)

            Button(action: onNew) {
                HStack(spacing: 10) {
                    Image(.iconChat)
                        .accessibilityHidden(true)
                    Text("Nieuw gesprek")
                        .textStyle(.label)
                        .foregroundStyle(Color.brandGreen)
                }
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .padding(.horizontal, 16)
                .background(Color.surfaceTint, in: .rect(cornerRadius: 14))
                .contentShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            if conversations.isEmpty {
                Text("Je hebt nog geen gesprekken met Ayla.")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 24)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(conversations) { conversation in
                            row(conversation)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            Button("Uitloggen", action: onSignOut)
                .textStyle(.link)
                .foregroundStyle(Color.brandGreen)
                .frame(minHeight: 44)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.canvas)
    }

    private func row(_ conversation: AylaConversation) -> some View {
        Button {
            onOpen(conversation)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                Text(conversation.updatedAt, format: .relative(presentation: .named).locale(Locale(identifier: "nl_NL")))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(conversation.id == currentID ? Color.surfaceTint : .clear, in: .rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(conversation.id == currentID ? .isSelected : [])
    }
}

#Preview {
    ConversationList(
        conversations: [AylaConversation(id: "1", title: "Welke banen passen bij mij?", updatedAt: .now.addingTimeInterval(-3600))],
        currentID: "1", onNew: {}, onOpen: { _ in }, onSignOut: {}
    )
}
