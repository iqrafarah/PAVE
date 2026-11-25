import PAVECore
import SwiftUI

/// A saved profile in Profiel: tap it to change it, or share it straight away.
struct SavedProfileRow: View {
    let profile: SavedProfile
    let onEdit: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onEdit) {
                HStack(spacing: 14) {
                    ShareTemplateIcon(template: profile.template)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                        Text(SharingMessages.profileSummary(profile))
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(1)
                    }
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
            .accessibilityLabel("\(SharingMessages.shareProfile): \(profile.name)")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
    }
}
