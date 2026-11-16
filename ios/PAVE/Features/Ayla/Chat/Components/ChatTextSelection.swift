import SwiftUI

/// A message on its own, to select part of it, as "Select text" does in ChatGPT.
struct ChatTextSelection: View {
    let text: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .textStyle(.bubble)
                    .foregroundStyle(Color.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Tekst selecteren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    ChatTextSelection(text: "Je kunt een stuk van dit antwoord selecteren en kopiëren.")
}
