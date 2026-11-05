import SwiftUI

struct AylaWelcome: View {
    let firstName: String?
    var isAvailable = true
    let onStarter: (String) -> Void

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
                    starter(.iconFolder, "Kluis", question: "Wat kan ik allemaal in mijn kluis bewaren?")
                    starter(.iconMap, "Plan", question: "Kun je me helpen een ontwikkelplan te maken?")
                    starter(.iconPerson, "Profiel", question: "Hoe maak ik een profiel om met een werkgever te delen?")
                }
            }
        }
        .padding(.horizontal, 32)
    }

    private func starter(_ icon: ImageResource, _ title: String, question: String) -> some View {
        Button {
            onStarter(question)
        } label: {
            HStack(spacing: 8) {
                Image(icon)
                    .accessibilityHidden(true)
                Text(title)
                    .textStyle(.chip)
                    .foregroundStyle(Color.ink)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 43)
            .background(Color.surfaceTint, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityHint(question)
    }
}

#Preview {
    AylaWelcome(firstName: "Daaf") { _ in }
        .frame(maxHeight: .infinity)
        .background(Color.canvas)
}
