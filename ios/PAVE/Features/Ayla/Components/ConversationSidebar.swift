import PAVECore
import SwiftUI

/// The list of conversations. On iPhone you open it with the menu button;
/// on the inner display of iPhone Duo and on iPad it is the sidebar next to the chat.
struct ConversationSidebar: View {
    let conversations: [AylaConversation]
    @Binding var selection: String?
    let onNew: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        List(selection: $selection) {
            Section {
                Button(action: onNew) {
                    Label {
                        Text("Nieuw gesprek")
                            .textStyle(.label)
                            .foregroundStyle(Color.brandGreen)
                    } icon: {
                        Image(.iconChat)
                            .renderingMode(.template)
                            .foregroundStyle(Color.brandGreen)
                    }
                }
                .listRowBackground(Color.surfaceTint)
            }

            Section {
                if conversations.isEmpty {
                    Text("Je hebt nog geen gesprekken met Ayla.")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.inkMuted)
                } else {
                    ForEach(conversations) { conversation in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title)
                                .textStyle(.label)
                                .foregroundStyle(Color.ink)
                                .lineLimit(2)
                            Text(conversation.updatedAt, format: .relative(presentation: .named).locale(Locale(identifier: "nl_NL")))
                                .textStyle(.caption)
                                .foregroundStyle(Color.inkMuted)
                        }
                        .padding(.vertical, 4)
                        .tag(conversation.id)
                    }
                }
            } header: {
                Text("Gesprekken")
                    .textStyle(.eyebrow)
                    .foregroundStyle(Color.brandGreen)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.canvas)
        .navigationTitle("Gesprekken")
        .safeAreaInset(edge: .bottom) {
            Button("Uitloggen", action: onSignOut)
                .textStyle(.link)
                .foregroundStyle(Color.brandGreen)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .buttonStyle(.plain)
                .background(Color.canvas)
        }
    }
}

#Preview {
    @Previewable @State var selection: String? = "1"
    NavigationStack {
        ConversationSidebar(
            conversations: [
                AylaConversation(id: "1", title: "Welke banen passen bij mij?", updatedAt: .now.addingTimeInterval(-3600)),
                AylaConversation(id: "2", title: "Hulp bij mijn cv", updatedAt: .now.addingTimeInterval(-86400 * 2)),
            ],
            selection: $selection, onNew: {}, onSignOut: {}
        )
    }
}
