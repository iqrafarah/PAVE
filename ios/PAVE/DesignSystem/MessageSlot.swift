import SwiftUI

/// Holds the space of the tallest message that can appear here, so showing,
/// changing or hiding a message never moves the rest of the screen.
struct MessageSlot<Content: View>: View {
    let message: String?
    let reserving: [String]
    @ViewBuilder let content: (String) -> Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(Set(reserving)).sorted(), id: \.self) { candidate in
                content(candidate)
                    .hidden()
                    .accessibilityHidden(true)
            }
            if let message {
                content(message)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

#Preview {
    @Previewable @State var message: String?
    VStack(alignment: .leading, spacing: 16) {
        MessageSlot(message: message, reserving: ["Kort.", "Een veel langere melding die over meerdere regels loopt en toch niets laat verspringen."]) {
            PaveInlineError(message: $0)
        }
        Button("Wissel") { message = message == nil ? "Kort." : nil }
        Text("Deze regel blijft staan.")
    }
    .padding(32)
    .animation(.easeOut(duration: 0.2), value: message)
}
