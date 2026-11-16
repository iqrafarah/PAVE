import PAVECore
import SwiftUI

/// What the panel over the chat shows for Kluis, Plan or Profiel: a title, that you can keep asking Ayla about it, and
/// the place itself.
struct AylaShelfContent: View {
    let shelf: AylaShelf
    let onAsk: (VaultItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(shelf.title)
                    .textStyle(.emptyTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(shelf.hint)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.top, 4)

            switch shelf {
            case .vault:
                AylaVaultShelf(onAsk: onAsk)
            case .plan:
                PaveEmptyState(
                    icon: .iconMap,
                    title: "Je hebt nog geen plan",
                    message: "Hier komen straks je doelen, wat je al kunt en je volgende stappen te staan."
                )
                .padding(.vertical, 24)
            case .profile:
                PaveEmptyState(
                    icon: .iconPerson,
                    title: "Je hebt nog geen profiel",
                    message: "Hier stel je straks een profiel samen om te delen, bijvoorbeeld voor een sollicitatie. Jij kiest wat erin staat en met wie je het deelt."
                )
                .padding(.vertical, 24)
            }
        }
        .frame(maxWidth: 600, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}
