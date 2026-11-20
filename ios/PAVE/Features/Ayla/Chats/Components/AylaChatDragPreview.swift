import PAVECore
import SwiftUI

/// What follows your finger while you drag a chat: the row itself, lifted on a card, so it looks like the chat you
/// picked up.
struct AylaChatDragPreview: View {
    let conversation: AylaConversation

    var body: some View {
        AylaChatRow(conversation: conversation, isCurrent: false) {}
            .frame(width: 280)
            .background(Color.panel, in: .rect(cornerRadius: 12))
            .compositingGroup()
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}
