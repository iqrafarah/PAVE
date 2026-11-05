import SwiftUI

enum PaveTextStyle {
    case title
    case eyebrow
    case lead
    case label
    case input
    case button
    case link
    case calloutTitle
    case footnote
    case caption
    case code
    case tag
    case aylaTitle
    case welcomeTitle
    case chip
    case bubble
    case bodyMedium
    case meta
    case status
    case choice
    case gapChip

    fileprivate var fontName: String {
        switch self {
        case .title, .eyebrow, .label, .button, .calloutTitle, .tag, .aylaTitle, .bubble, .choice, .gapChip: "InterVariable-SemiBold"
        case .link, .bodyMedium, .meta: "InterVariable-Medium"
        case .status: "InterVariable-Bold"
        case .welcomeTitle, .chip: "Sora-Regular_SemiBold"
        case .lead, .input, .footnote, .caption, .code: "InterVariable"
        }
    }

    fileprivate var size: CGFloat {
        switch self {
        case .aylaTitle, .welcomeTitle: 30
        case .choice: 18
        case .bubble: 16
        case .bodyMedium, .status: 14
        case .chip, .meta, .gapChip: 12
        case .title: 28
        case .code: 24
        case .button: 16
        case .lead, .input: 15
        case .label, .link, .calloutTitle: 14
        case .eyebrow, .footnote: 13
        case .caption: 12
        case .tag: 10
        }
    }

    fileprivate var relativeTo: Font.TextStyle {
        switch self {
        case .aylaTitle, .welcomeTitle: .largeTitle
        case .choice: .headline
        case .bubble: .body
        case .bodyMedium, .status: .subheadline
        case .chip, .meta, .gapChip: .caption
        case .title: .title
        case .code: .title2
        case .button: .headline
        case .lead, .input: .body
        case .label, .link, .calloutTitle: .subheadline
        case .eyebrow, .footnote: .footnote
        case .caption: .caption
        case .tag: .caption2
        }
    }

    fileprivate var lineHeight: CGFloat? {
        switch self {
        case .title: 1.25
        case .lead, .footnote, .caption: 1.5
        case .calloutTitle: 1.4
        case .bubble, .bodyMedium: 1.3
        case .welcomeTitle: 1.25
        default: nil
        }
    }

    var font: Font {
        .custom(fontName, size: size, relativeTo: relativeTo)
    }
}

private struct PaveTextStyleModifier: ViewModifier {
    let style: PaveTextStyle
    @ScaledMetric private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .lineSpacing(lineSpacing)
    }

    private var lineSpacing: CGFloat {
        guard let lineHeight = style.lineHeight else { return 0 }
        let naturalLineHeight: CGFloat = 1.21
        return max(0, (lineHeight - naturalLineHeight) * style.size * scale)
    }
}

extension View {
    func textStyle(_ style: PaveTextStyle) -> some View {
        modifier(PaveTextStyleModifier(style: style))
    }
}
