import PAVECore
import SwiftUI

/// The menu behind a long press (or the list button): start a new conversation, or pick up a recent one, also one
/// started on the iPhone or the web. Deleting, pinning and renaming stay on the iPhone; the Watch is a voice bot.
struct WatchMenuView: View {
    @Bindable var model: WatchAylaModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    model.startOver()
                    dismiss()
                } label: {
                    Label {
                        Text("Nieuw gesprek")
                    } icon: {
                        Image(.watchIconPlus).renderingMode(.template)
                    }
                }
                .listItemTint(.brandGreen)

                NavigationLink {
                    WatchMemoryView(model: model)
                } label: {
                    Text("Wat Ayla over je weet")
                }

                Section("Recente gesprekken") {
                    if model.isLoadingConversations {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if let problem = model.conversationsProblem {
                        Text(problem)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if model.conversations.isEmpty {
                        Text("Nog geen gesprekken.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.conversations) { conversation in
                            NavigationLink {
                                WatchConversationView(model: model, conversation: conversation) { dismiss() }
                            } label: {
                                row(conversation)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ayla")
            .task { await model.loadConversations() }
        }
    }

    private func row(_ conversation: AylaConversation) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conversation.title)
                .font(.footnote.weight(.medium))
                .lineLimit(2)
            Text(conversation.updatedAt, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(conversation.id == model.currentConversationID ? .isSelected : [])
    }
}
