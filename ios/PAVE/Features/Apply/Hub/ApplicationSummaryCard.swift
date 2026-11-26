import PAVECore
import SwiftUI

/// The top of Mijn sollicitatie: the company's logo, the job, and at a glance where it stands, how long until the
/// deadline and whether what you shared was looked at.
struct ApplicationSummaryCard: View {
    let draft: ApplicationDraft
    var shares: [ProfileShare] = []

    private var vacancy: Vacancy { draft.vacancy }
    private var tracking: ApplicationTracking { draft.progress }
    private var distance: ApplicationDeadline? {
        guard tracking.status == .concept, let deadline = tracking.deadline else { return nil }
        return ApplicationDeadline.of(deadline, now: .now)
    }
    private var liveShare: ProfileShare? { shares.first { $0.isLive() } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                CompanyLogo(
                    name: vacancy.company.hasPrefix("Via ") ? String(vacancy.company.dropFirst(4)) : vacancy.company,
                    url: vacancy.logoUrl,
                    size: 52,
                    city: vacancy.city,
                    looksUp: !vacancy.company.hasPrefix("Via ")
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(vacancy.title)
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text([vacancy.company, vacancy.city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
            }
            FlowLayout(spacing: 8) {
                ApplicationStatusBadge(status: tracking.status)
                if let distance {
                    pill(ApplyMessages.deadlineDistance(distance), ink: distance.isUrgent ? Color.critical : Color.ink, fill: distance.isUrgent ? Color.criticalSurface : Color.canvas)
                }
                if let liveShare {
                    pill(ApplyMessages.sharedLooks(liveShare.looks.count), ink: Color.paveAccent, fill: Color.paveSurfaceTint)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    private func pill(_ text: String, ink: Color, fill: Color) -> some View {
        Text(text)
            .textStyle(.caption)
            .foregroundStyle(ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 26)
            .background(fill, in: .capsule)
            .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: fill == Color.canvas ? 1 : 0) }
            .fixedSize()
    }
}
