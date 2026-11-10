import SwiftUI

struct ChatBubble: View {
    enum Speaker {
        case user
        case ayla(showsMark: Bool)
    }

    /// Something to do with the message, in the menu that opens when you press and hold it.
    struct Action: Identifiable {
        let title: String
        let icon: ImageResource
        let perform: () -> Void

        var id: String { title }
    }

    let text: String
    let speaker: Speaker
    var actions: [Action] = []

    private var isUser: Bool {
        if case .user = speaker { true } else { false }
    }

    var body: some View {
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: 40) }
            bubble
                .contentShape(.contextMenuPreview, .rect(cornerRadius: 18))
                .contextMenu {
                    ForEach(actions) { action in
                        Button {
                            PaveHaptics.tap(.light)
                            action.perform()
                        } label: {
                            Label(action.title, image: action.icon)
                        }
                    }
                }
            if !isUser { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUser ? "Jij: \(text)" : "Ayla: \(text)")
        .accessibilityActions {
            ForEach(actions) { action in
                Button(action.title, action: action.perform)
            }
        }
    }

    private var bubble: some View {
        HStack(alignment: .top, spacing: 8.4) {
            if case .ayla(true) = speaker {
                PaveMark()
            }
            MaxWidthLayout(maxWidth: isUser ? 232 : 230) {
                Text(text)
                    .textStyle(.bubble)
                    .foregroundStyle(isUser ? Color.ink : .brandGreen)
            }
        }
        .padding(.leading, isUser ? 14 : 15)
        .padding(.trailing, isUser ? 14 : 15)
        .padding(.top, isUser ? 15 : 14)
        .padding(.bottom, 14)
        .background(isUser ? Color.bubbleUser : .surfaceTint, in: .rect(cornerRadius: 18))
    }
}

#Preview {
    VStack(spacing: 20) {
        ChatBubble(text: "Heb ik in de kluis al iets staan over mijn LiveWall stage?", speaker: .user)
        ChatBubble(text: "Ik ga je helpen zoeken!", speaker: .ayla(showsMark: false))
        ChatBubble(
            text: "Ik ga je helpen zoeken! Welke gegevens mag ik hiervoor gebruiken?",
            speaker: .ayla(showsMark: true),
            actions: [.init(title: "Kopiëren", icon: .iconDocumentDuplicate) {}]
        )
    }
    .padding(.leading, 32)
    .padding(.trailing, 33)
    .background(Color.canvas)
}
