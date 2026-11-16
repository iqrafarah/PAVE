import PAVECore
import SwiftUI

/// A conversation in which the search text was found in a message: its name, and the piece of text with the
/// search text in bold.
struct AylaChatSearchRow: View {
    let conversation: AylaConversation
    let snippet: String
    let search: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.title)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Text(Self.highlighted(snippet, search))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
        .hoverEffect(.highlight)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    static func highlighted(_ text: String, _ search: String) -> AttributedString {
        var result = AttributedString(text)
        let words = search.trimmingCharacters(in: .whitespaces)
        guard !words.isEmpty, let range = result.range(of: words, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return result
        }
        result[range].foregroundColor = Color.ink
        result[range].inlinePresentationIntent = .stronglyEmphasized
        return result
    }
}

#Preview {
    AylaChatSearchRow(
        conversation: AylaConversation(id: "1", title: "Stage zoeken", updatedAt: .now),
        snippet: "…en wil nu graag een stage zoeken in de zorg, liefst in Eindhoven…",
        search: "zorg"
    ) {}
    .padding()
}
