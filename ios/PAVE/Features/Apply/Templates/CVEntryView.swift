import PAVECore
import SwiftUI

/// One line of experience or education, laid out in the style of the design.
struct CVEntryView: View {
    enum Style {
        /// The dates at the right of the title.
        case dateRight
        /// The dates in a narrow column on the left.
        case dateLeft
        /// A dot on a line down the page, the dates above the title.
        case timeline
        /// The dates under the title, for a narrow column.
        case stacked
    }

    let entry: CVEntry
    let style: Style
    let theme: ApplicationTheme
    var isLast = false

    var body: some View {
        switch style {
        case .dateRight:
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer(minLength: 8)
                    date(theme.body(8.5, .medium), color: theme.accent)
                }
                details
            }
        case .dateLeft:
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                date(theme.body(8.5, .medium), color: theme.muted)
                    .frame(width: 84, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    title
                    details
                }
            }
        case .stacked:
            VStack(alignment: .leading, spacing: 2) {
                title
                date(theme.body(8.5, .semibold), color: theme.accent)
                details
            }
        case .timeline:
            VStack(alignment: .leading, spacing: 2) {
                date(theme.mono(8), color: theme.accent)
                title
                details
            }
            .padding(.leading, 24)
            .padding(.bottom, isLast ? 0 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            // The line runs as long as the entry is, down to the next dot.
            .background(alignment: .topLeading) {
                ZStack(alignment: .top) {
                    if !isLast {
                        Rectangle()
                            .fill(theme.accent.opacity(0.25))
                            .frame(width: 1.5)
                            .frame(maxHeight: .infinity)
                            .padding(.top, 6)
                    }
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 9, height: 9)
                        .overlay { Circle().stroke(theme.tint, lineWidth: 3) }
                        .padding(.top, 2)
                }
                .frame(width: 12)
            }
        }
    }

    private var title: some View {
        Text(entry.title)
            .font(theme.body(10, .semibold))
            .foregroundStyle(theme.ink)
    }

    @ViewBuilder
    private func date(_ font: Font, color: Color) -> some View {
        if !entry.period.isEmpty {
            Text(entry.period)
                .font(font)
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private var details: some View {
        if !entry.organisation.isEmpty {
            Text(entry.organisation)
                .font(theme.body(9, .medium))
                .foregroundStyle(theme.muted)
        }
        if !entry.description.isEmpty {
            Text(entry.description)
                .font(theme.body(9))
                .foregroundStyle(theme.ink)
                .lineSpacing(1.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }
}
