import PAVECore
import SwiftUI

/// The motivation letter on A4, with the header of the chosen template so it belongs with the CV.
struct LetterPage: View {
    let draft: ApplicationDraft
    var interaction: ApplicationPageInteraction?
    var date = Date.now

    private var accent: Color { ApplicationPage.accent(draft) }
    private var cv: CVContent { draft.cv }
    private var letter: LetterContent { draft.letter }
    private var contact: String { [cv.email, cv.phone, cv.city].filter { !$0.isEmpty }.joined(separator: "   ") }
    private var place: String {
        [draft.vacancy.company, draft.vacancy.city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place)
                        .font(ApplicationPage.font(9.5, .medium))
                    Text(date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "nl_NL"))))
                        .font(ApplicationPage.font(9.5))
                        .foregroundStyle(ApplicationPage.muted)
                }
                .foregroundStyle(ApplicationPage.ink)
                Text("Betreft: sollicitatie \(draft.vacancy.title)")
                    .font(ApplicationPage.font(10, .semibold))
                    .foregroundStyle(ApplicationPage.ink)
                    .padding(.top, 6)
                Text(letter.salutation)
                    .font(ApplicationPage.font(10))
                    .foregroundStyle(ApplicationPage.ink)
                    .applicationBlock(.salutation, interaction, accent: accent)
                // An empty paragraph shows while editing, so it can be tapped; it is left out on paper.
                ForEach(letter.paragraphs.filter { interaction != nil || !$0.text.isEmpty }) { paragraph in
                    Text(paragraph.text.isEmpty ? ApplyMessages.paragraph : paragraph.text)
                        .font(ApplicationPage.font(10))
                        .foregroundStyle(paragraph.text.isEmpty ? ApplicationPage.muted : ApplicationPage.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .applicationBlock(.paragraph(paragraph.id), interaction, accent: accent)
                }
                VStack(alignment: .leading, spacing: 18) {
                    Text(letter.closing)
                    Text(letter.signature.isEmpty ? cv.name : letter.signature)
                        .fontWeight(.semibold)
                }
                .font(ApplicationPage.font(10))
                .foregroundStyle(ApplicationPage.ink)
                .applicationBlock(.closing, interaction, accent: accent)
                .padding(.top, 4)
            }
            .padding(.horizontal, ApplicationPage.margin + (draft.template == .modern ? 6 : 0))
            .padding(.vertical, 28)
        }
        .frame(width: ApplicationPage.size.width, alignment: .topLeading)
        .frame(minHeight: ApplicationPage.size.height, alignment: .top)
        .background(ApplicationPage.paper)
        .overlay(alignment: .leading) {
            if draft.template == .modern { accent.frame(width: 8) }
        }
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private var header: some View {
        let title = VStack(alignment: .leading, spacing: 3) {
            Text(cv.name)
                .font(ApplicationPage.font(draft.template == .compact ? 16 : 19, .bold))
            if !contact.isEmpty {
                Text(contact)
                    .font(ApplicationPage.font(8.5))
                    .opacity(0.8)
            }
        }
        if draft.template == .bold {
            title
                .foregroundStyle(.white)
                .padding(.horizontal, ApplicationPage.margin)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accent)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                title.foregroundStyle(ApplicationPage.ink)
                Rectangle().fill(accent).frame(height: draft.template == .compact ? 1 : 2)
            }
            .padding(.horizontal, ApplicationPage.margin + (draft.template == .modern ? 6 : 0))
            .padding(.top, ApplicationPage.margin)
        }
    }
}
