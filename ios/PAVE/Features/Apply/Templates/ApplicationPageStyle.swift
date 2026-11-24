import PAVECore
import SwiftUI

/// The fixed look of a page on paper: A4 in points, the type in fixed sizes (a page does not follow Dynamic Type), and
/// the colour the user picked.
enum ApplicationPage {
    static let size = CGSize(width: 595, height: 842)
    static let margin: CGFloat = 44

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("InterVariable", fixedSize: size).weight(weight)
    }

    /// The white kept free at the top of a following page and at the bottom of every page, per design.
    static func margins(_ template: ApplicationTemplate, _ document: ApplicationDocumentKind) -> (top: CGFloat, bottom: CGFloat) {
        if document == .letter { return template == .block ? (46, 46) : (54, 48) }
        return switch template {
        case .plain: (52, 44)
        case .frame: (56, 56)
        case .line: (50, 50)
        case .sage: (54, 44)
        case .night: (48, 44)
        case .block: (28, 28)
        case .coral: (52, 44)
        case .column, .halo, .tilt: (44, 44)
        }
    }

    static let ink = Color(red: 0.12, green: 0.13, blue: 0.13)
    static let muted = Color(red: 0.40, green: 0.42, blue: 0.42)
    static let paper = Color.white
}

/// The look of one design: its typefaces and the colours of its palette. Serif for the elegant ones, rounded for the
/// playful one, monospace for dates on the timeline, Inter (PAVE's own) for the rest.
struct ApplicationTheme {
    let template: ApplicationTemplate
    let palette: ApplicationPalette

    init(_ draft: ApplicationDraft) {
        template = draft.template
        palette = draft.palette
    }

    var accent: Color { Self.color(palette.accent) }
    var tint: Color { Self.color(palette.tint) }
    var dark: Color { Self.color(palette.dark) }
    var ink: Color { ApplicationPage.ink }
    var muted: Color { ApplicationPage.muted }

    /// The name and big titles.
    func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        switch template {
        case .sage, .frame: .system(size: size, weight: weight, design: .serif)
        case .coral: .system(size: size, weight: weight, design: .rounded)
        default: ApplicationPage.font(size, weight)
        }
    }

    /// The titles of the parts.
    func heading(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        switch template {
        case .sage: .system(size: size, weight: weight, design: .serif)
        case .coral: .system(size: size, weight: weight, design: .rounded)
        default: ApplicationPage.font(size, weight)
        }
    }

    func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { ApplicationPage.font(size, weight) }

    func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .monospaced) }

    static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// What the page needs to be edited: which block is chosen, which Ayla writes, and what a tap does. Nil when the page is
/// drawn for the pdf.
struct ApplicationPageInteraction {
    var selection: ApplicationBlock?
    var writing: ApplicationBlock?
    var isWritingLetter = false
    var writingEntries: Set<String> = []
    var onSelect: (ApplicationBlock) -> Void
}

extension View {
    /// A block that can be tapped: an outline in the page's colour when it is chosen, and faded while Ayla writes it.
    func applicationBlock(_ block: ApplicationBlock, _ interaction: ApplicationPageInteraction?, accent: Color) -> some View {
        modifier(ApplicationBlockFrame(block: block, interaction: interaction, accent: accent))
    }
}

private struct ApplicationBlockFrame: ViewModifier {
    let block: ApplicationBlock
    let interaction: ApplicationPageInteraction?
    let accent: Color

    private var isSelected: Bool { interaction?.selection == block }
    private var isWriting: Bool {
        interaction?.writing == block || (interaction?.isWritingLetter == true && [.salutation, .closing].contains(block)) || {
            if case .paragraph = block { return interaction?.isWritingLetter == true }
            if case .entry(let id) = block { return interaction?.writingEntries.contains(id) == true }
            return false
        }()
    }

    /// A block stays whole when the document is cut into pages. The tap itself is handled by the pages, which know
    /// where the block ended up.
    func body(content: Content) -> some View {
        if let interaction {
            content
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accent.opacity(isSelected ? 0.06 : 0))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(accent, lineWidth: isSelected ? 1.2 : 0)
                }
                .opacity(isWriting ? 0.35 : 1)
                .padding(-4)
                .pageMark(.block(keepsWithNext: false))
                .pageMark(.tap(block))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { interaction.onSelect(block) }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .animation(.easeOut(duration: 0.15), value: isSelected)
                .animation(.easeInOut(duration: 0.3), value: isWriting)
        } else {
            content
                .pageMark(.block(keepsWithNext: false))
        }
    }
}
