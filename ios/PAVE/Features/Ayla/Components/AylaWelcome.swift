import SwiftUI

/// The empty chat: greeting (typed out), explanation and three starters.
struct AylaWelcome: View {
    let firstName: String?
    var isAvailable = true
    /// The title types itself out once this is true.
    var isTyping = true
    let onStarter: (String) -> Void

    private struct Starter {
        let icon: ImageResource
        let title: String
        let question: String
        let width: CGFloat
    }

    private static let starters = [
        Starter(icon: .iconFolder, title: "Kluis", question: "Wat kan ik allemaal in mijn kluis bewaren?", width: 96),
        Starter(icon: .iconMap, title: "Plan", question: "Kun je me helpen een ontwikkelplan te maken?", width: 93),
        Starter(icon: .iconPerson, title: "Profiel", question: "Hoe maak ik een profiel om met een werkgever te delen?", width: 99),
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
                    ForEach(Self.starters, id: \.title) { starter in
                        PaveChip(icon: starter.icon, title: starter.title, width: starter.width) { onStarter(starter.question) }
                            .accessibilityHint(starter.question)
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
