import SwiftUI

/// "Vraag Ayla" under a vacancy, with her own letter: she tells in the chat why it fits and what you miss.
struct VacancyAskButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AylaLetter(color: .paveAccent)
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
                Text(AylaMessages.vacancyAskButton)
                    .textStyle(.chip)
                    .foregroundStyle(Color.paveAccent)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .background(Color.panel, in: .capsule)
            .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: 1) }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityHint("Ayla vertelt in de chat waarom deze vacature bij je past en wat je nog mist")
    }
}
