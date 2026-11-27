import SwiftUI

/// The skills: pills in the design's colour, white pills on a soft surface, or a quiet list.
struct CVSkillsView: View {
    enum Style { case pills, soft, outline, list }

    let skills: [String]
    let style: Style
    let theme: ApplicationTheme
    var onDark = false

    var body: some View {
        if style == .list {
            Text(skills.joined(separator: "  ·  "))
                .font(theme.body(9))
                .foregroundStyle(onDark ? .white : theme.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            FlowLayout(spacing: 5) {
                ForEach(skills, id: \.self) { skill in
                    Text(skill)
                        .font(theme.body(8.5, .medium))
                        .foregroundStyle(foreground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(background, in: .capsule)
                        .overlay { Capsule().strokeBorder(style == .outline ? theme.accent.opacity(0.5) : .clear, lineWidth: 0.8) }
                }
            }
        }
    }

    private var foreground: Color {
        if onDark { return .white }
        return style == .soft ? theme.ink : theme.accent
    }

    private var background: Color {
        if onDark { return .white.opacity(0.14) }
        switch style {
        case .pills: return theme.tint
        case .soft: return .white
        default: return .clear
        }
    }
}
