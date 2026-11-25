import PAVECore
import SwiftUI

/// A saved profile in Profiel: tap it to change it, or share it straight away.
struct SavedProfileRow: View {
    let template: ShareTemplate
    let title: String
    let detail: String
    let onEdit: () -> Void
    let onShare: () -> Void

    init(profile: SavedProfile, onEdit: @escaping () -> Void, onShare: @escaping () -> Void) {
        template = profile.template
        title = profile.name
        detail = SharingMessages.profileSummary(profile)
        self.onEdit = onEdit
        self.onShare = onShare
    }

    /// A kind of recipient without a profile yet: tap to make one, or share once.
    init(template: ShareTemplate, onMake: @escaping () -> Void, onShare: @escaping () -> Void) {
        self.template = template
        title = SharingMessages.template(template)
        detail = SharingMessages.templateHint(template)
        onEdit = onMake
        self.onShare = onShare
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onEdit) {
                HStack(spacing: 14) {
                    ShareTemplateIcon(template: template)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .lineLimit(2)
                        Text(detail)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(2)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .accessibilityHint(SharingMessages.editProfile)
            Button(action: onShare) {
                Text(SharingMessages.shareProfile)
                    .textStyle(.chip)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 34)
                    .background(Color.paveAccentFill, in: .capsule)
                    .frame(minHeight: 44)
                    .contentShape(.capsule)
            }
            .buttonStyle(.pave)
            .accessibilityLabel("\(SharingMessages.shareProfile): \(title)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
    }
}
