import PAVECore
import SwiftUI

/// A study or course Ayla found: what, where and how long, a few words from the school's page, the site, and a way
/// into your plan. Built like the vacancy card, so results in a chat look alike.
struct EducationCard: View {
    let education: AylaEducation
    var tint = Color.cardTintGreen
    var isInPlan = false
    var planAction: PlanAction = .add
    let onOpenSite: () -> Void
    let onPlan: () -> Void

    enum PlanAction { case add, make }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                CompanyLogo(name: education.school, url: nil, size: 48, city: education.city, looksUp: true, placeholder: .iconAcademicCapSolid)
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: education.name)
                        .textStyle(.bubble)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: ([education.school] + education.details.map(\.translated)).joined(separator: " · "))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
            if let summary = education.summary, !summary.isEmpty {
                Text(verbatim: summary)
                    .textStyle(.caption)
                    .foregroundStyle(Color.ink)
                    .lineLimit(3)
            }
            // Side by side when they fit; otherwise under each other, and then a label may wrap rather than push the
            // whole chat wider than the screen at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons(fixed: true) }
                VStack(alignment: .leading, spacing: 8) { buttons(fixed: false) }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { FigmaCardGradient(tint: tint, start: UnitPoint(x: 0.97, y: 1.08), end: UnitPoint(x: 0.03, y: -0.08)) }
        .clipShape(.rect(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Color.cardBorder, lineWidth: 1) }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func buttons(fixed: Bool) -> some View {
        PaveChip(icon: .iconGlobeEuropeAfricaSolid, title: EducationMessages.openSite, action: onOpenSite)
            .fixedSize(horizontal: fixed, vertical: true)
            .accessibilityHint(EducationMessages.openSiteHint)
        if isInPlan {
            HStack(spacing: 6) {
                Image(.iconCheckCircleSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconHeight(18)
                    .foregroundStyle(Color.paveAccent)
                    .accessibilityHidden(true)
                Text(EducationMessages.inPlan)
                    .textStyle(.chip)
                    .foregroundStyle(Color.ink)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 43)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            PaveChip(icon: planAction == .add ? .iconPlusCircleSolid : .iconMapSolid, title: planAction == .add ? EducationMessages.addToPlan : EducationMessages.makePlan, action: onPlan)
                .fixedSize(horizontal: fixed, vertical: true)
                .accessibilityHint(planAction == .add ? EducationMessages.addToPlanHint : EducationMessages.makePlanHint)
        }
    }
}

#Preview {
    EducationCard(
        education: AylaEducation(id: "1", name: "Pilotenopleiding", school: "Voorbeeld Vliegschool", level: .hbo, city: "Groningen", duration: "4 jaar", url: URL(string: "https://example.nl")!, summary: "Je leert in vier jaar vliegen op een verkeersvliegtuig."),
        onOpenSite: {}, onPlan: {}
    )
    .padding(25)
}
