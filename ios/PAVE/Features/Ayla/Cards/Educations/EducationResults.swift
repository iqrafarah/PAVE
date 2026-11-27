import PAVECore
import SwiftUI

/// The studies and courses under Ayla's answer, one card each, with what to check on the school's site.
struct EducationResults: View {
    let educations: [AylaEducation]
    /// Whether the chat belongs to a plan: then a study goes in as a step, otherwise it becomes a plan of its own.
    let hasPlan: Bool
    let isInPlan: (AylaEducation) -> Bool
    let onOpenSite: (AylaEducation) -> Void
    let onPlan: (AylaEducation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(EducationMessages.found(educations.count))
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(educations.enumerated()), id: \.element.id) { index, education in
                EducationCard(
                    education: education,
                    tint: VacancyCard.tints[(index + 1) % VacancyCard.tints.count],
                    isInPlan: isInPlan(education),
                    planAction: hasPlan ? .add : .make,
                    onOpenSite: { onOpenSite(education) },
                    onPlan: { onPlan(education) }
                )
            }
            Text(EducationMessages.checkOnSite)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .padding(.leading, 4)
        }
    }
}
