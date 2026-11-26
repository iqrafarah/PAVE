import PAVECore
import SwiftUI

/// The title of a part of the CV or letter, in the style of the design.
struct CVSectionTitle: View {
    enum Style {
        /// Small capitals with space between the letters and a line under them.
        case caps
        /// A serif title with a short bar of colour under it.
        case serif
        /// White letters on a pill of colour.
        case pill
        /// An icon in a circle of colour before the title.
        case icon(ImageResource)
        /// Small grey capitals, nothing else.
        case quiet
        /// Spaced capitals in the middle, between two thin lines.
        case centered
        /// A slanted bar of colour before bold capitals.
        case slash
    }

    let title: String
    let style: Style
    let theme: ApplicationTheme
    var onDark = false

    var body: some View {
        Group {
            switch style {
            case .caps:
                VStack(alignment: .leading, spacing: 5) {
                    Text(title.uppercased())
                        .font(theme.heading(9.5, .bold))
                        .tracking(1.6)
                        .foregroundStyle(onDark ? .white : theme.accent)
                    Rectangle()
                        .fill((onDark ? Color.white : theme.accent).opacity(0.35))
                        .frame(height: 0.8)
                }
            case .serif:
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(theme.heading(15, .semibold))
                        .foregroundStyle(onDark ? .white : theme.ink)
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: 26, height: 2.5)
                }
            case .pill:
                Text(title)
                    .font(theme.heading(10.5, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(theme.accent, in: .capsule)
            case .icon(let icon):
                HStack(spacing: 9) {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 11, height: 11)
                        .foregroundStyle(onDark ? theme.dark : .white)
                        .frame(width: 22, height: 22)
                        .background(onDark ? Color.white : theme.accent, in: .circle)
                    Text(title.uppercased())
                        .font(theme.heading(10, .bold))
                        .tracking(1.2)
                        .foregroundStyle(onDark ? .white : theme.ink)
                }
            case .quiet:
                Text(title.uppercased())
                    .font(theme.heading(8.5, .semibold))
                    .tracking(2.4)
                    .foregroundStyle(onDark ? .white.opacity(0.7) : theme.muted)
            case .centered:
                HStack(spacing: 12) {
                    line
                    Text(title.uppercased())
                        .font(theme.heading(9.5, .semibold))
                        .tracking(3)
                        .foregroundStyle(onDark ? .white : theme.dark)
                        .fixedSize()
                    line
                }
            case .slash:
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(theme.accent)
                        .frame(width: 5, height: 13)
                        .rotationEffect(.degrees(18))
                    Text(title.uppercased())
                        .font(theme.heading(10.5, .heavy))
                        .tracking(0.8)
                        .foregroundStyle(onDark ? .white : theme.dark)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }

    private var line: some View {
        Rectangle().fill(theme.accent.opacity(0.4)).frame(height: 0.8)
    }
}
