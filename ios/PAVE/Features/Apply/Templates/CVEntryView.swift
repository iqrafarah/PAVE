import PAVECore
import SwiftUI

/// One line of experience or education: what, where and when, and a short description.
struct CVEntryView: View {
    let entry: CVEntry
    var isCompact = false

    var body: some View {
        if isCompact {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(entry.period)
                    .font(ApplicationPage.font(8, .medium))
                    .foregroundStyle(ApplicationPage.muted)
                    .frame(width: 78, alignment: .leading)
                details
            }
        } else {
            details
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.title)
                    .font(ApplicationPage.font(isCompact ? 9 : 10, .semibold))
                    .foregroundStyle(ApplicationPage.ink)
                Spacer(minLength: 8)
                if !isCompact, !entry.period.isEmpty {
                    Text(entry.period)
                        .font(ApplicationPage.font(8.5))
                        .foregroundStyle(ApplicationPage.muted)
                }
            }
            if !entry.organisation.isEmpty {
                Text(entry.organisation)
                    .font(ApplicationPage.font(isCompact ? 8.5 : 9, .medium))
                    .foregroundStyle(ApplicationPage.muted)
            }
            if !entry.description.isEmpty {
                Text(entry.description)
                    .font(ApplicationPage.font(isCompact ? 8.5 : 9))
                    .foregroundStyle(ApplicationPage.ink)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }
}
