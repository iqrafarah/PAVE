import SwiftUI

struct ChatBubble: View {
    enum Speaker {
        case user
        case ayla(showsMark: Bool)
    }

    let text: String
    let speaker: Speaker

    var body: some View {
        HStack {
            if case .user = speaker { Spacer(minLength: 56) }
            HStack(alignment: .top, spacing: 9) {
                if case .ayla(true) = speaker {
                    AylaMark()
                        .padding(.top, 2)
                }
                Text(text)
                    .textStyle(.bubble)
                    .foregroundStyle(isUser ? Color.ink : .brandGreen)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)
            .background(isUser ? Color.bubbleUser : .surfaceTint, in: .rect(cornerRadius: 18))
            .frame(maxWidth: 340, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 56) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUser ? "Jij: \(text)" : "Ayla: \(text)")
    }

    private var isUser: Bool {
        if case .user = speaker { true } else { false }
    }
}

#Preview {
    VStack(spacing: 20) {
        ChatBubble(text: "Heb ik in de kluis al iets staan over mijn LiveWall stage?", speaker: .user)
        ChatBubble(text: "Ik ga je helpen zoeken!", speaker: .ayla(showsMark: false))
        ChatBubble(text: "Ik heb 3 vacatures gevonden", speaker: .ayla(showsMark: true))
    }
    .padding(32)
    .background(Color.canvas)
}
