import PAVECore
import SwiftUI

/// The last messages of one conversation, with "Verder praten" to go back to the orb inside it.
struct WatchConversationView: View {
    @Bindable var model: WatchAylaModel
    let conversation: AylaConversation
    let onContinue: () -> Void

    @State private var messages: [AylaStoredMessage] = []
    @State private var isLoading = true
    @State private var problem: String?

    /// Only the end of a conversation fits on the wrist.
    private static let shownMessages = 8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(messages.suffix(Self.shownMessages)) { message in
                        bubble(message)
                    }
                }
                Button {
                    model.continueConversation(conversation, messages: messages)
                    onContinue()
                } label: {
                    Text("Verder praten")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
                .disabled(isLoading)
                .padding(.top, 6)
            }
        }
        .navigationTitle(conversation.title)
        .task {
            do {
                messages = try await model.messages(in: conversation)
            } catch {
                problem = WatchMessages.message(for: AylaError(error))
            }
            isLoading = false
        }
    }

    private func bubble(_ message: AylaStoredMessage) -> some View {
        let isUser = message.role == .user
        return Text(message.text)
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isUser ? Color.white.opacity(0.14) : Color.brandGreen.opacity(0.35), in: .rect(cornerRadius: 12))
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            .accessibilityLabel(isUser ? "Jij: \(message.text)" : "Ayla: \(message.text)")
    }
}
