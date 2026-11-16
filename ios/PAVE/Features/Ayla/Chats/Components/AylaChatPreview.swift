import PAVECore
import SwiftUI

/// What you see when you press and hold a conversation: its name and its last messages, as in Messages.
struct AylaChatPreview: View {
    let title: String
    let load: () async -> [AylaStoredMessage]

    @State private var messages: [AylaStoredMessage]?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .textStyle(.listTitle)
                .foregroundStyle(Color.ink)
                .lineLimit(2)
            if let messages {
                if messages.isEmpty {
                    Text("Nog geen berichten.")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                } else {
                    ForEach(messages) { message in
                        Text(message.text)
                            .textStyle(.caption)
                            .foregroundStyle(message.role == .user ? Color.white : Color.ink)
                            .lineLimit(3)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(message.role == .user ? Color.paveAccent : Color.paveSurfaceTint, in: .rect(cornerRadius: 14))
                            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .padding(16)
        .frame(width: 300, alignment: .topLeading)
        .background(Color.canvas)
        .task { messages = await load() }
    }
}

#Preview {
    AylaChatPreview(title: "Stage zoeken") {
        [
            AylaStoredMessage(id: "1", role: .user, text: "Welke stages passen bij mij?"),
            AylaStoredMessage(id: "2", role: .ayla, text: "Op basis van je kluis passen stages in softwareontwikkeling en IT-consultancy goed bij je."),
        ]
    }
}
