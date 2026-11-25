import PAVECore
import SwiftUI

/// The motivation letter with the letterhead of the chosen design, so it belongs with the CV, as one long sheet;
/// `ApplicationPages` cuts it into A4 pages.
struct LetterPage: View {
    let draft: ApplicationDraft
    var interaction: ApplicationPageInteraction?
    var date = Date.now

    private var theme: ApplicationTheme { ApplicationTheme(draft) }
    private var cv: CVContent { draft.cv }
    private var letter: LetterContent { draft.letter }
    private var place: String {
        [draft.vacancy.company, draft.vacancy.city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
    /// Room on the left for the band of Salie and the line of Lijn.
    private var leading: CGFloat {
        switch draft.template {
        case .sage: 66
        case .line: 70
        case .frame, .halo: 64
        default: 52
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            letterhead
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place)
                        .font(theme.body(9.5, .semibold))
                    Text(date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "nl_NL"))))
                        .font(theme.body(9.5))
                        .foregroundStyle(theme.muted)
                }
                .foregroundStyle(theme.ink)
                Text(ApplyMessages.letterSubject(draft.vacancy))
                    .font(theme.heading(11, .semibold))
                    .foregroundStyle(draft.template == .frame ? theme.ink : theme.accent)
                    .padding(.top, 8)
                Text(letter.salutation)
                    .font(theme.body(10))
                    .foregroundStyle(theme.ink)
                    .applicationBlock(.salutation, interaction, accent: theme.accent)
                // An empty paragraph shows its hint while editing, so it can be tapped; it is left out on paper.
                ForEach(Array(letter.paragraphs.enumerated()).filter { interaction != nil || !$0.element.text.isEmpty }, id: \.element.id) { index, paragraph in
                    Text(paragraph.text.isEmpty ? ApplyMessages.paragraphHint(index) : paragraph.text)
                        .font(theme.body(10))
                        .italic(paragraph.text.isEmpty)
                        .foregroundStyle(paragraph.text.isEmpty ? theme.muted : theme.ink)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .applicationBlock(.paragraph(paragraph.id), interaction, accent: theme.accent)
                }
                VStack(alignment: .leading, spacing: 20) {
                    Text(letter.closing)
                        .font(theme.body(10))
                    Text(letter.signature.isEmpty ? cv.name : letter.signature)
                        .font(draft.template == .sage || draft.template == .frame ? theme.display(15, .regular) : theme.body(10.5, .semibold))
                }
                .foregroundStyle(theme.ink)
                .applicationBlock(.closing, interaction, accent: theme.accent)
                .padding(.top, 6)
            }
            .padding(.leading, leading)
            .padding(.trailing, 56)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pageRegion()
        }
    }

    static let blockHeaderHeight: CGFloat = 96

    @ViewBuilder
    private var letterhead: some View {
        let name = cv.name.isEmpty ? " " : cv.name
        switch draft.template {
        case .night, .column:
            VStack(alignment: .leading, spacing: 8) {
                Text(draft.template == .column ? name.uppercased() : name)
                    .font(theme.display(draft.template == .column ? 22 : 24, draft.template == .column ? .black : .heavy))
                    .tracking(draft.template == .column ? 2 : 0)
                    .foregroundStyle(.white)
                CVContactList(cv: cv, theme: theme, isRow: true, onDark: true, iconColor: theme.accent)
            }
            .padding(.horizontal, 52)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.dark)
            .overlay(alignment: .bottom) { theme.accent.frame(height: 4) }
        case .frame:
            VStack(spacing: 8) {
                Text(name)
                    .font(theme.display(28, .regular))
                    .tracking(0.6)
                CVContactList(cv: cv, theme: theme, isRow: true, iconColor: theme.muted)
                Rectangle().fill(theme.ink.opacity(0.85)).frame(height: 0.6).padding(.top, 12)
            }
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 64)
            .padding(.top, 54)
        case .coral:
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(theme.display(28, .heavy))
                        .foregroundStyle(theme.dark)
                    CVContactList(cv: cv, theme: theme, isRow: true)
                }
                Spacer()
            }
            .padding(.horizontal, 52)
            .padding(.top, 54)
            .background(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(theme.tint).frame(width: 220, height: 220).offset(x: 90, y: -110)
                    Circle().fill(theme.accent.opacity(0.85)).frame(width: 80, height: 80).offset(x: 10, y: 10)
                }
            }
        case .plain:
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(theme.display(24, .bold))
                    .foregroundStyle(theme.ink)
                CVContactList(cv: cv, theme: theme, isRow: true, iconColor: theme.muted)
                Rectangle().fill(theme.ink).frame(height: 1.2).padding(.top, 12)
            }
            .padding(.horizontal, 52)
            .padding(.top, 54)
        case .block:
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(theme.display(24, .heavy))
                    .foregroundStyle(.white)
                CVContactList(cv: cv, theme: theme, isRow: true, onDark: true)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .frame(height: Self.blockHeaderHeight)
            .background(theme.accent, in: .rect(cornerRadius: 18))
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 14)
        case .halo:
            VStack(spacing: 8) {
                ZStack {
                    Circle().strokeBorder(theme.accent.opacity(0.15), lineWidth: 1).frame(width: 64, height: 64)
                    Circle().strokeBorder(theme.accent.opacity(0.3), lineWidth: 1).frame(width: 46, height: 46)
                    Circle().fill(.white).frame(width: 28, height: 28)
                    Circle().strokeBorder(theme.accent.opacity(0.7), lineWidth: 1.5).frame(width: 28, height: 28)
                    Circle().fill(theme.accent).frame(width: 7, height: 7)
                }
                .accessibilityHidden(true)
                Text(name.uppercased())
                    .font(theme.display(20, .light))
                    .tracking(4.5)
                    .foregroundStyle(theme.dark)
                CVContactList(cv: cv, theme: theme, isRow: true)
                HStack(spacing: 6) {
                    Rectangle().fill(theme.accent.opacity(0.4)).frame(width: 40, height: 0.8)
                    Circle().fill(theme.accent).frame(width: 4, height: 4)
                    Rectangle().fill(theme.accent.opacity(0.4)).frame(width: 40, height: 0.8)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 30)
            .background(alignment: .top) { theme.tint.frame(height: 76) }
        case .tilt:
            ZStack(alignment: .topLeading) {
                CVTiltBand(theme: theme, height: 120)
                VStack(alignment: .leading, spacing: 8) {
                    Text(name.uppercased())
                        .font(theme.display(24, .black))
                        .tracking(1)
                        .foregroundStyle(.white)
                    CVContactList(cv: cv, theme: theme, isRow: true, onDark: true, iconColor: theme.tint)
                }
                .padding(.horizontal, 52)
                .padding(.top, 36)
            }
            .frame(height: 128, alignment: .top)
        case .sage, .line:
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(theme.display(26, draft.template == .sage ? .regular : .bold))
                    .foregroundStyle(theme.ink)
                CVContactList(cv: cv, theme: theme, isRow: true)
                Capsule().fill(theme.accent).frame(width: 36, height: 2.5).padding(.top, 8)
            }
            .padding(.leading, leading)
            .padding(.trailing, 56)
            .padding(.top, 54)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
