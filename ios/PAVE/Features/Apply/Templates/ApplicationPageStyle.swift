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

    static let ink = Color(red: 0.12, green: 0.13, blue: 0.13)
    static let muted = Color(red: 0.38, green: 0.40, blue: 0.40)
    static let paper = Color.white

    static func accent(_ draft: ApplicationDraft) -> Color {
        Color(
            red: Double((draft.accent >> 16) & 0xFF) / 255,
            green: Double((draft.accent >> 8) & 0xFF) / 255,
            blue: Double(draft.accent & 0xFF) / 255
        )
    }
}

/// What the page needs to be edited: which block is chosen, which Ayla writes, and what a tap does. Nil when the page is
/// drawn for the pdf.
struct ApplicationPageInteraction {
    var selection: ApplicationBlock?
    var writing: ApplicationBlock?
    var isWritingLetter = false
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
            return false
        }()
    }

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
                .contentShape(.rect)
                .onTapGesture { interaction.onSelect(block) }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { interaction.onSelect(block) }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .animation(.easeOut(duration: 0.15), value: isSelected)
                .animation(.easeInOut(duration: 0.3), value: isWriting)
        } else {
            content
        }
    }
}
