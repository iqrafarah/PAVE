import SwiftUI

/// Shown for a few seconds after deleting chats, as in Gmail: what happened, and a way back.
struct AylaUndoBar: View {
    let count: Int
    let onUndo: () -> Void

    private var message: String {
        count == 1 ? "Chat verwijderd" : "\(count) chats verwijderd"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .foregroundStyle(Color.inkMuted)
                .accessibilityHidden(true)
            Text(message)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
            Spacer(minLength: 8)
            Button("Ongedaan maken", action: onUndo)
                .textStyle(.link)
                .foregroundStyle(Color.brandGreen)
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
