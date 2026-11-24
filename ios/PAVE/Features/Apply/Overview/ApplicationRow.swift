import PAVECore
import SwiftUI

/// One application in the overview: the job, where it stands, how close the deadline is and when it last changed.
struct ApplicationRow: View {
    let draft: ApplicationDraft
    let action: () -> Void

    private var tracking: ApplicationTracking { draft.progress }
    private var distance: ApplicationDeadline? {
        guard tracking.status == .concept, let deadline = tracking.deadline else { return nil }
        return ApplicationDeadline.of(deadline, now: .now)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.vacancy.title)
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                    Text(draft.vacancy.company)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                // The status is in the heading of the group; what is left is the deadline and when it last changed.
                if let distance {
                    badge(ApplyMessages.deadlineDistance(distance), color: distance.isUrgent ? Color.critical : Color.ink, fill: distance.isUrgent ? Color.criticalSurface : Color.canvas)
                }
                Text(([ApplyMessages.changedOn(draft.updatedAt)] + (tracking.note.isEmpty ? [] : [tracking.note])).joined(separator: " · "))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1) }
            .contentShape(.rect(cornerRadius: 18))
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
