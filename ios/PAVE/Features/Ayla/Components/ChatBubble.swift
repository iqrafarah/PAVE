import SwiftUI

struct ChatBubble: View {
    enum Speaker {
        case user
        case ayla(showsMark: Bool)
    }

    let text: String
    let speaker: Speaker

    private var isUser: Bool {
        if case .user = speaker { true } else { false }
    }

    var body: some View {
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: 40) }
            bubble
            if !isUser { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUser ? "Jij: \(text)" : "Ayla: \(text)")
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
                    .textSelection(.enabled)
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
        ChatBubble(text: "Ik ga je helpen zoeken! Welke gegevens mag ik hiervoor gebruiken?", speaker: .ayla(showsMark: true))
    }
    .padding(.leading, 32)
    .padding(.trailing, 33)
    .background(Color.canvas)
}
