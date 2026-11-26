import PAVECore
import SwiftUI

/// Mijn sollicitatie › Tijdlijn: what is ahead (the talk, the deadline) and what happened (shared, who looked, the
/// invitation, the status you set), on one line down the card, so you feel the application move.
struct ApplicationTimelineView: View {
    let events: [ApplicationTimelineEvent]

    @State private var showsAll = false
    private static let shortCount = 5

    private var shown: [ApplicationTimelineEvent] { showsAll ? events : Array(events.prefix(Self.shortCount)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ApplyMessages.timeline)
                .textStyle(.label)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, event in
                    row(event, isLast: index == shown.count - 1)
                }
                if events.count > Self.shortCount {
                    Button(showsAll ? ApplyMessages.showLess : ApplyMessages.timelineAll(events.count)) {
                        withAnimation(.snappy(duration: 0.25)) { showsAll.toggle() }
                    }
                    .textStyle(.chip)
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
                    .padding(.leading, 44)
                    .buttonStyle(.pave)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
        }
    }

    private func row(_ event: ApplicationTimelineEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(Self.icon(event.kind))
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(14)
                    .foregroundStyle(event.isAhead ? Color.white : Color.paveAccent)
                    .frame(width: 30, height: 30)
                    .background(event.isAhead ? Color.paveAccentFill : Color.paveSurfaceTint, in: .circle)
                if !isLast {
                    Rectangle()
                        .fill(Color.cardBorder)
                        .frame(width: 2)
                        .frame(minHeight: 14, maxHeight: .infinity)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if event.isAhead {
                    Text(ApplyMessages.timelineAhead)
                        .textStyle(.caption)
                        .foregroundStyle(Color.paveAccent)
                }
                Text(ApplyMessages.timelineLine(event.kind))
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(ApplyMessages.timelineDate(event.date, isAhead: event.isAhead))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.bottom, isLast ? 0 : 14)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private static func icon(_ kind: ApplicationTimelineEvent.Kind) -> ImageResource {
        switch kind {
        case .status: .iconCheckBadgeSolid
        case .shared: .iconArrowUpTraySolid
        case .looked: .iconEyeSolid
        case .stoppedSharing: .iconXMark
        case .invited: .iconCalendarDaysSolid
        case .talk: .iconChatBubbleLeftEllipsisSolid
        case .deadline: .iconClockSolid
        }
    }
}

#Preview {
    let now = Date.now
    ApplicationTimelineView(events: [
        .init(id: "t", date: now.addingTimeInterval(2 * 86_400), kind: .talk, isAhead: true),
        .init(id: "l", date: now.addingTimeInterval(-3600), kind: .looked(by: "Sanne de Vries", downloaded: false)),
        .init(id: "s", date: now.addingTimeInterval(-7200), kind: .shared(recipient: "Sanne de Vries, Jumbo")),
        .init(id: "v", date: now.addingTimeInterval(-86_400), kind: .status(.sent)),
    ])
    .padding()
    .background(Color.canvas)
}
