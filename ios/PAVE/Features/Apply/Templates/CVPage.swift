import PAVECore
import SwiftUI

/// The CV on one A4 page in the chosen template. The same view is the preview, the thumbnail and the pdf, so what you
/// see is what you send.
struct CVPage: View {
    let draft: ApplicationDraft
    var photo: UIImage?
    var interaction: ApplicationPageInteraction?

    private var cv: CVContent { draft.cv }
    private var accent: Color { ApplicationPage.accent(draft) }
    private var shownPhoto: UIImage? { draft.showsPhoto ? photo : nil }
    private var contact: [String] { [cv.email, cv.phone, cv.city].filter { !$0.isEmpty } }
    private var isCompact: Bool { draft.template == .compact }

    var body: some View {
        Group {
            switch draft.template {
            case .calm, .compact: single
            case .modern: twoColumns
            case .bold: band
            }
        }
        .frame(width: ApplicationPage.size.width, alignment: .topLeading)
        .frame(minHeight: ApplicationPage.size.height, alignment: .top)
        // The side column of Modern runs down the whole page, also below its content.
        .background(alignment: .leading) {
            if draft.template == .modern { accent.opacity(0.08).frame(width: 190) }
        }
        .background(ApplicationPage.paper)
        .environment(\.colorScheme, .light)
    }

    // MARK: Templates

    private var single: some View {
        VStack(alignment: .leading, spacing: isCompact ? 12 : 18) {
            HStack(alignment: .center, spacing: 16) {
                CVPhotoView(photo: shownPhoto, size: isCompact ? 52 : 68)
                VStack(alignment: .leading, spacing: 3) {
                    name(size: isCompact ? 20 : 25, color: ApplicationPage.ink)
                    headline(color: accent)
                    contactLine(color: ApplicationPage.muted)
                }
            }
            .applicationBlock(.personal, interaction, accent: accent)
            Rectangle().fill(accent).frame(height: isCompact ? 1 : 2)
            profile
            sections
            skillsBlock(onDark: false)
        }
        .padding(isCompact ? 34 : ApplicationPage.margin)
    }

    private var twoColumns: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                CVPhotoView(photo: shownPhoto, size: 96)
                if !contact.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        CVHeading(title: ApplyMessages.contactHeading, accent: accent, size: 9.5, showsRule: false)
                        ForEach(contact, id: \.self) { line in
                            Text(line)
                                .font(ApplicationPage.font(8.5))
                                .foregroundStyle(ApplicationPage.ink)
                        }
                    }
                    .applicationBlock(.personal, interaction, accent: accent)
                }
                skillsBlock(onDark: false, showsRule: false)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, ApplicationPage.margin)
            .frame(width: 190, alignment: .leading)
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    name(size: 26, color: ApplicationPage.ink)
                    headline(color: accent)
                }
                .applicationBlock(.personal, interaction, accent: accent)
                profile
                sections
            }
            .padding(.horizontal, 30)
            .padding(.vertical, ApplicationPage.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var band: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    name(size: 27, color: .white)
                    headline(color: .white.opacity(0.85))
                    contactLine(color: .white.opacity(0.8))
                }
                Spacer(minLength: 0)
                CVPhotoView(photo: shownPhoto, size: 86, ring: .white)
            }
            .applicationBlock(.personal, interaction, accent: .white)
            .padding(.horizontal, ApplicationPage.margin)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent)
            VStack(alignment: .leading, spacing: 18) {
                profile
                sections
                skillsBlock(onDark: false)
            }
            .padding(ApplicationPage.margin)
        }
    }

    // MARK: Parts

    private func name(size: CGFloat, color: Color) -> some View {
        // An empty name shows what goes there while editing, and nothing on paper.
        Text(cv.name.isEmpty ? (interaction == nil ? " " : ApplyMessages.name) : cv.name)
            .font(ApplicationPage.font(size, .bold))
            .foregroundStyle(color)
            .opacity(cv.name.isEmpty ? 0.4 : 1)
    }

    @ViewBuilder
    private func headline(color: Color) -> some View {
        if !cv.headline.isEmpty {
            Text(cv.headline)
                .font(ApplicationPage.font(isCompact ? 10 : 11, .medium))
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private func contactLine(color: Color) -> some View {
        if !contact.isEmpty {
            Text(contact.joined(separator: "   "))
                .font(ApplicationPage.font(8.5))
                .foregroundStyle(color)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var profile: some View {
        if !cv.profile.isEmpty || interaction != nil {
            VStack(alignment: .leading, spacing: 8) {
                CVHeading(title: ApplyMessages.profileHeading, accent: accent, size: isCompact ? 9.5 : 10.5)
                Text(cv.profile.isEmpty ? ApplyMessages.aylaProfile : cv.profile)
                    .font(ApplicationPage.font(isCompact ? 9 : 9.5))
                    .foregroundStyle(cv.profile.isEmpty ? ApplicationPage.muted : ApplicationPage.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .applicationBlock(.profile, interaction, accent: accent)
        }
    }

    private var sections: some View {
        ForEach(cv.visibleSections) { section in
            VStack(alignment: .leading, spacing: isCompact ? 6 : 9) {
                CVHeading(title: ApplyMessages.section(section.kind), accent: accent, size: isCompact ? 9.5 : 10.5)
                ForEach(section.entries.filter(\.isVisible)) { entry in
                    CVEntryView(entry: entry, isCompact: isCompact)
                        .applicationBlock(.entry(entry.id), interaction, accent: accent)
                }
            }
        }
    }

    @ViewBuilder
    private func skillsBlock(onDark: Bool, showsRule: Bool = true) -> some View {
        if !cv.skills.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CVHeading(title: ApplyMessages.skillsHeading, accent: accent, size: isCompact ? 9.5 : 10.5, showsRule: showsRule)
                CVSkillsView(skills: cv.skills, accent: accent, onDark: onDark)
            }
            .applicationBlock(.skills, interaction, accent: accent)
        }
    }
}
