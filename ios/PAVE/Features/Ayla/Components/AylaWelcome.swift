import SwiftUI

struct AylaWelcome: View {
    let firstName: String?
    var isAvailable = true
    let onStarter: (String) -> Void

    private struct Starter {
        let icon: ImageResource
        let title: String
        let question: String
    }

    private static let starters = [
        Starter(icon: .iconFolder, title: "Kluis", question: "Wat kan ik allemaal in mijn kluis bewaren?"),
        Starter(icon: .iconMap, title: "Plan", question: "Kun je me helpen een ontwikkelplan te maken?"),
        Starter(icon: .iconPerson, title: "Profiel", question: "Hoe maak ik een profiel om met een werkgever te delen?"),
    ]

    private var title: String {
        if let firstName { "Wat wil je vandaag doen, \(firstName)" } else { "Wat wil je vandaag doen?" }
    }

    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 30) {
                HStack(alignment: .top, spacing: 12) {
                    AylaMark(count: 5, size: 6)
                        .padding(.top, 2)
                    Text(title)
                        .textStyle(.welcomeTitle)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                Text(isAvailable ? "Ontdek kansen, krijg persoonlijk advies en werk met AI direct in jouw PAVE-omgeving. Van je kluis en ontwikkelplan tot vacatures en sollicitaties." : AylaMessages.notAvailableInDemo)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isAvailable {
                HStack(spacing: 15) {
                    ForEach(Self.starters, id: \.title) { starter in
                        PaveChip(icon: starter.icon, title: starter.title) { onStarter(starter.question) }
                            .accessibilityHint(starter.question)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    AylaWelcome(firstName: "Daaf") { _ in }
        .frame(maxHeight: .infinity)
        .background(Color.canvas)
}
