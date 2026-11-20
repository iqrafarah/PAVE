import PAVECore
import SwiftUI

/// One vacancy, in the panel over the chat: the piece of its text PAVE has, what fits you and what you still miss with
/// the line each comes from, and at the bottom the way to the whole vacancy at the employer. Ayla stays below.
struct VacancyDetail: View {
    let vacancy: Vacancy
    var tint = Color.cardTintRose
    let isSaved: Bool
    let onToggleSave: (() -> Void)?
    let onAsk: (() -> Void)?
    let onAskGap: ((String) -> Void)?

    private var hasMatch: Bool { !vacancy.matches.isEmpty || !vacancy.skillGap.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 14) {
                    VacancyHeader(vacancy: vacancy)
                        .padding(.trailing, 18)
                    VacancyActions(vacancy: vacancy, isSaved: isSaved, onToggleSave: onToggleSave, onAsk: onAsk)
                        .padding(.trailing, 13)
                }
                .padding(.leading, 13)
                .padding(.bottom, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { FigmaCardGradient(tint: tint, start: UnitPoint(x: 0.97, y: 1.08), end: UnitPoint(x: 0.03, y: -0.08)) }
                .clipShape(.rect(cornerRadius: 17))
                .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Color.cardBorder, lineWidth: 1) }

                if let summary = vacancy.summary, !summary.isEmpty {
                    section(AylaMessages.vacancyFromText) {
                        Text(summary)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 9))
                        Text(AylaMessages.vacancyTextNote(vacancy.source))
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !vacancy.matches.isEmpty {
                    section(AylaMessages.vacancyFits) {
                        ForEach(vacancy.matches, id: \.skill) { VacancyRequirementRow(link: $0, isGap: false) }
                    }
                }
                if !vacancy.skillGap.isEmpty {
                    section(AylaMessages.vacancyMissing) {
                        ForEach(vacancy.skillGap, id: \.skill) { link in
                            VacancyRequirementRow(link: link, isGap: true, onAsk: onAskGap.map { ask in { ask(link.skill) } })
                        }
                    }
                }
                Text(hasMatch ? AylaMessages.vacancyMatchNote : AylaMessages.vacancyNoMatch)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if let url = vacancy.url {
                    VStack(spacing: 8) {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Text(AylaMessages.vacancyOpen)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .accessibilityHidden(true)
                            }
                            .textStyle(.button)
                            .foregroundStyle(Color.paveAccent)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.paveSurfaceTint, in: .capsule)
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.pave)
                        .accessibilityHint("Opent de vacature bij de werkgever, buiten PAVE")
                        if let source = AylaMessages.vacancySource(vacancy.source) {
                            Text(source)
                                .textStyle(.caption)
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Color.panel.ignoresSafeArea())
        .navigationTitle(AylaMessages.vacancyTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .textStyle(.label)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

#Preview {
    NavigationStack {
        VacancyDetail(
            vacancy: Vacancy(
                id: "1", title: "Junior IT-consultant", company: "Voorbeeldbedrijf", city: "Eindhoven", employment: .fullTime,
                url: URL(string: "https://www.adzuna.nl"), source: .adzuna,
                summary: "Je werkt in een Scrum-team aan webapps voor klanten. Ervaring met React is een pre.",
                matches: [.init(skill: "React", requirement: "Ervaring met React is een pre")],
                skillGap: [.init(skill: "Scrum-certificaat", requirement: "Je werkt in een Scrum-team")]
            ),
            isSaved: false, onToggleSave: {}, onAsk: {}, onAskGap: { _ in }
        )
    }
}
