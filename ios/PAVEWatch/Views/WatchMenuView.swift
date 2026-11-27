import PAVECore
import SwiftUI

/// The menu behind a long press (or the list button): start a new conversation, or pick up a recent one, also one
/// started on the iPhone or the web. Deleting, pinning and renaming stay on the iPhone; the Watch is a voice bot.
struct WatchMenuView: View {
    @Bindable var model: WatchAylaModel
    @Environment(\.dismiss) private var dismiss
    @Environment(WatchSessionStore.self) private var sessions

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
                .listItemTint(WatchPreferences.shared.accentColor)

                if let step = sessions.nextStep, step.date > .now {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Volgende stap")
                            .font(.caption2)
                            .foregroundStyle(WatchPreferences.shared.accentColor)
                        Text(WatchNextStep.title(step))
                            .font(.headline)
                        Text(WatchNextStep.when(step))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    if step.kind == .talk {
                        NavigationLink {
                            WatchCoachView(company: step.company, model: model)
                        } label: {
                            Text(WatchMessages.coachTitle)
                        }
                    }
                }

                if case .plan(let name, let done, let total, let current) = sessions.plan {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan")
                            .font(.caption2)
                            .foregroundStyle(WatchPreferences.shared.accentColor)
                        Text(name).font(.headline).lineLimit(2)
                        ProgressView(value: Double(done), total: Double(max(total, 1)))
                            .tint(WatchPreferences.shared.accentColor)
                        Text("\(done) van \(total)" + (current.map { " · nu: \($0)" } ?? ""))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                let codes = sessions.sharedCodes.filter(\.isValid)
                if !codes.isEmpty {
                    NavigationLink {
                        WatchSharedCodeView(codes: codes)
                    } label: {
                        Text(codes.count == 1 ? "QR-code" : "QR-codes (\(codes.count))")
                    }
                }

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
