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
    case keypad

    fileprivate var fontName: String {
        switch self {
        case .title, .eyebrow, .label, .button, .calloutTitle, .tag: "InterVariable-SemiBold"
        case .link, .keypad: "InterVariable-Medium"
        case .lead, .input, .footnote, .caption, .code: "InterVariable"
        }
    }

    fileprivate var size: CGFloat {
        switch self {
        case .title, .keypad: 28
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
        case .title, .keypad: .title
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
