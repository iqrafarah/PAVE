import SwiftUI

/// The empty chat: greeting (typed out), explanation and three chips. A chip opens Kluis, Plan or Profiel over the
/// chat, like on the web, so you can look at it and keep asking Ayla about it.
struct AylaWelcome: View {
    let firstName: String?
    var isAvailable = true
    /// The title types itself out once this is true.
    var isTyping = true
    let onStarter: (AylaShelf) -> Void

    private struct Starter {
        let icon: ImageResource
        let shelf: AylaShelf
        let width: CGFloat
    }

    private static let starters = [
        Starter(icon: .iconFolder, shelf: .vault, width: 96),
        Starter(icon: .iconMap, shelf: .plan, width: 93),
        Starter(icon: .iconPerson, shelf: .profile, width: 99),
    ]

    private var title: String {
        if let firstName { "Wat wil je vandaag doen, \(firstName)" } else { "Wat wil je vandaag doen?" }
    }

    var body: some View {
        VStack(spacing: 0) {
            AylaTypingTitle(text: title, isTyping: isTyping)

            MaxWidthLayout(maxWidth: 313) {
                Text(isAvailable ? "Ontdek kansen, krijg persoonlijk advies en werk met AI direct in jouw PAVE-omgeving. Van je kluis en ontwikkelplan tot vacatures en sollicitaties." : AylaMessages.notAvailableInDemo)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)

            if isAvailable {
                HStack(spacing: 14.5) {
                    ForEach(Self.starters, id: \.shelf) { starter in
                        PaveChip(icon: starter.icon, title: starter.shelf.title, width: starter.width) { onStarter(starter.shelf) }
                            .accessibilityHint("Opent \(starter.shelf.title.lowercased()) boven het gesprek")
                    }
                }
                .padding(.top, 26)
            }
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    AylaWelcome(firstName: "Daaf") { _ in }
        .frame(maxHeight: .infinity)
        .background(Color.canvas)
}
