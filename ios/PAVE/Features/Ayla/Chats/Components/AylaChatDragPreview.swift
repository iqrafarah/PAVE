import SwiftUI

/// What follows your finger while you drag a chat: its name on a small card.
struct AylaChatDragPreview: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(.iconChat)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(16)
                .foregroundStyle(Color.paveAccent)
            Text(title)
                .textStyle(.listTitle)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.cardBorder) }
    }
}
