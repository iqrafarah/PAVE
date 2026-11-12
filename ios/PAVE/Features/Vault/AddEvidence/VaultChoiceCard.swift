import SwiftUI

/// A white card with a title, a short explanation and an arrow, such as "Voeg een ervaring toe zonder bestand".
struct VaultChoiceCard: View {
    let title: String
    let message: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .textStyle(.label)
                        .foregroundStyle(Color.ink)
                    Text(message)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(.iconChevronRight)
                    .renderingMode(.template)
                    .foregroundStyle(Color.ink)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color.white, in: .rect(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.railBorder, lineWidth: 1) }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
    }
}

#Preview {
    VaultChoiceCard(title: "Voeg een ervaring toe zonder bestand", message: "Geen document, geen probleem. Je kunt ook zelf ervaringen toevoegen.") {}
        .padding(24)
}
