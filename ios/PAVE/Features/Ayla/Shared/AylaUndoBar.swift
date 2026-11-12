import SwiftUI

/// Shown for a few seconds after deleting chats or forgetting a note, as in Gmail: what happened, and a way back.
struct AylaUndoBar: View {
    let message: String
    let onUndo: () -> Void

    init(message: String, onUndo: @escaping () -> Void) {
        self.message = message
        self.onUndo = onUndo
    }

    init(count: Int, onUndo: @escaping () -> Void) {
        self.init(message: count == 1 ? "Chat verwijderd" : "\(count) chats verwijderd", onUndo: onUndo)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(.iconTrash)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.inkMuted)
                .accessibilityHidden(true)
            Text(message)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
            Spacer(minLength: 8)
            Button("Ongedaan maken", action: onUndo)
                .textStyle(.link)
                .foregroundStyle(Color.paveAccent)
                .frame(minHeight: 44)
                .hoverEffect(.highlight)
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .frame(minHeight: 52)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .contain)
        .onAppear {
            AccessibilityNotification.Announcement("\(message). Ongedaan maken kan nog even.").post()
        }
    }
}

#Preview {
    AylaUndoBar(count: 2) {}
        .padding()
        .background(Color.canvas)
}
