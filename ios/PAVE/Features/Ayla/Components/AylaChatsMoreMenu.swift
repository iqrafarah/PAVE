import SwiftUI

/// The button with three dots above the chats, with what you need less often: selecting several chats.
struct AylaChatsMoreMenu: View {
    let onSelect: () -> Void

    var body: some View {
        Menu {
            Button(action: onSelect) {
                Label("Selecteren", systemImage: "checkmark.circle.fill")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .simultaneousGesture(TapGesture().onEnded { PaveHaptics.tap(.light) })
        .accessibilityLabel("Meer opties")
    }
}

#Preview {
    NavigationStack {
        Color.canvas
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AylaChatsMoreMenu {}
                }
            }
    }
}
