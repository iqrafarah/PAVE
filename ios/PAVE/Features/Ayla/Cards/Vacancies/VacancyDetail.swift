import PAVECore
import SwiftUI

/// One vacancy, in the panel over the chat. First what you want to know (does it fit, what do you miss, each with the
/// line it comes from), then the piece of its text PAVE has, and last the way to the whole vacancy at the employer.
/// Ayla stays below.
struct VacancyDetail: View {
    let vacancy: Vacancy
    var tint = Color.cardTintRose
    let isSaved: Bool
    let onToggleSave: (() -> Void)?
    let onAsk: (() -> Void)?
    let onAskGap: ((String) -> Void)?

    private var hasFit: Bool { !vacancy.matches.isEmpty || !vacancy.skillGap.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    VacancyHeader(vacancy: vacancy, showsPosted: true)
                        .padding(.trailing, onToggleSave == nil ? 18 : 40)
                    if let onAsk {
                        VacancyAskButton(action: onAsk)
                    }
                }
                .padding(.leading, 13)
                .padding(.bottom, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { FigmaCardGradient(tint: tint, start: UnitPoint(x: 0.97, y: 1.08), end: UnitPoint(x: 0.03, y: -0.08)) }
                .clipShape(.rect(cornerRadius: 17))
                .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Color.cardBorder, lineWidth: 1) }
                .overlay(alignment: .topTrailing) {
                    if let onToggleSave {
                        VacancySaveButton(isSaved: isSaved, action: onToggleSave)
                            .padding(.top, 6)
                            .padding(.trailing, 6)
                    }
                }

                if !vacancy.matches.isEmpty {
                    section(AylaMessages.vacancyFits) { VacancyFitGroup(links: vacancy.matches, isGap: false) }
                }
                if !vacancy.skillGap.isEmpty {
                    section(AylaMessages.vacancyMissing) { VacancyFitGroup(links: vacancy.skillGap, isGap: true, onAsk: onAskGap) }
                }
                if !hasFit {
                    Text(AylaMessages.vacancyNoMatch)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let summary = vacancy.summary, !summary.isEmpty {
                    section(AylaMessages.vacancyFromText) {
                        // A quote, not a box: a line of the theme colour beside the employer's own words.
                        Text(summary)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color.paveAccent.opacity(0.45)).frame(width: 3)
                            }
                    }
                }

                VStack(spacing: 12) {
                    if let url = vacancy.url {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Text(AylaMessages.vacancyOpen)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .accessibilityHidden(true)
                            }
                            .textStyle(.button)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, minHeight: 53)
                            .background(Color.paveAccentFill, in: .capsule)
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.pave)
                        .accessibilityHint("Opent de vacature bij de werkgever, buiten PAVE")
                    }
                    Text([AylaMessages.vacancySource(vacancy.source), hasFit ? AylaMessages.vacancyMatchNote : AylaMessages.vacancyTextNote(vacancy.source)].compactMap(\.self).joined(separator: ". "))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
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
        VStack(alignment: .leading, spacing: 10) {
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
