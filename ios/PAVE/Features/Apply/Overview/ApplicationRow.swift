import PAVECore
import SwiftUI

/// One application in the overview: the company, the job, how close the deadline is, whether it was shared and looked
/// at, and when it last changed.
struct ApplicationRow: View {
    let draft: ApplicationDraft
    let action: () -> Void

    @Environment(SharingModel.self) private var sharing: SharingModel?

    private var vacancy: Vacancy { draft.vacancy }
    private var tracking: ApplicationTracking { draft.progress }
    private var distance: ApplicationDeadline? {
        guard tracking.status == .concept, let deadline = tracking.deadline else { return nil }
        return ApplicationDeadline.of(deadline, now: .now)
    }
    private var liveShare: ProfileShare? { sharing?.shares(forVacancy: vacancy.id).first { $0.isLive() } }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                CompanyLogo(
                    name: vacancy.company.hasPrefix("Via ") ? String(vacancy.company.dropFirst(4)) : vacancy.company,
                    url: vacancy.logoUrl,
                    size: 44,
                    city: vacancy.city,
                    looksUp: !vacancy.company.hasPrefix("Via ")
                )
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vacancy.title)
                            .textStyle(.listTitle)
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.leading)
                        Text(vacancy.company)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    FlowLayout(spacing: 6) {
                        ApplicationSourceTag(source: ApplicationSource(vacancy))
                        if let distance {
                            badge(ApplyMessages.deadlineDistance(distance), color: distance.isUrgent ? Color.critical : Color.ink, fill: distance.isUrgent ? Color.criticalSurface : Color.canvas)
                        }
                        if let liveShare {
                            badge(ApplyMessages.sharedLooks(liveShare.looks.count), color: Color.paveAccent, fill: Color.paveSurfaceTint)
                        }
                    }
                    Text(([ApplyMessages.changedOn(draft.updatedAt)] + (tracking.note.isEmpty ? [] : [tracking.note])).joined(separator: " · "))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(.iconChevronRightSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.pave)
        .accessibilityElement(children: .combine)
    }

    private func badge(_ text: String, color: Color, fill: Color) -> some View {
        Text(text)
            .textStyle(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .background(fill, in: .capsule)
            .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: fill == Color.canvas ? 1 : 0) }
            .fixedSize()
    }
}
