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
    case tileTitle
    case tileCount
    case listTitle
    case menuItem
    case railLabel
    case emptyTitle
    case action

    fileprivate var fontName: String {
        switch self {
        case .title, .eyebrow, .label, .button, .calloutTitle, .tag, .aylaTitle, .bubble, .choice, .gapChip, .listTitle: "InterVariable-SemiBold"
        case .link, .bodyMedium, .meta, .tileTitle, .tileCount, .menuItem, .railLabel: "InterVariable-Medium"
        case .status: "InterVariable-Bold"
        case .welcomeTitle, .chip, .emptyTitle, .action: "Sora-Regular_SemiBold"
        case .lead, .input, .footnote, .caption, .code: "InterVariable"
        }
    }

    fileprivate var size: CGFloat {
        switch self {
        case .aylaTitle, .welcomeTitle: 30
        case .choice: 18
        case .emptyTitle: 20
        case .bubble, .listTitle, .menuItem, .action: 16
        case .railLabel: 11
        case .tileTitle: 15
        case .bodyMedium, .status, .tileCount: 14
        case .chip, .meta, .gapChip: 12
        case .title: 28
        case .code: 24
        case .button: 16
        case .lead, .input: 15
        case .label, .link, .calloutTitle: 14
        case .eyebrow, .footnote: 13
        case .caption: 12
        case .tag: 11
        }
    }

    fileprivate var relativeTo: Font.TextStyle {
        switch self {
        case .aylaTitle, .welcomeTitle: .largeTitle
        case .choice, .emptyTitle: .headline
        case .bubble, .listTitle, .menuItem, .action: .body
        case .railLabel: .caption2
        case .bodyMedium, .status, .tileTitle, .tileCount: .subheadline
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
        default: nil
        }
    }

    /// How heavy the style is, read from PAVE's own font, for the other typefaces.
    fileprivate var weight: Font.Weight {
        if fontName.hasSuffix("SemiBold") { return .semibold }
        if fontName.hasSuffix("Bold") { return .bold }
        if fontName.hasSuffix("Medium") { return .medium }
        return .regular
    }

    var font: Font { font(scale: 1) }

    /// In the chosen typeface. Apple's typefaces have no name to scale by, so they take `scale`: how much bigger the
    /// text is than standard, from the text size of the device and of PAVE.
    fileprivate func font(scale: CGFloat) -> Font {
        switch PaveFontStore.shared.style {
        case .pave: .custom(fontName, size: size, relativeTo: relativeTo)
        case .system: .system(size: size * scale, weight: weight)
        case .rounded: .system(size: size * scale, weight: weight, design: .rounded)
        case .serif: .system(size: size * scale, weight: weight, design: .serif)
        case .readable:
            .custom(weight == .semibold || weight == .bold ? PaveFontStyle.readableBold : PaveFontStyle.readableRegular, size: size, relativeTo: relativeTo)
        }
    }
}

private struct PaveTextStyleModifier: ViewModifier {
    let style: PaveTextStyle
    @ScaledMetric private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .font(style.font(scale: scale))
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
