import PAVECore
import SwiftUI

/// The profile at the top of the CV; while editing an empty one says what goes there.
struct CVProfileBlock: View {
    let cv: CVContent
    let theme: ApplicationTheme
    let titleStyle: CVSectionTitle.Style
    var interaction: ApplicationPageInteraction?
    var showsTitle = true

    var body: some View {
        if !cv.profile.isEmpty || interaction != nil {
            VStack(alignment: .leading, spacing: 9) {
                if showsTitle {
                    CVSectionTitle(title: ApplyMessages.profileHeading, style: titleStyle, theme: theme)
                }
                Text(cv.profile.isEmpty ? ApplyMessages.profileHint : cv.profile)
                    .font(theme.body(9.5))
                    .foregroundStyle(cv.profile.isEmpty ? theme.muted : theme.ink)
                    .italic(cv.profile.isEmpty)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .applicationBlock(.profile, interaction, accent: theme.accent)
        }
    }
}
