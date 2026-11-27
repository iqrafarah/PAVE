import PAVECore
import SwiftUI

/// On the empty chat: an application whose deadline is close, to go on with it.
struct AylaDeadlineCard: View {
    let draft: ApplicationDraft
    let action: () -> Void

    private var distance: ApplicationDeadline? { draft.progress.deadline.map { ApplicationDeadline.of($0, now: .now) } }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(.iconBriefcaseSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(18)
                    .foregroundStyle(Color.paveAccent)
                    .frame(width: 40, height: 40)
                    .background(Color.paveSurfaceTint, in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(distance.map(ApplyMessages.deadlineCard) ?? "")
                        .textStyle(.chip)
                        .foregroundStyle(Color.ink)
                    Text("\(draft.vacancy.title) bij \(draft.vacancy.company)")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(.iconChevronDown)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconHeight(6)
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(Color.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: 340)
            .background(Color.panel, in: .rect(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1) }
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.pave)
        .accessibilityHint(ApplyMessages.openApplicationHint)
    }
}
